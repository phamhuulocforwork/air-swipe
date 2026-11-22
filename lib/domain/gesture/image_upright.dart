/// A point mapped into an upright image whose origin is the top-left.
class UprightPoint {
  const UprightPoint({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Maps a landmark in the raw camera buffer into upright coordinates.
///
/// [rotationDegrees] is the clockwise rotation that makes the buffer upright
/// (CameraX `imageInfo.rotationDegrees`).
UprightPoint uprightPoint({
  required double x,
  required double y,
  required double imageWidth,
  required double imageHeight,
  required int rotationDegrees,
}) {
  switch (rotationDegrees) {
    case 90:
      return UprightPoint(
        x: imageHeight - y,
        y: x,
        width: imageHeight,
        height: imageWidth,
      );
    case 180:
      return UprightPoint(
        x: imageWidth - x,
        y: imageHeight - y,
        width: imageWidth,
        height: imageHeight,
      );
    case 270:
      return UprightPoint(
        x: y,
        y: imageWidth - x,
        width: imageHeight,
        height: imageWidth,
      );
    default:
      return UprightPoint(
        x: x,
        y: y,
        width: imageWidth,
        height: imageHeight,
      );
  }
}
