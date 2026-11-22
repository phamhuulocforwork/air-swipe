package com.airswipe.air_swipe

import android.content.ComponentName
import android.content.Context
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

object AirSwipeRuntime {
    @Volatile
    var listening: Boolean = false

    fun refreshTile(context: Context) {
        try {
            TileService.requestListeningState(
                context,
                ComponentName(context, AirSwipeTileService::class.java),
            )
        } catch (_: Exception) {
        }
    }
}
