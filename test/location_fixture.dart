/// A stand-in for the location plugin, shared by every test that needs one.
///
/// Lives beside the tests rather than inside one of them because two quite
/// different questions are asked of it — the state machine in
/// `device_location_test.dart`, and what a map does with a reading in
/// `map_picker_test.dart` — and a second copy is how they quietly stop agreeing
/// about what the platform does.
library;

import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Answers what it is told to answer, and records what was asked of it.
class FakeGeolocator extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.denied;

  int permissionRequests = 0;
  bool streamRequested = false;
  bool streamCancelled = false;

  final _positions = StreamController<Position>.broadcast();

  void emit({
    required double latitude,
    required double longitude,
    required double accuracy,
  }) => _positions.add(
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.utc(2026, 8, 19, 9),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    ),
  );

  void fail(Object error) => _positions.addError(error);

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    streamRequested = true;
    // Handed out through a controller of its own so that cancelling it is
    // observable: "the receiver is released" is half of what this feature
    // promises, and it is the half a leak would not otherwise show.
    final out = StreamController<Position>();
    final subscription = _positions.stream.listen(
      out.add,
      onError: out.addError,
    );
    out.onCancel = () async {
      streamCancelled = true;
      await subscription.cancel();
    };
    return out.stream;
  }
}
