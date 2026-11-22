import 'package:air_swipe/domain/gesture/image_upright.dart';

/// One ML Kit pose landmark, already in upright image space.
class SkeletonLandmark {
  const SkeletonLandmark({
    required this.index,
    required this.x,
    required this.y,
    required this.likelihood,
  });

  final int index;
  final double x;
  final double y;
  final double likelihood;
}

/// Upright landmark arrays, one slot per ML Kit pose landmark.
class PoseSkeleton {
  const PoseSkeleton({
    required this.width,
    required this.height,
    required this.xs,
    required this.ys,
    required this.likelihoods,
  });

  static const landmarkCount = 33;

  final double width;
  final double height;
  final List<double> xs;
  final List<double> ys;
  final List<double> likelihoods;

  bool get hasVisibleJoint => likelihoods.any((value) => value >= 0.3);
}

/// Copies upright ML Kit landmarks and reports the upright frame size.
///
/// [rotationDegrees] only swaps [imageWidth] and [imageHeight] at 90 and 270.
/// Landmark x and y are already upright, so they are stored unchanged.
PoseSkeleton poseSkeleton({
  required double imageWidth,
  required double imageHeight,
  required int rotationDegrees,
  required List<SkeletonLandmark> landmarks,
}) {
  final frame = uprightFrameSize(
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    rotationDegrees: rotationDegrees,
  );
  final xs = List<double>.filled(PoseSkeleton.landmarkCount, 0);
  final ys = List<double>.filled(PoseSkeleton.landmarkCount, 0);
  final likelihoods = List<double>.filled(PoseSkeleton.landmarkCount, 0);
  for (final landmark in landmarks) {
    if (landmark.index < 0 || landmark.index >= PoseSkeleton.landmarkCount) {
      continue;
    }
    xs[landmark.index] = landmark.x;
    ys[landmark.index] = landmark.y;
    likelihoods[landmark.index] = landmark.likelihood;
  }
  return PoseSkeleton(
    width: frame.width,
    height: frame.height,
    xs: xs,
    ys: ys,
    likelihoods: likelihoods,
  );
}
