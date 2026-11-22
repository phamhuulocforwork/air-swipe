package com.airswipe.air_swipe

import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.util.Size
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.min

object AirSwipeCamera {
    @Volatile
    var acceptFrames: Boolean = true

    @Volatile
    private var previewActive: Boolean = true

    @Volatile
    private var running: Boolean = false

    private var provider: ProcessCameraProvider? = null
    private var analysis: ImageAnalysis? = null
    private var previewView: PreviewView? = null
    private var lifecycleOwner: ResumedLifecycleOwner? = null
    private var executor: ExecutorService? = null
    private var lastSentElapsed = 0L
    private var appContext: Context? = null

    fun attachPreview(view: PreviewView) {
        previewView = view
        rebind()
    }

    fun detachPreview(view: PreviewView) {
        if (previewView === view) {
            previewView = null
            rebind()
        }
    }

    fun updatePreviewActive(enabled: Boolean) {
        previewActive = enabled
        rebind()
    }

    fun start(context: Context) {
        appContext = context.applicationContext
        if (running) {
            AirSwipeChannels.notify("cameraReady")
            return
        }
        running = true
        acceptFrames = true
        AirSwipeRuntime.listening = true
        AirSwipeRuntime.refreshTile(context)
        val owner = ResumedLifecycleOwner().also { it.resume() }
        lifecycleOwner = owner
        val cameraExecutor = Executors.newSingleThreadExecutor()
        executor = cameraExecutor
        val future = ProcessCameraProvider.getInstance(context.applicationContext)
        future.addListener(
            {
                try {
                    val cameraProvider = future.get()
                    provider = cameraProvider
                    if (!cameraProvider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA)) {
                        fail("Máy không có camera trước")
                        return@addListener
                    }
                    val resolutionSelector =
                        ResolutionSelector.Builder()
                            .setResolutionStrategy(
                                ResolutionStrategy(
                                    Size(640, 480),
                                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                                ),
                            )
                            .build()
                    analysis =
                        ImageAnalysis.Builder()
                            .setResolutionSelector(resolutionSelector)
                            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_NV21)
                            .build()
                            .also { imageAnalysis ->
                                imageAnalysis.setAnalyzer(cameraExecutor, ::onImage)
                            }
                    bind()
                    AirSwipeChannels.notify("cameraReady")
                } catch (error: Exception) {
                    fail(error.message ?: "Không mở được camera")
                }
            },
            ContextCompat.getMainExecutor(context),
        )
    }

    fun stop() {
        running = false
        acceptFrames = true
        val context = appContext
        mainExecutorRun {
            try {
                provider?.unbindAll()
            } catch (_: Exception) {
            }
            provider = null
            analysis = null
            lifecycleOwner?.destroy()
            lifecycleOwner = null
            executor?.shutdownNow()
            executor = null
            AirSwipeSkeleton.clear()
            if (context != null) {
                AirSwipeRuntime.listening = false
                AirSwipeRuntime.refreshTile(context)
            }
        }
    }

    private fun rebind() {
        if (!running || provider == null) {
            return
        }
        mainExecutorRun {
            try {
                bind()
            } catch (error: Exception) {
                fail(error.message ?: "Không gắn lại được camera")
            }
        }
    }

    private fun bind() {
        val cameraProvider = provider ?: return
        val imageAnalysis = analysis ?: return
        val owner = lifecycleOwner ?: return
        val view = previewView
        cameraProvider.unbindAll()
        if (previewActive && view != null) {
            val preview =
                Preview.Builder().build().also { useCase ->
                    useCase.surfaceProvider = view.surfaceProvider
                }
            cameraProvider.bindToLifecycle(
                owner,
                CameraSelector.DEFAULT_FRONT_CAMERA,
                preview,
                imageAnalysis,
            )
        } else {
            cameraProvider.bindToLifecycle(
                owner,
                CameraSelector.DEFAULT_FRONT_CAMERA,
                imageAnalysis,
            )
        }
    }

    private fun onImage(image: ImageProxy) {
        try {
            if (!running || !acceptFrames) {
                return
            }
            val now = SystemClock.elapsedRealtime()
            if (now - lastSentElapsed < 80L) {
                return
            }
            val bytes = imageProxyToNv21(image)
            val width = image.width
            val height = image.height
            val rotation = image.imageInfo.rotationDegrees
            acceptFrames = false
            lastSentElapsed = now
            AirSwipeChannels.sendFrame(width, height, rotation, bytes)
        } catch (_: Exception) {
            acceptFrames = true
        } finally {
            image.close()
        }
    }

    private fun fail(message: String) {
        AirSwipeChannels.notify("cameraError", message)
        val context = appContext
        stop()
        if (context != null) {
            context.stopService(Intent(context, AirSwipeCameraService::class.java))
        }
    }

    private fun mainExecutorRun(block: () -> Unit) {
        val context = appContext
        if (context == null) {
            block()
            return
        }
        ContextCompat.getMainExecutor(context).execute(block)
    }
}

private class ResumedLifecycleOwner : LifecycleOwner {
    private val registry = LifecycleRegistry(this)

    override val lifecycle: Lifecycle
        get() = registry

    fun resume() {
        registry.currentState = Lifecycle.State.RESUMED
    }

    fun destroy() {
        if (registry.currentState != Lifecycle.State.DESTROYED) {
            registry.currentState = Lifecycle.State.DESTROYED
        }
    }
}

internal fun imageProxyToNv21(image: ImageProxy): ByteArray {
    if (image.planes.size >= 3) {
        return yuvToNv21(image)
    }
    val expected = image.width * image.height * 3 / 2
    val buffer = image.planes[0].buffer.duplicate()
    buffer.rewind()
    val out = ByteArray(expected)
    buffer.get(out, 0, min(expected, buffer.remaining()))
    return out
}

private fun yuvToNv21(image: ImageProxy): ByteArray {
    val width = image.width
    val height = image.height
    val nv21 = ByteArray(width * height * 3 / 2)
    val yPlane = image.planes[0]
    val uPlane = image.planes[1]
    val vPlane = image.planes[2]
    var position = 0
    var yIndexBase = 0
    for (row in 0 until height) {
        var yIndex = yIndexBase
        for (col in 0 until width) {
            nv21[position++] = yPlane.buffer.get(yIndex)
            yIndex += yPlane.pixelStride
        }
        yIndexBase += yPlane.rowStride
    }
    val chromaHeight = height / 2
    val chromaWidth = width / 2
    var vRow = 0
    var uRow = 0
    for (row in 0 until chromaHeight) {
        var vIndex = vRow
        var uIndex = uRow
        for (col in 0 until chromaWidth) {
            nv21[position++] = vPlane.buffer.get(vIndex)
            nv21[position++] = uPlane.buffer.get(uIndex)
            vIndex += vPlane.pixelStride
            uIndex += uPlane.pixelStride
        }
        vRow += vPlane.rowStride
        uRow += uPlane.rowStride
    }
    return nv21
}
