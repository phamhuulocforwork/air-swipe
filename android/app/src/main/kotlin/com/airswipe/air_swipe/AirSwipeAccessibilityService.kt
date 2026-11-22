package com.airswipe.air_swipe

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.os.Build
import android.os.SystemClock
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent

class AirSwipeAccessibilityService : AccessibilityService() {
    private var lastSwipeElapsed = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    fun performSwipe(up: Boolean): Boolean {
        val now = SystemClock.elapsedRealtime()
        if (now - lastSwipeElapsed < 400L) {
            return false
        }
        val (width, height) = screenSize()
        if (width <= 0 || height <= 0) {
            return false
        }
        val line = SwipePaths.vertical(width, height, up)
        val path =
            Path().apply {
                moveTo(line.startX, line.startY)
                lineTo(line.endX, line.endY)
            }
        val stroke = GestureDescription.StrokeDescription(path, 0, line.durationMs)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()
        val dispatched = dispatchGesture(gesture, null, null)
        if (dispatched) {
            lastSwipeElapsed = now
        }
        return dispatched
    }

    private fun screenSize(): Pair<Int, Int> {
        val windowManager = getSystemService(WindowManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = windowManager.currentWindowMetrics.bounds
            return bounds.width() to bounds.height()
        }
        val metrics = resources.displayMetrics
        return metrics.widthPixels to metrics.heightPixels
    }

    companion object {
        @Volatile
        var instance: AirSwipeAccessibilityService? = null
    }
}
