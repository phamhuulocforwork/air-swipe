package com.airswipe.air_swipe

import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.util.Log
import android.view.WindowManager
import rikka.shizuku.Shizuku

class ShizukuSwipeExecutor(private val context: Context) {

    var onStatusChanged: (() -> Unit)? = null

    private var lastSwipeElapsed = 0L
    private var bindRequested = false

    @Volatile
    private var shellExecutor: IShellExecutor? = null

    private val userServiceArgs = Shizuku.UserServiceArgs(
        ComponentName(context.packageName, ShellExecutorService::class.java.name),
    )
        .processNameSuffix("shell")
        .daemon(false)
        .version(1)

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            shellExecutor = IShellExecutor.Stub.asInterface(service)
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            shellExecutor = null
            bindRequested = false
        }
    }

    private val binderReceivedListener = Shizuku.OnBinderReceivedListener {
        bindRequested = false
        ensureBound()
        onStatusChanged?.invoke()
    }

    private val binderDeadListener = Shizuku.OnBinderDeadListener {
        shellExecutor = null
        bindRequested = false
        onStatusChanged?.invoke()
    }

    private val permissionResultListener = Shizuku.OnRequestPermissionResultListener { _, _ ->
        ensureBound()
        onStatusChanged?.invoke()
    }

    fun start() {
        Shizuku.addBinderReceivedListenerSticky(binderReceivedListener)
        Shizuku.addBinderDeadListener(binderDeadListener)
        Shizuku.addRequestPermissionResultListener(permissionResultListener)
    }

    fun shutdown() {
        Shizuku.removeBinderReceivedListener(binderReceivedListener)
        Shizuku.removeBinderDeadListener(binderDeadListener)
        Shizuku.removeRequestPermissionResultListener(permissionResultListener)
        shellExecutor = null
        bindRequested = false
        try {
            Shizuku.unbindUserService(userServiceArgs, serviceConnection, true)
        } catch (error: Exception) {
            Log.w(TAG, "unbindUserService failed", error)
        }
    }

    fun isServiceRunning(): Boolean = Shizuku.pingBinder()

    fun isPermissionGranted(): Boolean {
        if (!isServiceRunning()) return false
        if (Shizuku.isPreV11()) return false
        return Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
    }

    fun statusMap(): Map<String, Boolean> =
        try {
            mapOf("granted" to isPermissionGranted(), "running" to isServiceRunning())
        } catch (error: Exception) {
            Log.w(TAG, "statusMap failed", error)
            mapOf("granted" to false, "running" to false)
        }

    fun requestPermission(requestCode: Int = REQUEST_CODE): Map<String, Boolean> =
        try {
            if (!isServiceRunning() || Shizuku.isPreV11()) {
                statusMap()
            } else {
                if (!isPermissionGranted()) {
                    Shizuku.requestPermission(requestCode)
                }
                statusMap()
            }
        } catch (error: Exception) {
            Log.w(TAG, "requestPermission failed", error)
            mapOf("granted" to false, "running" to false)
        }

    fun swipeUp(): Boolean = performSwipe(true)

    fun swipeDown(): Boolean = performSwipe(false)

    fun ensureBound() {
        if (shellExecutor != null || bindRequested) return
        if (!isServiceRunning() || !isPermissionGranted()) return
        bindRequested = true
        try {
            Shizuku.bindUserService(userServiceArgs, serviceConnection)
        } catch (error: Exception) {
            Log.w(TAG, "bindUserService failed", error)
            bindRequested = false
        }
    }

    private fun performSwipe(up: Boolean): Boolean {
        val now = SystemClock.elapsedRealtime()
        if (now - lastSwipeElapsed < 400L) {
            return false
        }
        val executor = shellExecutor ?: run {
            ensureBound()
            return false
        }
        val (width, height) = screenSize()
        if (width <= 0 || height <= 0) {
            return false
        }
        val line = SwipePaths.vertical(width, height, up)
        val command = arrayOf(
            "input", "swipe",
            line.startX.toInt().toString(),
            line.startY.toInt().toString(),
            line.endX.toInt().toString(),
            line.endY.toInt().toString(),
            line.durationMs.toString(),
        )
        return try {
            executor.exec(command)
            lastSwipeElapsed = now
            true
        } catch (error: Exception) {
            Log.w(TAG, "exec failed", error)
            false
        }
    }

    private fun screenSize(): Pair<Int, Int> {
        val windowManager = context.getSystemService(WindowManager::class.java)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = windowManager.currentWindowMetrics.bounds
            bounds.width() to bounds.height()
        } else {
            val metrics = context.resources.displayMetrics
            metrics.widthPixels to metrics.heightPixels
        }
    }

    companion object {
        private const val TAG = "ShizukuSwipeExecutor"
        const val REQUEST_CODE = 1001
    }
}
