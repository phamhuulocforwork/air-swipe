/// Width and height of the upright image ML Kit already returns landmarks in.
class UprightFrame {
  const UprightFrame({required this.width, required this.height});

  final double width;
  final double height;
}

/// Display size for landmarks that are already upright.
///
/// ML Kit rotates the buffer itself when [rotationDegrees] is passed with the
/// input image. Landmark x/y are in that upright space. Only the frame size
/// swaps when the buffer was rotated 90 or 270 degrees.
UprightFrame uprightFrameSize({
  required double imageWidth,
  required double imageHeight,
  required int rotationDegrees,
}) {
  switch (rotationDegrees) {
    case 90:
    case 270:
      return UprightFrame(width: imageHeight, height: imageWidth);
    default:
      return UprightFrame(width: imageWidth, height: imageHeight);
  }
}
