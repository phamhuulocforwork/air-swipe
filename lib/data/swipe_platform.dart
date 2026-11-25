import 'dart:async';

import 'package:flutter/services.dart';

class HandEvent {
  const HandEvent({
    required this.width,
    required this.height,
    required this.gesture,
    required this.score,
    required this.xs,
    required this.ys,
    required this.likelihoods,
    this.fps,
    this.latencyMs,
  });

  final double width;
  final double height;
  final String gesture;
  final double score;
  final List<double> xs;
  final List<double> ys;
  final List<double> likelihoods;
  final int? fps;
  final int? latencyMs;

  bool get hasVisibleJoint => likelihoods.any((value) => value >= 0.3);

  factory HandEvent.fromArguments(Object? arguments) {
    final map = Map<Object?, Object?>.from(arguments as Map);
    return HandEvent(
      width: (map['width'] as num?)?.toDouble() ?? 0,
      height: (map['height'] as num?)?.toDouble() ?? 0,
      gesture: map['gesture'] as String? ?? 'None',
      score: (map['score'] as num?)?.toDouble() ?? 0,
      xs: _doubles(map['xs']),
      ys: _doubles(map['ys']),
      likelihoods: _doubles(map['likelihoods']),
      fps: (map['fps'] as num?)?.toInt(),
      latencyMs: (map['latencyMs'] as num?)?.toInt(),
    );
  }
}

class ShizukuStatus {
  const ShizukuStatus({required this.granted, required this.running});

  final bool granted;
  final bool running;

  factory ShizukuStatus.fromArguments(Object? arguments) {
    final map = Map<Object?, Object?>.from(arguments as Map);
    return ShizukuStatus(
      granted: map['granted'] == true,
      running: map['running'] == true,
    );
  }
}

List<double> _doubles(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [for (final item in value) (item as num).toDouble()];
}

class SwipePlatform {
  SwipePlatform({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.airswipe/gestures');

  static const channelName = 'com.airswipe/gestures';

  final MethodChannel _channel;
  Completer<void>? _ready;

  void listenCommands({
    required Future<void> Function() onStart,
    required Future<void> Function() onStop,
    required void Function(String message) onCameraError,
    required Future<void> Function(Object? arguments) onHand,
    required void Function(ShizukuStatus status) onShizukuStatus,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'start':
          unawaited(Future<void>(onStart));
        case 'stop':
          unawaited(Future<void>(onStop));
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
        case 'hand':
          await onHand(call.arguments);
        case 'shizukuStatus':
          onShizukuStatus(ShizukuStatus.fromArguments(call.arguments));
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

  Future<bool> swipeUp() async {
    return await _channel.invokeMethod<bool>('swipeUp') ?? false;
  }

  Future<bool> swipeDown() async {
    return await _channel.invokeMethod<bool>('swipeDown') ?? false;
  }

  Future<ShizukuStatus> getShizukuStatus() async {
    return ShizukuStatus.fromArguments(
      await _channel.invokeMethod('getShizukuStatus'),
    );
  }

  Future<ShizukuStatus> requestShizukuPermission() async {
    return ShizukuStatus.fromArguments(
      await _channel.invokeMethod('requestShizukuPermission'),
    );
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

  void showSkeleton(HandEvent? hand) {
    if (hand == null || !hand.hasVisibleJoint) {
      _channel.invokeMethod<void>('showSkeleton');
      return;
    }
    _channel.invokeMethod<void>('showSkeleton', {
      'width': hand.width,
      'height': hand.height,
      'xs': hand.xs,
      'ys': hand.ys,
      'likelihoods': hand.likelihoods,
    });
  }
}
