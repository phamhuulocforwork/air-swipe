package com.airswipe.air_swipe

object SwipePaths {
    data class Line(
        val startX: Float,
        val startY: Float,
        val endX: Float,
        val endY: Float,
        val durationMs: Long,
    )

    fun vertical(
        width: Int,
        height: Int,
        up: Boolean,
        durationMs: Long = 250L,
    ): Line {
        val x = width / 2f
        val top = height * 0.28f
        val bottom = height * 0.72f
        return if (up) {
            Line(x, bottom, x, top, durationMs)
        } else {
            Line(x, top, x, bottom, durationMs)
        }
    }
}
