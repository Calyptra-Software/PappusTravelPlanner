import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/features/map/finite_camera.dart';

/// The guard that keeps a pinch from hanging the map.
///
/// The failure it exists for is worth restating, because nothing about it is
/// obvious from the symptom: a camera carrying a NaN makes `Rect.overlaps`
/// answer *true*, `MarkerLayer` therefore culls none of the copies it draws of
/// each marker in the neighboring worlds, and its loop — which steps by the
/// world's width, a step NaN swallows — runs until the heap is gone. The first
/// test below is that fact, kept here so the reasoning cannot quietly rot.
void main() {
  MapCamera cameraAt(LatLng center, double zoom) => MapCamera(
    crs: const Epsg3857(),
    center: center,
    zoom: zoom,
    rotation: 0,
    nonRotatedSize: const Size(393, 852),
    minZoom: 2,
    maxZoom: 19,
  );

  test('a NaN rectangle reads as visible, which is what makes this fatal', () {
    // Every rejection in `Rect.overlaps` is a comparison, and every comparison
    // with NaN is false — so the method falls through to "yes, these overlap".
    const viewport = Rect.fromLTRB(0, 0, 393, 852);
    final nowhere = Rect.fromLTRB(double.nan, 0, double.nan, 28);
    expect(viewport.overlaps(nowhere), isTrue);

    // And the step that would have walked the marker out of view stands still.
    expect(double.nan - 7406.0, isNaN);
  });

  test('an ordinary camera passes through untouched', () {
    final camera = cameraAt(const LatLng(53.55, 9.99), 10.83);
    expect(const FiniteCamera().constrain(camera), same(camera));
  });

  test('a camera whose centre is not a number is refused', () {
    // `moveRaw` drops a move whose constraint answers null, so refusing here
    // keeps the last good camera and costs a single gesture event.
    expect(
      const FiniteCamera().constrain(
        cameraAt(LatLng(double.nan, double.nan), 10.83),
      ),
      isNull,
    );
    expect(
      const FiniteCamera().constrain(
        cameraAt(LatLng(53.55, double.nan), 10.83),
      ),
      isNull,
    );
  });

  test('a non-finite zoom cannot even be built here — but can be shipped', () {
    // `MapCamera` asserts its zoom is finite, so this throws in a test and in
    // debug. Asserts are stripped from profile and release builds, which is
    // exactly where the freeze was measured — so the guard checks the zoom as
    // well, and this test records why that check can have no direct test.
    expect(
      () => cameraAt(const LatLng(53.55, 9.99), double.negativeInfinity),
      throwsAssertionError,
    );
  });

  group('composed with a second rule', () {
    // Only one constraint can be given to a map, so a map that has something
    // else to say about the camera has to compose — and this guard goes first,
    // since a rule about *where* the camera is says nothing useful when the
    // answer is not a number.
    final world = LatLngBounds(const LatLng(-85, -180), const LatLng(85, 180));

    test('the inner rule is asked once the numbers are numbers', () {
      final constraint = FiniteCamera(
        then: CameraConstraint.contain(bounds: world),
      );
      // At zoom 0 the whole world is 256 px wide and the viewport is wider
      // than that, which is exactly when flutter_map draws the next copy of it
      // beside this one.
      expect(constraint.constrain(cameraAt(const LatLng(0, 0), 0)), isNull);
      expect(constraint.constrain(cameraAt(const LatLng(0, 0), 5)), isNotNull);
    });

    test('a camera that is not a number never reaches the inner rule', () {
      var asked = false;
      final constraint = FiniteCamera(then: _Watching(() => asked = true));

      expect(
        constraint.constrain(cameraAt(LatLng(double.nan, double.nan), 10)),
        isNull,
      );
      expect(asked, isFalse);
    });
  });
}

/// Records whether it was consulted at all.
class _Watching extends CameraConstraint {
  const _Watching(this.onAsked);

  final void Function() onAsked;

  @override
  MapCamera? constrain(MapCamera camera) {
    onAsked();
    return camera;
  }
}
