import 'package:air_swipe/domain/gesture/wrist_swipe_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

HandPoint _point(double y, [double likelihood = 0.9]) {
  return HandPoint(y: y, likelihood: likelihood);
}

void main() {
  final t0 = DateTime(2026, 1, 1);

  WristSwipeTracker tracker() => WristSwipeTracker();

  group('WristSwipeTracker', () {
    test('emits up when the hand moves up past the threshold', () {
      final result = tracker()
        ..addPoints(
          at: t0,
          points: [_point(80)],
          imageHeight: 100,
        );
      expect(
        result.addPoints(
          at: t0.add(const Duration(milliseconds: 200)),
          points: [_point(50)],
          imageHeight: 100,
        ),
        SwipeDirection.up,
      );
    });

    test('emits down when the hand moves down past the threshold', () {
      final swipe = tracker();
      swipe.addPoints(at: t0, points: [_point(20)], imageHeight: 100);
      expect(
        swipe.addPoints(
          at: t0.add(const Duration(milliseconds: 200)),
          points: [_point(50)],
          imageHeight: 100,
        ),
        SwipeDirection.down,
      );
    });

    test('ignores travel below the sensitivity', () {
      final swipe = tracker();
      swipe.addPoints(at: t0, points: [_point(50)], imageHeight: 100);
      expect(
        swipe.addPoints(
          at: t0.add(const Duration(milliseconds: 200)),
          points: [_point(60)],
          imageHeight: 100,
        ),
        isNull,
      );
    });

    test('a low-likelihood sample clears the buffer', () {
      final swipe = tracker();
      swipe.addPoints(at: t0, points: [_point(80)], imageHeight: 100);
      expect(
        swipe.addPoints(
          at: t0.add(const Duration(milliseconds: 40)),
          points: [_point(80, 0.1)],
          imageHeight: 100,
        ),
        isNull,
      );
      expect(
        swipe.addPoints(
          at: t0.add(const Duration(milliseconds: 200)),
          points: [_point(20)],
          imageHeight: 100,
        ),
        isNull,
      );
    });

    test('cooldown swallows a second trigger', () {
      final swipe = tracker();
      swipe.addPoints(at: t0, points: [_point(80)], imageHeight: 100);
      expect(
        swipe.addPoints(
          at: t0.add(const Duration(milliseconds: 200)),
          points: [_point(50)],
          imageHeight: 100,
        ),
        SwipeDirection.up,
      );

      expect(
        swipe.addPoints(
          at: t0.add(const Duration(milliseconds: 900)),
          points: [_point(20)],
          imageHeight: 100,
        ),
        isNull,
      );
      expect(
        swipe.addPoints(
          at: t0.add(const Duration(milliseconds: 1100)),
          points: [_point(80)],
          imageHeight: 100,
        ),
        isNull,
      );

      swipe.addPoints(
        at: t0.add(const Duration(milliseconds: 1700)),
        points: [_point(20)],
        imageHeight: 100,
      );
      expect(
        swipe.addPoints(
          at: t0.add(const Duration(milliseconds: 1900)),
          points: [_point(50)],
          imageHeight: 100,
        ),
        SwipeDirection.down,
      );
    });

    test('does not fire when the window is shorter than 120ms', () {
      final swipe = tracker();
      swipe.addPoints(at: t0, points: [_point(80)], imageHeight: 100);
      expect(
        swipe.addPoints(
          at: t0.add(const Duration(milliseconds: 100)),
          points: [_point(20)],
          imageHeight: 100,
        ),
        isNull,
      );
    });

    test('a new sensitivity applies on the next sample', () {
      final swipe = tracker();
      swipe.addPoints(at: t0, points: [_point(50)], imageHeight: 100);
      expect(
        swipe.addPoints(
          at: t0.add(const Duration(milliseconds: 200)),
          points: [_point(60)],
          imageHeight: 100,
        ),
        isNull,
      );

      swipe.sensitivity = 0.05;
      expect(
        swipe.addPoints(
          at: t0.add(const Duration(milliseconds: 250)),
          points: [_point(61)],
          imageHeight: 100,
        ),
        SwipeDirection.down,
      );
    });

    test('picks the landmark with the higher likelihood', () {
      final swipe = tracker();
      swipe.addPoints(
        at: t0,
        points: [_point(10, 0.55), _point(80, 0.95)],
        imageHeight: 100,
      );
      expect(
        swipe.addPoints(
          at: t0.add(const Duration(milliseconds: 200)),
          points: [_point(90, 0.55), _point(50, 0.95)],
          imageHeight: 100,
        ),
        SwipeDirection.up,
      );
    });

    test('inverted Y axis flips the direction', () {
      final swipe = WristSwipeTracker(yIncreasesDownward: false);
      swipe.addPoints(at: t0, points: [_point(80)], imageHeight: 100);
      expect(
        swipe.addPoints(
          at: t0.add(const Duration(milliseconds: 200)),
          points: [_point(50)],
          imageHeight: 100,
        ),
        SwipeDirection.down,
      );
    });
  });
}
