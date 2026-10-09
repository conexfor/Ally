package com.conexfor.ally.voice

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.Locale

/** Idioma de reconocimiento y voz: el del teléfono si es español, si no es-ES. */
internal fun spanishLocale(): Locale {
    val current = Locale.getDefault()
    return if (current.language == "es") current else Locale.forLanguageTag("es-ES")
}

/**
 * Voz a texto con el reconocedor del sistema (Google en la mayoría de
 * teléfonos; sin coste). Debe usarse desde el hilo principal.
 */
class SpeechListener(private val context: Context) {
    private var recognizer: SpeechRecognizer? = null
    private var pending: (() -> Unit)? = null

    fun isAvailable() = SpeechRecognizer.isRecognitionAvailable(context)

    /** Escucha una frase. [onResult] recibe el texto o `null` (silencio / error). */
    fun listen(onResult: (String?) -> Unit) {
        cancel()
        if (!isAvailable()) {
            onResult(null)
            return
        }
        val sr = SpeechRecognizer.createSpeechRecognizer(context)
        recognizer = sr
        var delivered = false
        fun deliver(text: String?) {
            if (delivered) return
            delivered = true
            pending = null
            cancel()
            onResult(text?.trim()?.takeIf { it.isNotEmpty() })
        }
        pending = { deliver(null) }
        sr.setRecognitionListener(object : RecognitionListener {
            override fun onResults(results: Bundle?) {
                val opciones = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION).orEmpty()
                // Las alternativas sirven para diagnosticar confusiones («trece»/«catorce»).
                if (opciones.size > 1) android.util.Log.i("AllyVoice", "Alternativas: $opciones")
                deliver(opciones.firstOrNull())
            }

            override fun onError(error: Int) = deliver(null)
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(partialResults: Bundle?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        val locale = spanishLocale().toLanguageTag()
        sr.startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, locale)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            // Más margen antes de dar la frase por terminada: con pausas como
            // «once y… treinta y nueve» se cortaba antes del segundo número.
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1500L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 2000L)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
        })
    }

    /** Detiene la escucha; si había una en curso, su callback recibe `null`. */
    fun cancel() {
        pending?.let {
            pending = null
            it()
        }
        recognizer?.let {
            runCatching { it.cancel() }
            it.destroy()
        }
        recognizer = null
    }
}

/** Texto a voz con el motor del sistema. */
class Speaker(context: Context) {
    private val main = Handler(Looper.getMainLooper())
    private val pending = mutableListOf<Pair<String, () -> Unit>>()
    private val callbacks = mutableMapOf<String, () -> Unit>()
    private var ready = false
    private var counter = 0

    private val tts: TextToSpeech = TextToSpeech(context.applicationContext) { status ->
        main.post {
            ready = status == TextToSpeech.SUCCESS
            if (ready) tts.language = spanishLocale()
            val queued = pending.toList()
            pending.clear()
            queued.forEach { (text, done) -> speak(text, done) }
        }
    }

    init {
        tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {}
            override fun onDone(utteranceId: String?) = finish(utteranceId)
            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) = finish(utteranceId)
            override fun onError(utteranceId: String?, errorCode: Int) = finish(utteranceId)
        })
    }

    private fun finish(id: String?) {
        main.post { callbacks.remove(id)?.invoke() }
    }

    /** Lee [text] y llama a [done] al terminar (también si falla). */
    fun speak(text: String, done: () -> Unit = {}) {
        if (!ready) {
            // Aún inicializando: se encola. Si el motor no existe, se continúa.
            pending.add(text to done)
            main.postDelayed({
                if (!ready && pending.remove(text to done)) done()
            }, 5000)
            return
        }
        val id = "u${counter++}"
        callbacks[id] = done
        val result = tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, id)
        if (result != TextToSpeech.SUCCESS) finish(id)
    }

    fun stop() {
        runCatching { tts.stop() }
        val waiting = callbacks.values.toList()
        callbacks.clear()
        waiting.forEach { it() }
    }

    fun shutdown() {
        callbacks.clear()
        pending.clear()
        runCatching { tts.stop() }
        tts.shutdown()
    }
}

/** Pitido corto para indicar "te escucho". */
internal fun beep() {
    runCatching {
        val tone = ToneGenerator(AudioManager.STREAM_MUSIC, 80)
        tone.startTone(ToneGenerator.TONE_PROP_BEEP, 150)
        Handler(Looper.getMainLooper()).postDelayed({ tone.release() }, 400)
    }
}
