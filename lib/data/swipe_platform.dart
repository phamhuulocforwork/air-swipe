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
  });

  final double width;
  final double height;
  final String gesture;
  final double score;
  final List<double> xs;
  final List<double> ys;
  final List<double> likelihoods;

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
        case 'hand':
          await onHand(call.arguments);
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
