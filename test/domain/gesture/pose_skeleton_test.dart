import 'package:air_swipe/domain/gesture/pose_skeleton.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('places a landmark in upright coordinates', () {
    final skeleton = poseSkeleton(
      imageWidth: 10,
      imageHeight: 20,
      rotationDegrees: 90,
      landmarks: const [
        SkeletonLandmark(index: 15, x: 3, y: 4, likelihood: 0.8),
      ],
    );

    expect(skeleton.width, 20);
    expect(skeleton.height, 10);
    expect(skeleton.xs[15], 16);
    expect(skeleton.ys[15], 3);
    expect(skeleton.likelihoods[15], 0.8);
    expect(skeleton.likelihoods[16], 0);
    expect(skeleton.hasVisibleJoint, isTrue);
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
}
