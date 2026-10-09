package com.conexfor.ally.voice

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Tras reiniciar el teléfono (o actualizar la app) recupera «Hey Ally».
 *
 * Desde Android 11 el micrófono solo se concede a servicios iniciados con la
 * app visible o desde una notificación, así que en esas versiones se muestra
 * un aviso que el usuario toca una vez.
 */
class VoiceBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) return
        if (!VoicePrefs.isEnabled(context) || !VoiceService.hasMicPermission(context)) return
        if (!WakeWordDetector.isModelAvailable(context)) return
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            VoiceService.start(context)
        } else {
            VoiceService.showResumeNotification(context)
        }
    }
}
