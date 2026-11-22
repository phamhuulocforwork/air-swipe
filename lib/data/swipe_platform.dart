import 'dart:async';

import 'package:air_swipe/domain/gesture/pose_skeleton.dart';
import 'package:flutter/services.dart';

class CameraFrame {
  const CameraFrame({
    required this.width,
    required this.height,
    required this.rotation,
    required this.bytes,
  });

  final int width;
  final int height;
  final int rotation;
  final Uint8List bytes;
}

class SwipePlatform {
  SwipePlatform({MethodChannel? channel, EventChannel? frames})
    : _channel = channel ?? const MethodChannel('com.airswipe/gestures'),
      _frames = frames ?? const EventChannel('com.airswipe/frames');

  static const channelName = 'com.airswipe/gestures';
  static const framesName = 'com.airswipe/frames';

  final MethodChannel _channel;
  final EventChannel _frames;
  Completer<void>? _ready;

  void listenCommands({
    required Future<void> Function() onStart,
    required Future<void> Function() onStop,
    required void Function(String message) onCameraError,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'start':
          await onStart();
        case 'stop':
          await onStop();
        case 'cameraReady':
          final ready = _ready;
          if (ready != null && !ready.isCompleted) {
            ready.complete();
          }
        case 'cameraError':
          final message = call.arguments as String? ?? 'Không mở được camera';
          final ready = _ready;
          if (ready != null && !ready.isCompleted) {
            ready.completeError(StateError(message));
          }
          onCameraError(message);
      }
    });
  }

  Future<String?> takeCommand() {
    return _channel.invokeMethod<String>('takeCommand');
  }

  Future<void> startListening() async {
    final ready = Completer<void>();
    _ready = ready;
    try {
      final started = await _channel.invokeMethod<bool>('startListening');
      if (started != true) {
        throw StateError('Không bật được camera');
      }
      await ready.future.timeout(const Duration(seconds: 5));
    } finally {
      if (identical(_ready, ready)) {
        _ready = null;
      }
    }
  }

  Future<void> stopListening() {
    return _channel.invokeMethod<void>('stopListening');
  }

  Future<void> frameDone() {
    return _channel.invokeMethod<void>('frameDone');
  }

  Future<bool> swipeUp() async {
    return await _channel.invokeMethod<bool>('swipeUp') ?? false;
  }

  Future<bool> swipeDown() async {
    return await _channel.invokeMethod<bool>('swipeDown') ?? false;
  }

  Future<bool> isServiceEnabled() async {
    return await _channel.invokeMethod<bool>('isServiceEnabled') ?? false;
  }

  Future<void> openAccessibilitySettings() {
    return _channel.invokeMethod<void>('openAccessibilitySettings');
  }

  Future<bool> canRequestAddTile() async {
    return await _channel.invokeMethod<bool>('canRequestAddTile') ?? false;
  }

  Future<bool> requestAddTile() async {
    return await _channel.invokeMethod<bool>('requestAddTile') ?? false;
  }

  Future<void> moveToBack() {
    return _channel.invokeMethod<void>('moveToBack');
  }

  Future<void> setPreviewActive(bool active) {
    return _channel.invokeMethod<void>('setPreviewActive', active);
  }

  void showSkeleton(PoseSkeleton? skeleton) {
    if (skeleton == null || !skeleton.hasVisibleJoint) {
      _channel.invokeMethod<void>('showSkeleton');
      return;
    }
    _channel.invokeMethod<void>('showSkeleton', {
      'width': skeleton.width,
      'height': skeleton.height,
      'xs': skeleton.xs,
      'ys': skeleton.ys,
      'likelihoods': skeleton.likelihoods,
    });
  }

  Stream<CameraFrame> frames() {
    return _frames.receiveBroadcastStream().map((event) {
      final map = Map<Object?, Object?>.from(event as Map);
      return CameraFrame(
        width: (map['width'] as num).toInt(),
        height: (map['height'] as num).toInt(),
        rotation: (map['rotation'] as num).toInt(),
        bytes: map['bytes'] as Uint8List,
      );
    });
  }
}
