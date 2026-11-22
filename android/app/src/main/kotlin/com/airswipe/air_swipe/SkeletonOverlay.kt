package com.airswipe.air_swipe

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.View
import kotlin.math.max

/// Draws the pose on top of the front-camera preview.
///
/// X is mirrored so the drawing matches PreviewView's selfie mirror.
class SkeletonOverlay(
    context: Context,
) : View(context) {
    var imageWidth = 1f
    var imageHeight = 1f
    var xs = FloatArray(0)
    var ys = FloatArray(0)
    var likelihoods = FloatArray(0)

    private val bonePaint =
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
        }
    private val jointPaint =
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#FFD74B")
            style = Paint.Style.FILL
        }
    private val trackedPaint =
        Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#8A4200")
            style = Paint.Style.FILL
        }

    override fun onDraw(canvas: Canvas) {
        val count = minOf(xs.size, ys.size, likelihoods.size)
        if (count == 0 || imageWidth <= 0f || imageHeight <= 0f) {
            return
        }
        bonePaint.strokeWidth = max(3f, width / 80f)
        for (index in bones.indices step 2) {
            val start = bones[index]
            val end = bones[index + 1]
            if (start >= count || end >= count) {
                continue
            }
            if (likelihoods[start] < minLikelihood || likelihoods[end] < minLikelihood) {
                continue
            }
            val a = map(xs[start], ys[start])
            val b = map(xs[end], ys[end])
            canvas.drawLine(a[0], a[1], b[0], b[1], bonePaint)
        }
        for (index in 0 until count) {
            if (likelihoods[index] < minLikelihood) {
                continue
            }
            val point = map(xs[index], ys[index])
            val tracked = index in trackedJoints && likelihoods[index] >= 0.5f
            val radius = if (tracked) max(8f, width / 40f) else max(4f, width / 70f)
            canvas.drawCircle(point[0], point[1], radius, if (tracked) trackedPaint else jointPaint)
        }
    }

    private fun map(x: Float, y: Float): FloatArray {
        val mirroredX = imageWidth - x
        val scale = max(width / imageWidth, height / imageHeight)
        val dx = (width - imageWidth * scale) / 2f
        val dy = (height - imageHeight * scale) / 2f
        return floatArrayOf(dx + mirroredX * scale, dy + y * scale)
    }

    companion object {
        private const val minLikelihood = 0.3f

        private val trackedJoints = intArrayOf(15, 16, 19, 20)

        private val bones =
            intArrayOf(
                11, 12,
                11, 13, 13, 15,
                15, 17, 15, 19, 15, 21, 17, 19,
                12, 14, 14, 16,
                16, 18, 16, 20, 16, 22, 18, 20,
                11, 23, 12, 24, 23, 24,
                23, 25, 25, 27, 27, 29, 27, 31, 29, 31,
                24, 26, 26, 28, 28, 30, 28, 32, 30, 32,
                0, 1, 1, 2, 2, 3, 3, 7,
                0, 4, 4, 5, 5, 6, 6, 8,
                9, 10,
            )
    }
}

object AirSwipeSkeleton {
    private val overlays = mutableListOf<SkeletonOverlay>()

    fun attach(overlay: SkeletonOverlay) {
        overlays.add(overlay)
    }

    fun detach(overlay: SkeletonOverlay) {
        overlays.remove(overlay)
    }

    fun update(
        width: Float,
        height: Float,
        xs: FloatArray,
        ys: FloatArray,
        likelihoods: FloatArray,
    ) {
        for (overlay in overlays.toList()) {
            overlay.post {
                overlay.imageWidth = width
                overlay.imageHeight = height
                overlay.xs = xs
                overlay.ys = ys
                overlay.likelihoods = likelihoods
                overlay.invalidate()
            }
        }
    }

    fun clear() {
        update(1f, 1f, FloatArray(0), FloatArray(0), FloatArray(0))
    }
}
