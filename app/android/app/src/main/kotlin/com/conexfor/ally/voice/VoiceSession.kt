package com.conexfor.ally.voice

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Motor Flutter sin interfaz que ejecuta `voiceAssistantMain` (Dart): el mismo
 * intérprete y repositorios que la app, sin abrirla.
 */
private class DartAssistant(private val context: Context) {
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var ready = false
    val isReady get() = ready
    private val waiting = mutableListOf<() -> Unit>()

    fun start() {
        if (engine != null) return
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(context.applicationContext)
        loader.ensureInitializationComplete(context.applicationContext, null)
        val flutter = FlutterEngine(context.applicationContext)
        engine = flutter
        channel = MethodChannel(flutter.dartExecutor.binaryMessenger, "ally/voice_session").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "ready") {
                    Log.i(TAG, "Motor Dart listo")
                    ready = true
                    val queued = waiting.toList()
                    waiting.clear()
                    queued.forEach { it() }
                }
                result.success(null)
            }
        }
        flutter.dartExecutor.executeDartEntrypoint(
            // Función de main.dart (la biblioteca principal siempre se compila).
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "voiceAssistantMain"),
        )
    }

    private fun whenReady(action: () -> Unit) = if (ready) action() else waiting.add(action)

    /** Envía lo que dijo el usuario; responde `(texto a leer, espera respuesta)`. */
    fun handle(text: String, onReply: (String, Boolean) -> Unit) = whenReady {
        channel?.invokeMethod("handle", text, object : MethodChannel.Result {
            override fun success(result: Any?) {
                val map = result as? Map<*, *>
                onReply(map?.get("reply") as? String ?: FAILURE, map?.get("expects_answer") == true)
            }

            override fun error(code: String, message: String?, details: Any?) {
                Log.w(TAG, "Error del asistente: $code $message")
                onReply(FAILURE, false)
            }

            override fun notImplemented() = onReply(FAILURE, false)
        })
    }

    fun destroy() {
        val flutter = engine ?: return
        val ch = channel
        engine = null
        channel = null
        waiting.clear()
        // Deja que Dart cierre la base de datos antes de destruir el motor.
        var disposed = false
        val dispose = Runnable {
            if (!disposed) {
                disposed = true
                runCatching { flutter.destroy() }
            }
        }
        val main = Handler(Looper.getMainLooper())
        if (ready && ch != null) {
            ch.invokeMethod("end", null, object : MethodChannel.Result {
                override fun success(result: Any?) { main.post(dispose) }
                override fun error(code: String, message: String?, details: Any?) { main.post(dispose) }
                override fun notImplemented() { main.post(dispose) }
            })
            // Dart puede tardar hasta 6 s terminando de enviar la alarma al servidor.
            main.postDelayed(dispose, 8000)
        } else {
            dispose.run()
        }
        ready = false
    }

    companion object {
        const val TAG = "AllyVoice"
        const val FAILURE = "No pude completar la acción. Inténtalo de nuevo desde la app."
    }
}

/**
 * Una conversación por voz tras decir «Hey Ally»:
 * pitido → escuchar → interpretar/ejecutar (Dart) → leer la respuesta →
 * volver a escuchar solo si el asistente hizo una pregunta.
 *
 * Todo ocurre en el hilo principal.
 */
class VoiceSession(
    private val context: Context,
    /** Lo que entendió el reconocedor (para mostrarlo en pantalla). */
    private val onHeard: (String) -> Unit = {},
    /** Lo que responde el asistente (para mostrarlo en la notificación). */
    private val onReply: (String) -> Unit = {},
    private val onFinished: () -> Unit,
) {
    private val main = Handler(Looper.getMainLooper())
    private val listener = SpeechListener(context)
    private val speaker = Speaker(context)
    private val assistant = DartAssistant(context)
    private var turns = 0
    private var finished = false

    fun start() {
        try {
            assistant.start()
        } catch (e: Exception) {
            Log.e(DartAssistant.TAG, "No se pudo iniciar el asistente", e)
            say("No pude iniciar el asistente.") { finish() }
            return
        }
        beep()
        // Espera a que termine el pitido para no grabarlo.
        main.postDelayed({ listen() }, 250)
    }

    private fun listen() {
        if (finished) return
        listener.listen { text ->
            if (finished) return@listen
            Log.i(DartAssistant.TAG, "Reconocido: ${text ?: "(nada)"}")
            if (text != null) onHeard(text)
            if (text == null) {
                say(if (turns == 0) "No te escuché." else "No te escuché. Lo dejamos aquí.") { finish() }
                return@listen
            }
            turns++
            val timeout = Runnable {
                say("El asistente tardó demasiado. Inténtalo de nuevo.") { finish() }
            }
            main.postDelayed(timeout, 35_000) // Dart responde antes con su propio límite
            // El motor Dart arranca en paralelo a la escucha y suele estar listo
            // antes de que termines de hablar. Si no arrancó, se avisa enseguida.
            val notStarted = Runnable {
                if (assistant.isReady || finished) return@Runnable
                main.removeCallbacks(timeout)
                Log.w(DartAssistant.TAG, "El motor Dart no arrancó")
                // En una build de depuración lanzada desde el IDE, el motor de voz
                // hereda «empezar en pausa» y nadie lo reanuda.
                val debuggable = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
                say(
                    if (debuggable) {
                        "El asistente no pudo arrancar. Pasa al iniciar la app desde el depurador: prueba la voz con una versión release."
                    } else {
                        "El asistente no pudo arrancar. Abre Ally e inténtalo de nuevo."
                    },
                ) { finish() }
            }
            main.postDelayed(notStarted, 6_000)
            assistant.handle(text) { reply, expectsAnswer ->
                main.removeCallbacks(timeout)
                main.removeCallbacks(notStarted)
                if (finished) return@handle
                say(reply) {
                    if (expectsAnswer && turns < MAX_TURNS) listen() else finish()
                }
            }
        }
    }

    /** Lee la respuesta en voz alta y también la muestra. */
    private fun say(text: String, done: () -> Unit) {
        onReply(text)
        speaker.speak(text, done)
    }

    /** Termina la conversación (p. ej. si suena una alarma). */
    fun cancel() = finish()

    private fun finish() {
        if (finished) return
        finished = true
        main.removeCallbacksAndMessages(null)
        listener.cancel()
        speaker.shutdown()
        assistant.destroy()
        onFinished()
    }

    companion object {
        private const val MAX_TURNS = 4
    }
}
