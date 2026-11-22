package com.airswipe.air_swipe

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object AirSwipeChannels {
    const val METHOD = "com.airswipe/gestures"
    const val PREVIEW = "com.airswipe/preview"

    @Volatile
    var messenger: BinaryMessenger? = null

    @Volatile
    var dartReady: Boolean = false

    @Volatile
    var pendingCommand: String? = null

    private val main = Handler(Looper.getMainLooper())

    fun notify(method: String, arguments: Any? = null) {
        val messenger = messenger ?: return
        main.post { MethodChannel(messenger, METHOD).invokeMethod(method, arguments) }
    }
}
