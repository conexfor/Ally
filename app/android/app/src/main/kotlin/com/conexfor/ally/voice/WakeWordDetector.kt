package com.conexfor.ally.voice

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import java.io.Closeable
import java.nio.FloatBuffer

/**
 * Detector de palabra clave con openWakeWord (https://github.com/dscripka/openWakeWord),
 * 100% en el dispositivo.
 *
 * Tubería (idéntica a la de la librería en Python):
 *  audio 16 kHz PCM16 → melspectrogram.onnx (8 tramas de 32 bandas por cada 80 ms)
 *  → embedding_model.onnx (ventana de 76 tramas → 96 valores)
 *  → modelo de la palabra (últimos 16 embeddings → probabilidad 0..1).
 *
 * No es seguro para hilos: se usa desde el hilo de grabación.
 */
class WakeWordDetector private constructor(
    private val env: OrtEnvironment,
    private val melspec: OrtSession,
    private val embedding: OrtSession,
    private val wakeword: OrtSession,
    private val threshold: Float,
) : Closeable {

    companion object {
        const val SAMPLE_RATE = 16000

        /** 80 ms: tamaño de bloque que procesa openWakeWord. */
        const val FRAME_SAMPLES = 1280

        private const val ASSET_DIR = "flutter_assets/assets/wakeword"
        const val MODEL_FILE = "hey_ally.onnx"

        private const val MEL_CONTEXT = 160 * 3
        private const val MEL_BINS = 32
        private const val EMBEDDING_WINDOW = 76
        private const val EMBEDDING_SIZE = 96
        private const val MAX_MEL_FRAMES = 10 * 97
        private const val MAX_FEATURES = 120

        fun isModelAvailable(context: Context): Boolean =
            runCatching { context.assets.list(ASSET_DIR)?.contains(MODEL_FILE) == true }
                .getOrDefault(false)

        fun create(context: Context, threshold: Float = 0.5f): WakeWordDetector {
            val env = OrtEnvironment.getEnvironment()
            fun load(name: String): OrtSession {
                val bytes = context.assets.open("$ASSET_DIR/$name").use { it.readBytes() }
                val options = OrtSession.SessionOptions().apply { setIntraOpNumThreads(1) }
                return env.createSession(bytes, options)
            }
            return WakeWordDetector(
                env,
                load("melspectrogram.onnx"),
                load("embedding_model.onnx"),
                load(MODEL_FILE),
                threshold,
            )
        }
    }

    private val wakewordInput = wakeword.inputNames.first()
    private val wakewordFrames = (wakeword.inputInfo[wakewordInput]?.info as? ai.onnxruntime.TensorInfo)
        ?.shape?.getOrNull(1)?.toInt()?.takeIf { it > 0 } ?: 16

    /** Últimas muestras (contexto que necesita el espectrograma). */
    private val audio = FloatArray(FRAME_SAMPLES + MEL_CONTEXT)
    private val mel = ArrayDeque<FloatArray>()
    private val features = ArrayDeque<FloatArray>()
    private var framesSeen = 0

    init {
        reset()
    }

    /** Vacía el estado (tras una detección o al reanudar la escucha). */
    fun reset() {
        audio.fill(0f)
        mel.clear()
        // openWakeWord inicializa el buffer de espectrograma con unos.
        repeat(EMBEDDING_WINDOW) { mel.addLast(FloatArray(MEL_BINS) { 1f }) }
        features.clear()
        framesSeen = 0
    }

    /**
     * Procesa exactamente [FRAME_SAMPLES] muestras y devuelve la probabilidad
     * de que se acabe de decir la palabra clave.
     */
    fun process(frame: ShortArray): Float {
        require(frame.size == FRAME_SAMPLES)
        // Desplaza el contexto y añade el bloque nuevo (valores PCM sin normalizar).
        System.arraycopy(audio, FRAME_SAMPLES, audio, 0, MEL_CONTEXT)
        for (i in frame.indices) audio[MEL_CONTEXT + i] = frame[i].toFloat()

        for (row in melspectrogram(audio)) {
            mel.addLast(row)
            if (mel.size > MAX_MEL_FRAMES) mel.removeFirst()
        }
        features.addLast(embed())
        if (features.size > MAX_FEATURES) features.removeFirst()

        framesSeen++
        // Los primeros bloques no tienen contexto suficiente (la librería
        // también descarta las primeras predicciones).
        if (framesSeen < wakewordFrames) return 0f
        return predict()
    }

    fun isDetection(score: Float) = score >= threshold

    private fun melspectrogram(samples: FloatArray): List<FloatArray> {
        OnnxTensor.createTensor(env, FloatBuffer.wrap(samples), longArrayOf(1, samples.size.toLong())).use { input ->
            melspec.run(mapOf(melspec.inputNames.first() to input)).use { result ->
                val flat = (result[0] as OnnxTensor).floatBuffer
                val values = FloatArray(flat.remaining()).also { flat.get(it) }
                // Misma transformación que openWakeWord: x / 10 + 2.
                return values.toList().chunked(MEL_BINS).map { row ->
                    FloatArray(MEL_BINS) { row[it] / 10f + 2f }
                }
            }
        }
    }

    private fun embed(): FloatArray {
        val window = FloatArray(EMBEDDING_WINDOW * MEL_BINS)
        val start = mel.size - EMBEDDING_WINDOW
        for (i in 0 until EMBEDDING_WINDOW) {
            System.arraycopy(mel[start + i], 0, window, i * MEL_BINS, MEL_BINS)
        }
        val shape = longArrayOf(1, EMBEDDING_WINDOW.toLong(), MEL_BINS.toLong(), 1)
        OnnxTensor.createTensor(env, FloatBuffer.wrap(window), shape).use { input ->
            embedding.run(mapOf(embedding.inputNames.first() to input)).use { result ->
                val flat = (result[0] as OnnxTensor).floatBuffer
                return FloatArray(EMBEDDING_SIZE).also { flat.get(it) }
            }
        }
    }

    private fun predict(): Float {
        val input = FloatArray(wakewordFrames * EMBEDDING_SIZE)
        val start = features.size - wakewordFrames
        for (i in 0 until wakewordFrames) {
            System.arraycopy(features[start + i], 0, input, i * EMBEDDING_SIZE, EMBEDDING_SIZE)
        }
        val shape = longArrayOf(1, wakewordFrames.toLong(), EMBEDDING_SIZE.toLong())
        OnnxTensor.createTensor(env, FloatBuffer.wrap(input), shape).use { tensor ->
            wakeword.run(mapOf(wakewordInput to tensor)).use { result ->
                return (result[0] as OnnxTensor).floatBuffer.get(0)
            }
        }
    }

    override fun close() {
        wakeword.close()
        embedding.close()
        melspec.close()
    }
}
