package com.airswipe.air_swipe

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

class AirSwipeCameraService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (
            ContextCompat.checkSelfPermission(this, android.Manifest.permission.CAMERA) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            AirSwipeChannels.notify("cameraError", "Chưa cấp quyền camera")
            stopSelf()
            return START_NOT_STICKY
        }
        startInForeground()
        AirSwipeCamera.start(this)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        AirSwipeCamera.stop()
        super.onDestroy()
    }

    private fun startInForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel =
                NotificationChannel(
                    CHANNEL_ID,
                    "AirSwipe",
                    NotificationManager.IMPORTANCE_LOW,
                )
            channel.description = "Camera đang lắng nghe cử chỉ"
            manager.createNotificationChannel(channel)
        }
        val openApp =
            PendingIntent.getActivity(
                this,
                0,
                Intent(this, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        val notification =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("AirSwipe")
                .setContentText("Đang lắng nghe cử chỉ")
                .setSmallIcon(R.drawable.ic_tile)
                .setContentIntent(openApp)
                .setOngoing(true)
                .build()
        val type =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
            } else {
                0
            }
        ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, type)
    }

    companion object {
        private const val CHANNEL_ID = "airswipe_listening"
        private const val NOTIFICATION_ID = 1001
    }
}
