package com.conexfor.ally

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import com.conexfor.ally.voice.Speaker
import com.conexfor.ally.voice.VoiceBubble
import com.conexfor.ally.voice.SpeechListener
import com.conexfor.ally.voice.VoicePrefs
import com.conexfor.ally.voice.VoiceService
import com.conexfor.ally.voice.WakeWordDetector
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FragmentActivity: requerido por local_auth (huella / bloqueo biométrico).
class MainActivity : FlutterFragmentActivity() {

    private var speechListener: SpeechListener? = null
    private var speaker: Speaker? = null
    private var permissionCallback: ((Boolean) -> Unit)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ally/system").setMethodCallHandler { call, result ->
            when (call.method) {
                // Pantalla de notificaciones de la app en los ajustes del sistema
                // (cuando el permiso se negó y Android ya no vuelve a preguntar).
                "openNotificationSettings" -> {
                    runCatching {
                        startActivity(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
                        )
                    }.onFailure {
                        startActivity(
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                .setData(android.net.Uri.fromParts("package", packageName, null)),
                        )
                    }
                    result.success(null)
                }
                // Tras responder a una alarma que abrió la app: volver a lo que
                // había antes (pantalla de bloqueo u otra app) sin cerrar Ally.
                "moveToBackground" -> result.success(moveTaskToBack(true))
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ally/voice").setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(voiceStatus())
                "setWakeWordEnabled" -> {
                    val enabled = call.arguments as? Boolean ?: false
                    if (!enabled) {
                        VoicePrefs.setEnabled(this, false)
                        VoiceService.stop(this)
                        result.success(voiceStatus())
                    } else {
                        withMicPermission { granted ->
                            if (granted) {
                                VoicePrefs.setEnabled(this, true)
                                VoiceService.start(this)
                            }
                            result.success(voiceStatus())
                        }
                    }
                }
                "listen" -> withMicPermission { granted ->
                    if (!granted) {
                        result.error("permission", "Sin permiso de micrófono", null)
                        return@withMicPermission
                    }
                    // La escucha de «Hey Ally» suelta el micrófono mientras tanto.
                    VoiceService.pause(this)
                    val listener = speechListener ?: SpeechListener(this).also { speechListener = it }
                    window.decorView.postDelayed({
                        listener.listen { text ->
                            VoiceService.resume(this)
                            result.success(text)
                        }
                    }, 150)
                }
                "stopListening" -> {
                    speechListener?.cancel()
                    VoiceService.resume(this)
                    result.success(null)
                }
                "speak" -> {
                    val text = call.arguments as? String ?: ""
                    val tts = speaker ?: Speaker(this).also { speaker = it }
                    tts.speak(text) { result.success(null) }
                }
                // Permiso «Mostrar sobre otras apps» para la burbuja de voz.
                "requestOverlayPermission" -> {
                    runCatching {
                        startActivity(
                            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                                .setData(android.net.Uri.parse("package:$packageName")),
                        )
                    }
                    result.success(null)
                }
                "stopSpeaking" -> {
                    speaker?.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun voiceStatus() = mapOf(
        "enabled" to VoicePrefs.isEnabled(this),
        "running" to VoiceService.isRunning,
        "model_available" to WakeWordDetector.isModelAvailable(this),
        "mic_permission" to VoiceService.hasMicPermission(this),
        "recognition_available" to SpeechListener(this).isAvailable(),
        "overlay_permission" to VoiceBubble.isAvailable(this),
    )

    private fun withMicPermission(callback: (Boolean) -> Unit) {
        if (VoiceService.hasMicPermission(this)) {
            callback(true)
            return
        }
        permissionCallback?.invoke(false)
        permissionCallback = callback
        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), MIC_REQUEST)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == MIC_REQUEST) {
            val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            permissionCallback?.invoke(granted)
            permissionCallback = null
        }
    }

    override fun onResume() {
        super.onResume()
        // Con la app visible Android sí deja iniciar la escucha (p. ej. tras reiniciar).
        if (!VoiceService.isRunning) VoiceService.start(this)
    }

    override fun onDestroy() {
        speechListener?.cancel()
        speaker?.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val MIC_REQUEST = 7310
    }
}
