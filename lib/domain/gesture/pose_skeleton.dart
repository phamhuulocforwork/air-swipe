import 'package:air_swipe/domain/gesture/image_upright.dart';

/// One raw pose landmark before it is rotated upright.
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

/// Converts raw image landmarks into upright preview space.
PoseSkeleton poseSkeleton({
  required double imageWidth,
  required double imageHeight,
  required int rotationDegrees,
  required List<SkeletonLandmark> landmarks,
}) {
  final xs = List<double>.filled(PoseSkeleton.landmarkCount, 0);
  final ys = List<double>.filled(PoseSkeleton.landmarkCount, 0);
  final likelihoods = List<double>.filled(PoseSkeleton.landmarkCount, 0);
  var width = imageWidth;
  var height = imageHeight;
  for (final landmark in landmarks) {
    if (landmark.index < 0 || landmark.index >= PoseSkeleton.landmarkCount) {
      continue;
    }
    final upright = uprightPoint(
      x: landmark.x,
      y: landmark.y,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      rotationDegrees: rotationDegrees,
    );
    width = upright.width;
    height = upright.height;
    xs[landmark.index] = upright.x;
    ys[landmark.index] = upright.y;
    likelihoods[landmark.index] = landmark.likelihood;
  }
  return PoseSkeleton(
    width: width,
    height: height,
    xs: xs,
    ys: ys,
    likelihoods: likelihoods,
  );
}
