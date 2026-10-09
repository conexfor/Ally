package com.conexfor.ally.voice

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.SweepGradient
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.animation.LinearInterpolator

/**
 * Burbuja flotante «Te escucho…» sobre cualquier app: píldora oscura con borde
 * arcoíris que gira y ondas que se expanden mientras Ally escucha.
 *
 * Necesita el permiso «Mostrar sobre otras apps» (SYSTEM_ALERT_WINDOW); sin él
 * [isAvailable] es `false` y el servicio usa la notificación emergente.
 * Todo se usa desde el hilo principal.
 */
class VoiceBubble(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())
    private val windowManager = context.getSystemService(WindowManager::class.java)
    private var view: BubbleView? = null

    companion object {
        fun isAvailable(context: Context) =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)
    }

    /** Muestra (o actualiza) la burbuja con [text]. */
    fun show(text: String, listening: Boolean = true) {
        main.removeCallbacksAndMessages(null)
        val current = view
        if (current != null) {
            current.setContent(text, listening)
            return
        }
        if (!isAvailable(context)) return
        val bubble = BubbleView(context).apply { setContent(text, listening) }
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = bubble.dp(40f).toInt()
        }
        val added = runCatching { windowManager.addView(bubble, params) }.isSuccess
        if (!added) return
        view = bubble
        bubble.alpha = 0f
        bubble.animate().alpha(1f).setDuration(200).start()
    }

    /** Deja a la vista el último texto (p. ej. «Listo. Alarma creada…») y desaparece sola. */
    fun finish(afterMs: Long = 2_500) {
        main.removeCallbacksAndMessages(null)
        main.postDelayed({ hide() }, afterMs)
    }

    fun hide() {
        main.removeCallbacksAndMessages(null)
        val bubble = view ?: return
        view = null
        bubble.animate().alpha(0f).setDuration(250).withEndAction {
            bubble.stop()
            runCatching { windowManager.removeView(bubble) }
        }.start()
    }
}

/** Dibujo de la burbuja: píldora, borde arcoíris giratorio y ondas. */
private class BubbleView(context: Context) : View(context) {
    private val density = context.resources.displayMetrics.density
    fun dp(v: Float) = v * density

    private val rainbow = intArrayOf(
        Color.parseColor("#FF5E5E"), Color.parseColor("#FFB13B"), Color.parseColor("#F9F871"),
        Color.parseColor("#4ADE80"), Color.parseColor("#38BDF8"), Color.parseColor("#818CF8"),
        Color.parseColor("#E879F9"), Color.parseColor("#FF5E5E"),
    )
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#EE15151B") }
    private val border = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = dp(3f) }
    private val wave = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = dp(2f) }
    private val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = dp(16f)
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }
    private val gradientMatrix = Matrix()
    private val pill = RectF()
    private var text = ""
    private var listening = true
    private var angle = 0f
    private var phase = 0f

    private val animator = ValueAnimator.ofFloat(0f, 1f).apply {
        duration = 2_400
        repeatCount = ValueAnimator.INFINITE
        interpolator = LinearInterpolator()
        addUpdateListener {
            val f = it.animatedValue as Float
            angle = f * 360f
            phase = (f * 2f) % 1f // dos ondas por vuelta
            invalidate()
        }
        start()
    }

    private val margin = dp(18f) // espacio para las ondas
    private val minPillHeight = dp(52f)
    private val padH = dp(24f)
    private val padV = dp(14f)
    private var layout: StaticLayout? = null

    /** Texto en hasta dos líneas, centrado, dentro del ancho disponible. */
    private fun buildLayout(available: Int): StaticLayout {
        val maxWidth = (available - margin * 2 - padH * 2).toInt().coerceAtLeast(1)
        val natural = textPaint.measureText(text).toInt() + 1
        return StaticLayout.Builder.obtain(text, 0, text.length, textPaint, minOf(natural, maxWidth))
            .setAlignment(Layout.Alignment.ALIGN_CENTER)
            .setMaxLines(2)
            .setEllipsize(TextUtils.TruncateAt.END)
            .build()
    }

    private fun pillHeight(l: StaticLayout) = maxOf(minPillHeight, l.height + padV * 2)

    fun setContent(text: String, listening: Boolean) {
        this.text = text
        this.listening = listening
        layout = null
        requestLayout()
        invalidate()
    }

    fun stop() = animator.cancel()

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val width = MeasureSpec.getSize(widthMeasureSpec)
        val l = buildLayout(width).also { layout = it }
        setMeasuredDimension(width, (pillHeight(l) + margin * 2).toInt())
    }

    override fun onDraw(canvas: Canvas) {
        val l = layout ?: buildLayout(width).also { layout = it }
        val pillHeight = pillHeight(l)
        val pillWidth = l.width + padH * 2
        val cx = width / 2f
        val cy = height / 2f
        pill.set(cx - pillWidth / 2, cy - pillHeight / 2, cx + pillWidth / 2, cy + pillHeight / 2)
        val radius = minOf(pillHeight, minPillHeight) / 2

        val shader = SweepGradient(cx, cy, rainbow, null)
        gradientMatrix.setRotate(angle, cx, cy)
        shader.setLocalMatrix(gradientMatrix)

        // Ondas: rectángulos redondeados que crecen y se desvanecen.
        if (listening) {
            wave.shader = shader
            for (i in 0 until 2) {
                val p = (phase + i * 0.5f) % 1f
                val grow = p * margin
                wave.alpha = ((1f - p) * 170).toInt()
                canvas.drawRoundRect(
                    pill.left - grow, pill.top - grow, pill.right + grow, pill.bottom + grow,
                    radius + grow, radius + grow, wave,
                )
            }
        }

        canvas.drawRoundRect(pill, radius, radius, fill)
        border.shader = shader
        canvas.drawRoundRect(pill, radius, radius, border)

        canvas.save()
        canvas.translate(cx - l.width / 2f, cy - l.height / 2f)
        l.draw(canvas)
        canvas.restore()
    }
}
