package com.airswipe.air_swipe

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

class AirSwipeTileService : TileService() {
    override fun onStartListening() {
        val tile = qsTile ?: return
        tile.label = "AirSwipe"
        tile.state =
            if (AirSwipeRuntime.listening) {
                Tile.STATE_ACTIVE
            } else {
                Tile.STATE_INACTIVE
            }
        tile.updateTile()
    }

    override fun onClick() {
        if (AirSwipeRuntime.listening) {
            val tile = qsTile
            tile?.state = Tile.STATE_INACTIVE
            tile?.updateTile()
            stopService(Intent(this, AirSwipeCameraService::class.java))
            AirSwipeChannels.notify("stop")
        } else {
            openForCommand("start")
        }
    }

    private fun openForCommand(command: String) {
        val intent =
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra(MainActivity.EXTRA_COMMAND, command)
            }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val pending =
                PendingIntent.getActivity(
                    this,
                    1,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            startActivityAndCollapse(pending)
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }
}
