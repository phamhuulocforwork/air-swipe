package com.airswipe.air_swipe

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ComponentName
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var shizukuExecutor: ShizukuSwipeExecutor

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        stashCommand(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val command = intent.getStringExtra(EXTRA_COMMAND) ?: return
        if (AirSwipeChannels.dartReady) {
            AirSwipeChannels.notify(command)
        } else {
            AirSwipeChannels.pendingCommand = command
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        AirSwipeChannels.messenger = messenger
        shizukuExecutor = ShizukuSwipeExecutor(this)
        shizukuExecutor.onStatusChanged = {
            AirSwipeChannels.notify("shizukuStatus", shizukuExecutor.statusMap())
        }
        shizukuExecutor.start()
        flutterEngine.platformViewsController.registry.registerViewFactory(
            AirSwipeChannels.PREVIEW,
            PreviewFactory(),
        )
        MethodChannel(messenger, AirSwipeChannels.METHOD).setMethodCallHandler { call, result ->
            when (call.method) {
                "takeCommand" -> {
                    AirSwipeChannels.dartReady = true
                    val command = AirSwipeChannels.pendingCommand
                    AirSwipeChannels.pendingCommand = null
                    intent?.removeExtra(EXTRA_COMMAND)
                    result.success(command)
                }
                "startListening" -> {
                    try {
                        ContextCompat.startForegroundService(
                            this,
                            Intent(this, AirSwipeCameraService::class.java),
                        )
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("start", error.message, null)
                    }
                }
                "stopListening" -> {
                    stopService(Intent(this, AirSwipeCameraService::class.java))
                    result.success(true)
                }
                "setPreviewActive" -> {
                    AirSwipeCamera.updatePreviewActive(call.arguments as? Boolean ?: true)
                    result.success(null)
                }
                "showSkeleton" -> {
                    showSkeleton(call.arguments as? Map<*, *>)
                    result.success(null)
                }
                "moveToBack" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                "swipeUp" -> result.success(shizukuExecutor.swipeUp())
                "swipeDown" -> result.success(shizukuExecutor.swipeDown())
                "getShizukuStatus" -> result.success(shizukuExecutor.statusMap())
                "requestShizukuPermission" -> result.success(shizukuExecutor.requestPermission())
                "isServiceEnabled" -> result.success(isAccessibilityEnabled())
                "openAccessibilitySettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("settings", error.message, null)
                    }
                }
                "canRequestAddTile" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
                "requestAddTile" -> requestAddTile(result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        AirSwipeChannels.dartReady = false
        AirSwipeChannels.messenger = null
        shizukuExecutor.shutdown()
        stopService(Intent(this, AirSwipeCameraService::class.java))
        super.onDestroy()
    }

    private fun showSkeleton(args: Map<*, *>?) {
        if (args == null) {
            AirSwipeSkeleton.clear()
            return
        }
        val width = (args["width"] as? Number)?.toFloat() ?: return
        val height = (args["height"] as? Number)?.toFloat() ?: return
        AirSwipeSkeleton.update(
            width,
            height,
            floatList(args["xs"]),
            floatList(args["ys"]),
            floatList(args["likelihoods"]),
        )
    }

    private fun floatList(value: Any?): FloatArray {
        val list = value as? List<*> ?: return FloatArray(0)
        return FloatArray(list.size) { index -> (list[index] as? Number)?.toFloat() ?: 0f }
    }

    private fun stashCommand(intent: Intent?) {
        val command = intent?.getStringExtra(EXTRA_COMMAND) ?: return
        AirSwipeChannels.pendingCommand = command
    }

    private fun isAccessibilityEnabled(): Boolean {
        val manager = getSystemService(AccessibilityManager::class.java)
        return manager
            .getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
            .any { it.resolveInfo.serviceInfo.packageName == packageName }
    }

    private fun requestAddTile(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(false)
            return
        }
        val statusBar = getSystemService(android.app.StatusBarManager::class.java)
        statusBar.requestAddTileService(
            ComponentName(this, AirSwipeTileService::class.java),
            "AirSwipe",
            Icon.createWithResource(this, R.drawable.ic_tile),
            mainExecutor,
        ) { code ->
            val added =
                code == android.app.StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED ||
                    code == android.app.StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED
            result.success(added)
        }
    }

    companion object {
        const val EXTRA_COMMAND = "command"
    }
}
