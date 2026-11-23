enum SwipeDirection { up, down }

/// One pose landmark already mapped into upright image space.
class HandPoint {
  const HandPoint({required this.y, required this.likelihood});

  final double y;
  final double likelihood;
}

class _Sample {
  const _Sample(this.at, this.yNorm);

  final DateTime at;
  final double yNorm;
}

/// Turns upright wrist positions into swipe-up / swipe-down.
///
/// A sample is stored only when [gesture] is `Open_Palm`. Any other label
/// clears the window.
///
/// [yIncreasesDownward] is true when upright [HandPoint.y] grows toward the
/// bottom of the frame. Flip it if a device reports the opposite axis.
class WristSwipeTracker {
  WristSwipeTracker({
    this.sensitivity = 0.18,
    this.cooldown = const Duration(milliseconds: 1500),
    this.window = const Duration(milliseconds: 350),
    this.minLikelihood = 0.5,
    this.minElapsed = const Duration(milliseconds: 120),
    this.yIncreasesDownward = true,
    this.upOnly = false,
  });

  double sensitivity;
  Duration cooldown;
  bool upOnly;
  final Duration window;
  final double minLikelihood;
  final Duration minElapsed;

  /// When false, a decrease in raw upright Y is treated as a downward swipe.
  final bool yIncreasesDownward;

  final List<_Sample> _samples = [];
  DateTime? _cooldownUntil;

  bool blocksInference(DateTime at) {
    final until = _cooldownUntil;
    return until != null && at.isBefore(until);
  }

  SwipeDirection? addPoints({
    required DateTime at,
    required String gesture,
    required List<HandPoint> points,
    required double imageHeight,
  }) {
    if (blocksInference(at)) {
      return null;
    }
    if (gesture != 'Open_Palm') {
      _samples.clear();
      return null;
    }

    HandPoint? best;
    for (final point in points) {
      if (best == null || point.likelihood > best.likelihood) {
        best = point;
      }
    }

    if (best == null || best.likelihood < minLikelihood || imageHeight <= 0) {
      _samples.clear();
      return null;
    }

    final normalized = best.y / imageHeight;
    final yNorm = yIncreasesDownward ? normalized : 1 - normalized;
    _samples.add(_Sample(at, yNorm));
    _samples.removeWhere((sample) => at.difference(sample.at) > window);
    if (_samples.length < 2) {
      return null;
    }

    final oldest = _samples.first;
    if (at.difference(oldest.at) < minElapsed) {
      return null;
    }

    final dy = yNorm - oldest.yNorm;
    if (dy.abs() < sensitivity) {
      return null;
    }

    final direction = dy < 0 ? SwipeDirection.up : SwipeDirection.down;
    if (upOnly && direction == SwipeDirection.down) {
      _samples.clear();
      return null;
    }
    _samples.clear();
    _cooldownUntil = at.add(cooldown);
    return direction;
  }
}
