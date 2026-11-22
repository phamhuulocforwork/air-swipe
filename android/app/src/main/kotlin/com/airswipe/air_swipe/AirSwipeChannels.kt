package com.airswipe.air_swipe

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

object AirSwipeChannels {
    const val METHOD = "com.airswipe/gestures"
    const val FRAMES = "com.airswipe/frames"
    const val PREVIEW = "com.airswipe/preview"

    @Volatile
    var messenger: BinaryMessenger? = null

    @Volatile
    var dartReady: Boolean = false

    @Volatile
    var pendingCommand: String? = null

    var frameSink: EventChannel.EventSink? = null

    private val main = Handler(Looper.getMainLooper())

    fun notify(method: String, arguments: Any? = null) {
        val messenger = messenger ?: return
        main.post { MethodChannel(messenger, METHOD).invokeMethod(method, arguments) }
    }

    fun sendFrame(width: Int, height: Int, rotation: Int, bytes: ByteArray) {
        main.post {
            val sink = frameSink
            if (sink == null) {
                AirSwipeCamera.acceptFrames = true
                return@post
            }
            sink.success(
                mapOf(
                    "width" to width,
                    "height" to height,
                    "rotation" to rotation,
                    "bytes" to bytes,
                ),
            )
        }
    }
}
