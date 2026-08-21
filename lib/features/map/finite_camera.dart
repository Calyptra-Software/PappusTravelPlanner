import 'package:flutter_map/flutter_map.dart';

/// Refuses a camera whose numbers are not numbers.
///
/// A fast pinch hands flutter_map's focal-point arithmetic two pointers that
/// can meet, and the projection that follows then divides by zero: the camera
/// arrives carrying a NaN. Nothing downstream tests for it, and one place
/// answers catastrophically — `Rect.overlaps` returns **true** against a NaN
/// rectangle, because each of its four rejection tests is a comparison and
/// every comparison with NaN is false. `MarkerLayer` culls the copies it draws
/// of each marker in the neighboring worlds with exactly that call, in a loop
/// that steps by the world's width and stops at the first copy culled. Against
/// a NaN camera no copy is ever culled, and the step never moves either
/// (`NaN - 7406 == NaN`), so the loop runs until the heap is gone.
///
/// Measured on the phone: one build of **twelve** markers grew its list to
/// 33 554 431 entries and the heap to 2.8 GB, all of it `Positioned` and the
/// four doubles each one holds. The frame never ended, which is why this
/// presents as "Pappus reagiert nicht" — an ANR, not a crash — and why the
/// zoom, the marker count and the tile layer all looked innocent while it
/// happened.
///
/// [MapController.moveRaw] drops a move whose constraint returns null, so
/// refusing here keeps the last good camera and costs that one gesture event.
/// There is nothing to repair and nothing to clamp to: a position that is not a
/// number was never a position, and the next event carries a real one.
class FiniteCamera extends CameraConstraint {
  /// Const so it can sit in a `const MapOptions`.
  ///
  /// [then] is applied after this one, for a map that has a second thing to say
  /// about where the camera may go. Only one constraint can be given to a map,
  /// so composing is the only way to keep this guard while adding another — and
  /// this one goes first, since a rule about *where* the camera is says nothing
  /// useful when the answer is not a number.
  const FiniteCamera({this.then});

  final CameraConstraint? then;

  @override
  MapCamera? constrain(MapCamera camera) {
    if (!camera.zoom.isFinite ||
        !camera.center.latitude.isFinite ||
        !camera.center.longitude.isFinite) {
      return null;
    }
    // Not `then?.constrain(camera) ?? camera`: that reads a *refusal* from the
    // inner rule as "nothing to say" and hands the camera back anyway, which is
    // the one thing composing must not do.
    final inner = then;
    return inner == null ? camera : inner.constrain(camera);
  }
}
