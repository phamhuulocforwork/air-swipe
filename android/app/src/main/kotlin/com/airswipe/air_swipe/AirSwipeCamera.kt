package com.airswipe.air_swipe

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.os.SystemClock
import android.util.Log
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
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.gesturerecognizer.GestureRecognizer
import com.google.mediapipe.tasks.vision.gesturerecognizer.GestureRecognizerResult
import java.io.ByteArrayOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.min

object AirSwipeCamera {
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
    private var lastTimestamp = 0L
    private var fpsWindowStart = 0L
    private var fpsWindowCount = 0
    private var fps: Int? = null
    private var appContext: Context? = null
    private var recognizer: GestureRecognizer? = null
    private var gestureBusy = false
    private var pendingMeta: FrameMeta? = null
    private val gestureGate = Any()

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
        resetMetrics()
        AirSwipeRuntime.listening = true
        AirSwipeRuntime.refreshTile(context)
        val owner = ResumedLifecycleOwner().also { it.resume() }
        lifecycleOwner = owner
        val cameraExecutor = Executors.newSingleThreadExecutor()
        executor = cameraExecutor
        val app = context.applicationContext
        cameraExecutor.execute {
            try {
                val created = createRecognizer(app)
                synchronized(gestureGate) {
                    if (!running || executor !== cameraExecutor) {
                        created.close()
                    } else {
                        recognizer = created
                    }
                }
            } catch (error: Exception) {
                Log.e("AirSwipeGesture", "GestureRecognizer init failed", error)
                if (running && executor === cameraExecutor) {
                    fail(error.message ?: "Không tải được model cử chỉ")
                }
            }
        }
        val future = ProcessCameraProvider.getInstance(app)
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
                            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_YUV_420_888)
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
        resetMetrics()
        val closing: GestureRecognizer?
        val meta: FrameMeta?
        synchronized(gestureGate) {
            running = false
            closing = recognizer
            recognizer = null
            meta = pendingMeta
            pendingMeta = null
            gestureBusy = false
        }
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
            try {
                closing?.close()
            } catch (error: Exception) {
                Log.e("AirSwipeGesture", "close failed", error)
            }
            meta?.release()
            AirSwipeSkeleton.clear()
            if (context != null) {
                AirSwipeRuntime.listening = false
                AirSwipeRuntime.refreshTile(context)
            }
        }
    }

    private fun createRecognizer(context: Context): GestureRecognizer {
        val base =
            BaseOptions.builder()
                .setModelAssetPath("gesture_recognizer.task")
                .build()
        val options =
            GestureRecognizer.GestureRecognizerOptions.builder()
                .setBaseOptions(base)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setNumHands(2)
                .setResultListener { result, _ -> onGesture(result) }
                .setErrorListener { error -> onGestureError(error) }
                .build()
        return GestureRecognizer.createFromOptions(context, options)
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
        var bitmap: Bitmap? = null
        try {
            val active =
                synchronized(gestureGate) {
                    if (!running || gestureBusy) {
                        null
                    } else {
                        recognizer
                    }
                } ?: return
            val now = SystemClock.elapsedRealtime()
            if (now - lastSentElapsed < 80L) {
                return
            }
            val rotation = image.imageInfo.rotationDegrees
            val frame = uprightBitmap(imageProxyToBitmap(image), rotation)
            bitmap = frame
            val uprightWidth = frame.width.toFloat()
            val uprightHeight = frame.height.toFloat()
            val mpImage = BitmapImageBuilder(frame).build()
            val submittedElapsed = SystemClock.elapsedRealtime()
            val meta =
                FrameMeta(
                    rotation,
                    uprightWidth,
                    uprightHeight,
                    frame,
                    mpImage,
                    submittedElapsed,
                )
            bitmap = null
            lastSentElapsed = now
            synchronized(gestureGate) {
                pendingMeta = meta
                gestureBusy = true
            }
            try {
                active.recognizeAsync(mpImage, nextTimestamp())
            } catch (error: Exception) {
                val taken = takePending()
                Log.e("AirSwipeGesture", "recognizeAsync failed", error)
                val latency = taken?.let { SystemClock.elapsedRealtime() - it.submittedElapsed }
                taken?.release()
                if (running) {
                    AirSwipeChannels.notify(
                        "hand",
                        nonePayload(uprightWidth, uprightHeight, latency),
                    )
                }
            }
        } catch (error: Exception) {
            bitmap?.recycle()
            Log.e("AirSwipeGesture", "frame failed", error)
        } finally {
            image.close()
        }
    }

    private fun onGesture(result: GestureRecognizerResult) {
        val meta = takePending() ?: return
        try {
            if (!running) {
                return
            }
            val index = chosenHand(result)
            if (index == null) {
                Log.i(
                    "AirSwipeGesture",
                    "gesture=None score=0 hands=0 rotation=${meta.rotation}",
                )
                AirSwipeChannels.notify(
                    "hand",
                    nonePayload(
                        meta.uprightWidth,
                        meta.uprightHeight,
                        SystemClock.elapsedRealtime() - meta.submittedElapsed,
                    ),
                )
                return
            }
            val category = result.gestures().getOrNull(index)?.firstOrNull()
            val name = category?.categoryName()?.takeIf { it.isNotEmpty() } ?: "None"
            val score = category?.score() ?: 0f
            Log.i(
                "AirSwipeGesture",
                "gesture=$name score=$score hands=${result.landmarks().size} rotation=${meta.rotation}",
            )
            AirSwipeChannels.notify(
                "hand",
                handPayload(meta, name, score, result.landmarks()[index]),
            )
        } finally {
            meta.release()
        }
    }

    private fun onGestureError(error: RuntimeException) {
        val meta = takePending()
        Log.e("AirSwipeGesture", error.message ?: "recognize failed", error)
        val width = meta?.uprightWidth ?: 0f
        val height = meta?.uprightHeight ?: 0f
        val latency = meta?.let { SystemClock.elapsedRealtime() - it.submittedElapsed }
        meta?.release()
        if (running) {
            AirSwipeChannels.notify("hand", nonePayload(width, height, latency))
        }
    }

    private fun chosenHand(result: GestureRecognizerResult): Int? {
        val hands = result.landmarks()
        if (hands.isEmpty()) {
            return null
        }
        var chosen = 0
        var chosenScore = -1f
        var chosenOpen = false
        for (index in hands.indices) {
            val category = result.gestures().getOrNull(index)?.firstOrNull()
            val name = category?.categoryName().orEmpty()
            val score = category?.score() ?: 0f
            val open = name == "Open_Palm"
            if (open && (!chosenOpen || score > chosenScore)) {
                chosen = index
                chosenScore = score
                chosenOpen = true
            } else if (!chosenOpen && score > chosenScore) {
                chosen = index
                chosenScore = score
            }
        }
        return chosen
    }

    private fun handPayload(
        meta: FrameMeta,
        name: String,
        score: Float,
        landmarks: List<NormalizedLandmark>,
    ): Map<String, Any> {
        val xs = ArrayList<Double>(landmarks.size)
        val ys = ArrayList<Double>(landmarks.size)
        val likelihoods = ArrayList<Double>(landmarks.size)
        for (landmark in landmarks) {
            xs.add((landmark.x() * meta.uprightWidth).toDouble())
            ys.add((landmark.y() * meta.uprightHeight).toDouble())
            likelihoods.add(landmark.presence().orElse(1f).toDouble())
        }
        val payload =
            mutableMapOf<String, Any>(
                "width" to meta.uprightWidth.toDouble(),
                "height" to meta.uprightHeight.toDouble(),
                "gesture" to name,
                "score" to score.toDouble(),
                "xs" to xs,
                "ys" to ys,
                "likelihoods" to likelihoods,
            )
        attachMetrics(payload, SystemClock.elapsedRealtime() - meta.submittedElapsed)
        return payload
    }

    private fun nonePayload(
        width: Float,
        height: Float,
        latencyMs: Long? = null,
    ): Map<String, Any> {
        val payload =
            mutableMapOf<String, Any>(
                "width" to width.toDouble(),
                "height" to height.toDouble(),
                "gesture" to "None",
                "score" to 0.0,
                "xs" to emptyList<Double>(),
                "ys" to emptyList<Double>(),
                "likelihoods" to emptyList<Double>(),
            )
        attachMetrics(payload, latencyMs)
        return payload
    }

    private fun attachMetrics(payload: MutableMap<String, Any>, latencyMs: Long?) {
        val currentFps = noteGesture(SystemClock.elapsedRealtime())
        if (currentFps != null) {
            payload["fps"] = currentFps
        }
        if (latencyMs != null) {
            payload["latencyMs"] = latencyMs
        }
    }

    private fun noteGesture(now: Long): Int? {
        if (fpsWindowStart == 0L) {
            fpsWindowStart = now
        }
        fpsWindowCount += 1
        val elapsed = now - fpsWindowStart
        if (elapsed >= 1000L) {
            fps = ((fpsWindowCount * 1000L) / elapsed).toInt()
            fpsWindowStart = now
            fpsWindowCount = 0
        }
        return fps
    }

    private fun resetMetrics() {
        fpsWindowStart = 0L
        fpsWindowCount = 0
        fps = null
    }

    private fun takePending(): FrameMeta? {
        synchronized(gestureGate) {
            gestureBusy = false
            val meta = pendingMeta
            pendingMeta = null
            return meta
        }
    }

    private fun nextTimestamp(): Long {
        val now = SystemClock.uptimeMillis()
        val timestamp = if (now <= lastTimestamp) lastTimestamp + 1 else now
        lastTimestamp = timestamp
        return timestamp
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

private class FrameMeta(
    val rotation: Int,
    val uprightWidth: Float,
    val uprightHeight: Float,
    private val bitmap: Bitmap,
    private val mpImage: MPImage,
    val submittedElapsed: Long,
) {
    fun release() {
        try {
            mpImage.close()
        } catch (_: Exception) {
        }
        if (!bitmap.isRecycled) {
            bitmap.recycle()
        }
    }
}

internal fun uprightBitmap(source: Bitmap, rotationDegrees: Int): Bitmap {
    val rotation = ((rotationDegrees % 360) + 360) % 360
    if (rotation == 0) {
        return source
    }
    val matrix = Matrix().apply { postRotate(rotation.toFloat()) }
    val rotated =
        Bitmap.createBitmap(source, 0, 0, source.width, source.height, matrix, true)
    if (rotated != source) {
        source.recycle()
    }
    return rotated
}

internal fun imageProxyToBitmap(image: ImageProxy): Bitmap {
    val nv21 = imageProxyToNv21(image)
    val yuv =
        YuvImage(nv21, ImageFormat.NV21, image.width, image.height, null)
    val jpeg = ByteArrayOutputStream()
    yuv.compressToJpeg(Rect(0, 0, image.width, image.height), 90, jpeg)
    val bytes = jpeg.toByteArray()
    return BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        ?: throw IllegalStateException("Không decode được frame camera")
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
