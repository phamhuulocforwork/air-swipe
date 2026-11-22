package com.airswipe.air_swipe

import android.content.Context
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.widget.FrameLayout
import androidx.camera.view.PreviewView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class PreviewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val previewView =
            PreviewView(context).apply {
                implementationMode = PreviewView.ImplementationMode.COMPATIBLE
                scaleType = PreviewView.ScaleType.FILL_CENTER
            }
        val overlay = SkeletonOverlay(context)
        val root =
            FrameLayout(context).apply {
                addView(previewView, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
                addView(overlay, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
            }
        AirSwipeCamera.attachPreview(previewView)
        AirSwipeSkeleton.attach(overlay)
        return object : PlatformView {
            override fun getView(): View = root

            override fun dispose() {
                AirSwipeSkeleton.detach(overlay)
                AirSwipeCamera.detachPreview(previewView)
            }
        }
    }
}
