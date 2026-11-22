import 'package:air_swipe/domain/gesture/image_upright.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('uprightFrameSize', () {
    test('rotation 0 and 180 keep the raw frame', () {
      for (final rotation in [0, 180]) {
        final frame = uprightFrameSize(
          imageWidth: 10,
          imageHeight: 20,
          rotationDegrees: rotation,
        );
        expect(frame.width, 10, reason: 'rotation $rotation');
        expect(frame.height, 20, reason: 'rotation $rotation');
      }
    });

    test('rotation 90 and 270 swap the axes', () {
      for (final rotation in [90, 270]) {
        final frame = uprightFrameSize(
          imageWidth: 10,
          imageHeight: 20,
          rotationDegrees: rotation,
        );
        expect(frame.width, 20, reason: 'rotation $rotation');
        expect(frame.height, 10, reason: 'rotation $rotation');
      }
    });
  });
}
