import 'dart:async';

import 'package:air_swipe/data/swipe_platform.dart';
import 'package:air_swipe/domain/gesture/wrist_swipe_tracker.dart';

/// Turns native GestureRecognizer results into swipes.
///
/// The camera service runs the model. This session only keeps the wrist of an
/// open palm and asks the Shizuku shell executor to swipe.
class HandSession {
  HandSession({required this.platform, WristSwipeTracker? tracker})
    : tracker = tracker ?? WristSwipeTracker();

  final SwipePlatform platform;
  final WristSwipeTracker tracker;

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
    await platform.stopListening();
    platform.showSkeleton(null);
    _notify();
  }

  Future<void> onHand(Object? arguments) async {
    if (!listening) {
      return;
    }
    try {
      final hand = HandEvent.fromArguments(arguments);
      if (hand.xs.isEmpty || !hand.hasVisibleJoint) {
        platform.showSkeleton(null);
      } else {
        platform.showSkeleton(hand);
      }
      final direction = tracker.addPoints(
        at: DateTime.now(),
        gesture: hand.gesture,
        points: hand.likelihoods.isEmpty
            ? const []
            : [
                HandPoint(y: hand.ys[0], likelihood: hand.likelihoods[0]),
              ],
        imageHeight: hand.height,
      );
      if (direction != null) {
        lastGesture = direction;
        final swiped = direction == SwipeDirection.up
            ? await platform.swipeUp()
            : await platform.swipeDown();
        if (!swiped) {
          error = 'Shizuku chưa sẵn sàng, hoặc vuốt bị chặn.';
        } else {
          error = null;
        }
        _notify();
      }
    } catch (error) {
      this.error = error.toString();
      _notify();
    }
  }
}
