import 'package:air_swipe/domain/gesture/pose_skeleton.dart';
import 'package:air_swipe/domain/gesture/wrist_swipe_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps an upright landmark and swaps the frame at 90 and 270', () {
    for (final rotation in [90, 270]) {
      final skeleton = poseSkeleton(
        imageWidth: 10,
        imageHeight: 20,
        rotationDegrees: rotation,
        landmarks: const [
          SkeletonLandmark(index: 15, x: 3, y: 4, likelihood: 0.8),
        ],
      );

      expect(skeleton.width, 20, reason: 'rotation $rotation');
      expect(skeleton.height, 10, reason: 'rotation $rotation');
      expect(skeleton.xs[15], 3, reason: 'rotation $rotation');
      expect(skeleton.ys[15], 4, reason: 'rotation $rotation');
      expect(skeleton.likelihoods[15], 0.8);
      expect(skeleton.likelihoods[16], 0);
      expect(skeleton.hasVisibleJoint, isTrue);
    }
  });

  test('keeps an upright landmark and the raw frame at 0 and 180', () {
    for (final rotation in [0, 180]) {
      final skeleton = poseSkeleton(
        imageWidth: 10,
        imageHeight: 20,
        rotationDegrees: rotation,
        landmarks: const [
          SkeletonLandmark(index: 15, x: 3, y: 4, likelihood: 0.8),
        ],
      );

      expect(skeleton.width, 10, reason: 'rotation $rotation');
      expect(skeleton.height, 20, reason: 'rotation $rotation');
      expect(skeleton.xs[15], 3, reason: 'rotation $rotation');
      expect(skeleton.ys[15], 4, reason: 'rotation $rotation');
    }
  });

  test('an empty pose still reports the swapped upright frame', () {
    final skeleton = poseSkeleton(
      imageWidth: 10,
      imageHeight: 20,
      rotationDegrees: 90,
      landmarks: const [],
    );

    expect(skeleton.width, 20);
    expect(skeleton.height, 10);
    expect(skeleton.hasVisibleJoint, isFalse);
  });

  test('a faint pose has no visible joint', () {
    final skeleton = poseSkeleton(
      imageWidth: 10,
      imageHeight: 20,
      rotationDegrees: 0,
      landmarks: const [
        SkeletonLandmark(index: 0, x: 1, y: 1, likelihood: 0.1),
      ],
    );

    expect(skeleton.hasVisibleJoint, isFalse);
  });

  test('rotation 270 keeps wrist y so a downward move is a down swipe', () {
    final tracker = WristSwipeTracker();
    final t0 = DateTime(2026, 1, 1);
    SwipeDirection? direction;
    const ys = [20.0, 50.0, 80.0];

    for (var i = 0; i < ys.length; i++) {
      final skeleton = poseSkeleton(
        imageWidth: 100,
        imageHeight: 200,
        rotationDegrees: 270,
        landmarks: [
          SkeletonLandmark(index: 15, x: 10, y: ys[i], likelihood: 0.9),
        ],
      );
      expect(skeleton.ys[15], ys[i]);
      expect(skeleton.height, 100);
      final swiped = tracker.addPoints(
        at: t0.add(Duration(milliseconds: 150 * i)),
        points: [
          HandPoint(y: skeleton.ys[15], likelihood: skeleton.likelihoods[15]),
        ],
        imageHeight: skeleton.height,
      );
      direction ??= swiped;
    }

    expect(direction, SwipeDirection.down);
  });
}
