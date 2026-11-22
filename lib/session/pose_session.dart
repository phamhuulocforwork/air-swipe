import 'dart:async';
import 'dart:ui';

import 'package:air_swipe/data/swipe_platform.dart';
import 'package:air_swipe/domain/gesture/pose_skeleton.dart';
import 'package:air_swipe/domain/gesture/wrist_swipe_tracker.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Runs ML Kit pose on NV21 frames from the native camera service.
///
/// The Flutter `camera` plugin binds CameraX to the activity lifecycle, so the
/// stream stops as soon as another app is in front. Frames come from a
/// foreground service whose lifecycle stays resumed.
class PoseSession {
  PoseSession({required this.platform, WristSwipeTracker? tracker})
    : tracker = tracker ?? WristSwipeTracker();

  final SwipePlatform platform;
  final WristSwipeTracker tracker;

  PoseDetector? _detector;
  StreamSubscription<CameraFrame>? _frames;
  var listening = false;
  var starting = false;
  SwipeDirection? lastGesture;
  String? error;
  void Function()? onUpdate;

  void _notify() => onUpdate?.call();

  Future<void> start({required bool collapseAfter}) async {
    if (listening || starting) {
      return;
    }
    starting = true;
    error = null;
    _notify();
    try {
      _detector ??= PoseDetector(
        options: PoseDetectorOptions(
          mode: PoseDetectionMode.stream,
          model: PoseDetectionModel.base,
        ),
      );
      _frames ??= platform.frames().listen(
        _onFrame,
        onError: (Object error) {
          this.error = error.toString();
          _notify();
        },
      );
      await platform.startListening();
      listening = true;
      error = null;
      _notify();
      if (collapseAfter) {
        await platform.moveToBack();
      }
    } catch (error) {
      this.error = error is StateError ? error.message : error.toString();
      await _release();
      _notify();
    } finally {
      starting = false;
      _notify();
    }
  }

  Future<void> stop() => _release();

  Future<void>? _releaseTask;

  Future<void> _release() {
    final existing = _releaseTask;
    if (existing != null) {
      return existing;
    }
    final task = _releaseBody();
    _releaseTask = task;
    return task.whenComplete(() {
      if (identical(_releaseTask, task)) {
        _releaseTask = null;
      }
    });
  }

  Future<void> _releaseBody() async {
    listening = false;
    starting = false;
    await _frames?.cancel();
    _frames = null;
    await platform.stopListening();
    await _detector?.close();
    _detector = null;
    platform.showSkeleton(null);
    _notify();
  }

  Future<void> _onFrame(CameraFrame frame) async {
    final detector = _detector;
    if (!listening || detector == null) {
      await platform.frameDone();
      return;
    }
    final now = DateTime.now();

    try {
      final expected = frame.width * frame.height * 3 ~/ 2;
      if (frame.bytes.length < expected) {
        error = 'Frame không phải NV21 một buffer. Dừng lắng nghe.';
        _notify();
        scheduleMicrotask(() {
          stop();
        });
        return;
      }
      final rotation = InputImageRotationValue.fromRawValue(frame.rotation);
      if (rotation == null) {
        return;
      }
      final input = InputImage.fromBytes(
        bytes: frame.bytes,
        metadata: InputImageMetadata(
          size: Size(frame.width.toDouble(), frame.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: frame.width,
        ),
      );
      final poses = await detector.processImage(input);
      final skeleton = poseSkeleton(
        imageWidth: frame.width.toDouble(),
        imageHeight: frame.height.toDouble(),
        rotationDegrees: frame.rotation,
        landmarks: [
          for (final pose in poses.take(1))
            for (final entry in pose.landmarks.entries)
              SkeletonLandmark(
                index: entry.key.index,
                x: entry.value.x,
                y: entry.value.y,
                likelihood: entry.value.likelihood,
              ),
        ],
      );
      platform.showSkeleton(skeleton.hasVisibleJoint ? skeleton : null);
      final points = <HandPoint>[];
      for (final type in const [
        PoseLandmarkType.leftWrist,
        PoseLandmarkType.rightWrist,
        PoseLandmarkType.leftIndex,
        PoseLandmarkType.rightIndex,
      ]) {
        final index = type.index;
        if (skeleton.likelihoods[index] <= 0) {
          continue;
        }
        points.add(
          HandPoint(y: skeleton.ys[index], likelihood: skeleton.likelihoods[index]),
        );
      }
      final direction = tracker.addPoints(
        at: now,
        points: points,
        imageHeight: points.isEmpty ? 0 : skeleton.height,
      );
      if (direction != null) {
        lastGesture = direction;
        final swiped = direction == SwipeDirection.up
            ? await platform.swipeUp()
            : await platform.swipeDown();
        if (!swiped) {
          error = 'Chưa bật hỗ trợ tiếp cận, hoặc vuốt bị chặn.';
        } else {
          error = null;
        }
        _notify();
      }
    } catch (error) {
      this.error = error.toString();
      _notify();
    } finally {
      await platform.frameDone();
    }
  }
}
