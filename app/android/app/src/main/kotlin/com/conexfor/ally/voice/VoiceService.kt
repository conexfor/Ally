package com.conexfor.ally.voice

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.conexfor.ally.MainActivity
import com.conexfor.ally.R
import kotlin.concurrent.thread

/** Preferencias del modo manos libres (las lee también el receptor de arranque). */
object VoicePrefs {
    private const val FILE = "ally_voice"
    private const val KEY_ENABLED = "wake_word_enabled"

    fun isEnabled(context: Context) =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, false)

    fun setEnabled(context: Context, enabled: Boolean) =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit().putBoolean(KEY_ENABLED, enabled).apply()
}

/**
 * Servicio en primer plano que escucha «Hey Ally» con el micrófono y,
 * al detectarlo, abre una [VoiceSession].
 *
 * Android exige una notificación fija mientras se usa el micrófono en
 * segundo plano, y solo permite iniciar este servicio con la app visible o
 * desde una notificación (por eso, tras reiniciar, se pide tocar un aviso).
 */
class VoiceService : Service() {

    companion object {
        private const val TAG = "AllyVoice"
        private const val IDLE_TITLE = "Di «Hey Ally»"
        private const val IDLE_TEXT = "Por ejemplo: «alarma a las 4 de la tarde con Ana, Luis y Pedro»."
        private const val CHANNEL_ID = "ally_voice"
        /** Aviso emergente «Ally te escucha…» (importancia alta, sin sonido). */
        private const val LISTENING_CHANNEL_ID = "ally_voice_listening"
        private const val LISTENING_NOTIFICATION_ID = 7303
        /** Tiempo que se ve la respuesta antes de quitarse sola. */
        private const val RESULT_VISIBLE_MS = 6_000L
        private const val NOTIFICATION_ID = 7301
        private const val RESUME_NOTIFICATION_ID = 7302

        private const val ACTION_START = "com.conexfor.ally.voice.START"
        private const val ACTION_STOP = "com.conexfor.ally.voice.STOP"
        private const val ACTION_PAUSE = "com.conexfor.ally.voice.PAUSE"
        private const val ACTION_RESUME = "com.conexfor.ally.voice.RESUME"

        @Volatile
        var isRunning = false
            private set

        fun hasMicPermission(context: Context) =
            ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED

        /** Inicia la escucha. Solo funciona con la app en primer plano (o desde una notificación). */
        fun start(context: Context) {
            if (!VoicePrefs.isEnabled(context) || !hasMicPermission(context)) return
            if (!WakeWordDetector.isModelAvailable(context)) return
            runCatching {
                ContextCompat.startForegroundService(context, intent(context, ACTION_START))
            }.onFailure { Log.w(TAG, "No se pudo iniciar la escucha", it) }
        }

        fun stop(context: Context) {
            if (!isRunning) return
            runCatching { context.startService(intent(context, ACTION_STOP)) }
        }

        /** Libera el micrófono mientras la app lo usa (botón de micrófono del asistente). */
        fun pause(context: Context) {
            if (isRunning) runCatching { context.startService(intent(context, ACTION_PAUSE)) }
        }

        fun resume(context: Context) {
            if (isRunning) runCatching { context.startService(intent(context, ACTION_RESUME)) }
        }

        private fun intent(context: Context, action: String) =
            Intent(context, VoiceService::class.java).setAction(action)

        fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager = context.getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(CHANNEL_ID, "Asistente por voz", NotificationManager.IMPORTANCE_LOW).apply {
                        description = "Aviso fijo mientras Ally escucha «Hey Ally»"
                        setShowBadge(false)
                    },
                )
            }
            if (manager.getNotificationChannel(LISTENING_CHANNEL_ID) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(LISTENING_CHANNEL_ID, "Ally te escucha", NotificationManager.IMPORTANCE_HIGH).apply {
                        description = "Aviso emergente al decir «Hey Ally»"
                        setSound(null, null) // Ya suena el pitido.
                        enableVibration(false)
                        setShowBadge(false)
                    },
                )
            }
        }

        /**
         * Aviso para reactivar la escucha cuando Android no deja iniciarla
         * sola (tras reiniciar el teléfono o si el sistema cerró el servicio).
         */
        fun showResumeNotification(context: Context) {
            ensureChannel(context)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val tap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                PendingIntent.getForegroundService(context, 1, intent(context, ACTION_START), flags)
            } else {
                PendingIntent.getService(context, 1, intent(context, ACTION_START), flags)
            }
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.notification_icon)
                .setContentTitle("Activa «Hey Ally»")
                .setContentText("Toca para volver a escuchar tus órdenes por voz.")
                .setContentIntent(tap)
                .setAutoCancel(true)
                .build()
            runCatching {
                context.getSystemService(NotificationManager::class.java).notify(RESUME_NOTIFICATION_ID, notification)
            }
        }
    }

    private val main = Handler(Looper.getMainLooper())
    private val bubble by lazy { VoiceBubble(this) }

    /** Burbuja arcoíris si hay permiso «Mostrar sobre otras apps»; si no, notificación. */
    private fun useBubble() = VoiceBubble.isAvailable(this)
    private var detector: WakeWordDetector? = null
    private var recorder: AudioRecord? = null
    private var recordThread: Thread? = null

    @Volatile
    private var listening = false
    private var session: VoiceSession? = null
    private var paused = false
    private var loadingDetector = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                // También desde el botón "Desactivar" de la notificación.
                VoicePrefs.setEnabled(this, false)
                shutdown()
                return START_NOT_STICKY
            }
            ACTION_PAUSE -> {
                paused = true
                stopListening()
                return START_STICKY
            }
            ACTION_RESUME -> {
                paused = false
                if (session == null) startListening()
                return START_STICKY
            }
        }

        // ACTION_START o reinicio del sistema (intent nulo).
        if (!VoicePrefs.isEnabled(this) || !hasMicPermission(this)) {
            shutdown()
            return START_NOT_STICKY
        }
        if (!goForeground()) {
            showResumeNotification(this)
            shutdown()
            return START_NOT_STICKY
        }
        getSystemService(NotificationManager::class.java).cancel(RESUME_NOTIFICATION_ID)
        isRunning = true
        if (detector == null) {
            // Cargar los modelos tarda; fuera del hilo principal para no
            // retrasar la apertura de la app (que arranca este servicio).
            if (!loadingDetector) {
                loadingDetector = true
                thread(name = "wake-word-load") {
                    val loaded = runCatching { WakeWordDetector.create(this) }
                        .onFailure { Log.e(TAG, "No se pudo cargar el modelo de la palabra clave", it) }
                        .getOrNull()
                    main.post {
                        loadingDetector = false
                        if (!isRunning) {
                            loaded?.close()
                            return@post
                        }
                        detector = loaded
                        if (loaded == null) shutdown() else if (session == null && !paused) startListening()
                    }
                }
            }
            return START_STICKY
        }
        if (session == null && !paused) startListening()
        return START_STICKY
    }

    private fun buildNotification(title: String, text: String): Notification {
        val open = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val stop = PendingIntent.getService(
            this, 2, intent(this, ACTION_STOP), PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.notification_icon)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(open)
            .addAction(0, "Desactivar", stop)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    private fun showListening(heard: String? = null) {
        ensureChannel(this)
        val notification = NotificationCompat.Builder(this, LISTENING_CHANNEL_ID)
            .setSmallIcon(R.drawable.notification_icon)
            .setContentTitle(if (heard == null) "Ally te escucha…" else "Entendí:")
            .setContentText(heard?.let { "«$it»" } ?: "Di tu orden, por ejemplo «alarma a las 4 de la tarde».")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setOnlyAlertOnce(true)
            .setSilent(false) // Necesario para que aparezca como emergente (el canal no tiene sonido).
            .setTimeoutAfter(30_000)
            .build()
        runCatching {
            getSystemService(NotificationManager::class.java).notify(LISTENING_NOTIFICATION_ID, notification)
        }
    }

    /**
     * Respuesta del asistente en la notificación emergente («Listo. Alarma
     * creada…»). Vuelve a aparecer arriba y se quita sola a los pocos segundos.
     */
    private fun showResult(text: String) {
        ensureChannel(this)
        val notification = NotificationCompat.Builder(this, LISTENING_CHANNEL_ID)
            .setSmallIcon(R.drawable.notification_icon)
            .setContentTitle("Ally")
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setOnlyAlertOnce(false) // Que vuelva a mostrarse arriba (el canal no suena).
            .setSilent(false)
            .setAutoCancel(true)
            .setTimeoutAfter(RESULT_VISIBLE_MS)
            .build()
        runCatching {
            getSystemService(NotificationManager::class.java).notify(LISTENING_NOTIFICATION_ID, notification)
        }
    }

    private fun hideListening() {
        runCatching { getSystemService(NotificationManager::class.java).cancel(LISTENING_NOTIFICATION_ID) }
    }

    private fun updateNotification(title: String, text: String) {
        if (!isRunning) return
        runCatching {
            getSystemService(NotificationManager::class.java)
                .notify(NOTIFICATION_ID, buildNotification(title, text))
        }
    }

    private fun goForeground(): Boolean {
        ensureChannel(this)
        val notification = buildNotification(IDLE_TITLE, IDLE_TEXT)
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            true
        } catch (e: Exception) {
            // Android 12+ no deja iniciarlo desde segundo plano; Android 14+
            // tampoco sin acceso "mientras se usa" al micrófono.
            Log.w(TAG, "No se pudo iniciar en primer plano", e)
            false
        }
    }

    @SuppressLint("MissingPermission") // Se comprueba en onStartCommand.
    private fun startListening() {
        val wake = detector ?: return
        if (listening) return
        val minBuffer = AudioRecord.getMinBufferSize(
            WakeWordDetector.SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
        )
        val record = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                WakeWordDetector.SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minBuffer, WakeWordDetector.FRAME_SAMPLES * 2 * 4),
            )
        } catch (e: Exception) {
            Log.e(TAG, "No se pudo abrir el micrófono", e)
            null
        }
        if (record == null || record.state != AudioRecord.STATE_INITIALIZED) {
            record?.release()
            // Otra app usa el micrófono: se reintenta más tarde.
            main.postDelayed({ if (isRunning && session == null && !paused) startListening() }, 5000)
            return
        }
        recorder = record
        wake.reset()
        listening = true
        record.startRecording()
        recordThread = thread(name = "wake-word", priority = Thread.MAX_PRIORITY) {
            val frame = ShortArray(WakeWordDetector.FRAME_SAMPLES)
            var cooldown = 0
            var errors = 0
            var frames = 0
            var peak = 0
            var best = 0f
            Log.i(TAG, "Escuchando la palabra clave")
            while (listening) {
                var read = 0
                while (read < frame.size && listening) {
                    val n = record.read(frame, read, frame.size - read)
                    if (n <= 0) break
                    read += n
                }
                if (!listening) break
                if (read < frame.size) {
                    // Micrófono interrumpido (llamada, otra app): se reabre.
                    main.post { restartListening() }
                    break
                }
                val score = try {
                    wake.process(frame)
                } catch (e: Exception) {
                    if (errors++ == 0) Log.e(TAG, "Error del detector de palabra clave", e)
                    0f
                }
                // Diagnóstico en Logcat (filtro "AllyVoice") cada ~2 s: si el nivel
                // es 0 el micrófono entrega silencio (otra app lo está usando).
                for (s in frame) peak = maxOf(peak, kotlin.math.abs(s.toInt()))
                best = maxOf(best, score)
                if (++frames % 25 == 0) {
                    Log.i(TAG, "escuchando: nivel=$peak puntuación=${"%.3f".format(best)}")
                    peak = 0
                    best = 0f
                }
                if (cooldown > 0) {
                    cooldown--
                } else if (wake.isDetection(score)) {
                    cooldown = 25 // ~2 s
                    main.post { onWakeWord() }
                }
            }
        }
    }

    private fun stopListening() {
        listening = false
        recordThread?.join(500)
        recordThread = null
        recorder?.let {
            runCatching { it.stop() }
            it.release()
        }
        recorder = null
    }

    private fun restartListening() {
        stopListening()
        if (isRunning && session == null && !paused) {
            main.postDelayed({ if (isRunning && session == null && !paused) startListening() }, 1000)
        }
    }

    private fun onWakeWord() {
        if (session != null || paused) return
        Log.i(TAG, "Palabra clave detectada")
        // El reconocedor de voz necesita el micrófono libre.
        stopListening()
        // Aviso visual además del pitido (por si el volumen está bajo).
        // Aviso visual: burbuja flotante o, sin ese permiso, notificación emergente
        // (los Toast desde un servicio los bloquean fabricantes como Xiaomi).
        if (useBubble()) bubble.show("Te escucho…") else showListening()
        updateNotification("Te escucho…", "Di tu orden, por ejemplo «alarma a las 4 de la tarde».")
        session = VoiceSession(
            this,
            onHeard = { if (useBubble()) bubble.show("«$it»") else showListening(heard = it) },
            onReply = { if (useBubble()) bubble.show(it, listening = false) else showResult(it) },
        ) {
            session = null
            bubble.finish() // La respuesta queda a la vista ~2,5 s y se quita sola.
            // La respuesta queda a la vista unos segundos y se quita sola.
            updateNotification(IDLE_TITLE, IDLE_TEXT)
            if (isRunning && !paused) startListening()
        }.also { it.start() }
    }

    private fun shutdown() {
        hideListening()
        bubble.hide()
        isRunning = false
        session?.cancel()
        session = null
        stopListening()
        detector?.close()
        detector = null
        main.removeCallbacksAndMessages(null)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        if (isRunning) shutdown()
        super.onDestroy()
    }
}
