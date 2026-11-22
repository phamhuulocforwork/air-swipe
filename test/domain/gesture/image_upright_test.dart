import 'package:air_swipe/domain/gesture/image_upright.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('uprightPoint', () {
    test('rotation 0 keeps the raw point', () {
      final point = uprightPoint(
        x: 3,
        y: 4,
        imageWidth: 10,
        imageHeight: 20,
        rotationDegrees: 0,
      );
      expect(point.x, 3);
      expect(point.y, 4);
      expect(point.width, 10);
      expect(point.height, 20);
    });

    test('rotation 90 maps raw x onto upright y', () {
      final point = uprightPoint(
        x: 3,
        y: 4,
        imageWidth: 10,
        imageHeight: 20,
        rotationDegrees: 90,
      );
      expect(point.x, 16);
      expect(point.y, 3);
      expect(point.width, 20);
      expect(point.height, 10);
    });

    test('rotation 180 flips both axes', () {
      final point = uprightPoint(
        x: 3,
        y: 4,
        imageWidth: 10,
        imageHeight: 20,
        rotationDegrees: 180,
      );
      expect(point.x, 7);
      expect(point.y, 16);
      expect(point.height, 20);
    });

    test('rotation 270 maps raw x from the right edge onto upright y', () {
      final point = uprightPoint(
        x: 3,
        y: 4,
        imageWidth: 10,
        imageHeight: 20,
        rotationDegrees: 270,
      );
      expect(point.x, 4);
      expect(point.y, 7);
      expect(point.width, 20);
      expect(point.height, 10);
    });
  });
}
