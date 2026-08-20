import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:travelplanner/features/map/location/device_location.dart';

import 'location_fixture.dart';

/// The map's "you are here" from the sensor: what the button does, and — the
/// part worth pinning down — what it does when the answer is "no".
///
/// A refusal, a switched-off receiver and a granted permission are three
/// outcomes of the same press, and each has to reach the map as something it can
/// say out loud. Driven through a stand-in for the platform plugin, so none of
/// this needs a device with a receiver in it.
void main() {
  late FakeGeolocator platform;

  setUp(() {
    platform = FakeGeolocator();
    GeolocatorPlatform.instance = platform;
  });

  /// A container with the provider kept alive, as a screen watching it would.
  (ProviderContainer, DeviceLocationController) open() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(deviceLocationProvider, (_, _) {}, fireImmediately: true);
    return (container, container.read(deviceLocationProvider.notifier));
  }

  DeviceLocationState stateOf(ProviderContainer c) =>
      c.read(deviceLocationProvider);

  test('starts off, with nothing to say', () {
    final (container, _) = open();
    expect(stateOf(container).on, isFalse);
    expect(stateOf(container).fix, isNull);
    expect(stateOf(container).problem, isNull);
  });

  test('a declined permission is an answer, not a crash', () async {
    platform.permission = LocationPermission.denied;
    final (container, controller) = open();

    await controller.start();

    expect(stateOf(container).problem, LocationProblem.denied);
    expect(stateOf(container).on, isFalse, reason: 'nothing is running');
    expect(platform.streamRequested, isFalse);
  });

  test('a permanently blocked permission says so in its own words', () async {
    platform.permission = LocationPermission.deniedForever;
    final (container, controller) = open();

    await controller.start();

    // Distinct from `denied`, because the way out of it is different: this one
    // can only be undone in the system settings, which is what the message
    // offers a button for.
    expect(stateOf(container).problem, LocationProblem.deniedForever);
  });

  test('location switched off device-wide is asked about first', () async {
    platform.serviceEnabled = false;
    final (container, controller) = open();

    await controller.start();

    expect(stateOf(container).problem, LocationProblem.serviceOff);
    // Asked before the permission, so a user with location off is not put
    // through a dialog that would not have helped.
    expect(platform.permissionRequests, 0);
  });

  test('a permission already granted is not asked for again', () async {
    platform.permission = LocationPermission.whileInUse;
    final (container, controller) = open();

    await controller.start();

    expect(platform.permissionRequests, 0);
    expect(stateOf(container).on, isTrue);
    expect(stateOf(container).locating, isTrue, reason: 'no reading yet');
  });

  test('the first reading fills the mark in', () async {
    platform.permission = LocationPermission.whileInUse;
    final (container, controller) = open();
    await controller.start();

    platform.emit(latitude: 53.55, longitude: 10.0, accuracy: 12);
    await pumpEventQueue();

    final fix = stateOf(container).fix;
    expect(fix, isNotNull);
    expect(fix!.position.latitude, 53.55);
    expect(fix.accuracyMeters, 12);
    expect(stateOf(container).locating, isFalse);
  });

  test('a negative accuracy is never handed on as a radius', () async {
    platform.permission = LocationPermission.whileInUse;
    final (container, controller) = open();
    await controller.start();

    // Some platforms report -1 for "no idea", which drawn as a circle is a
    // radius pointing the wrong way.
    platform.emit(latitude: 0, longitude: 0, accuracy: -1);
    await pumpEventQueue();

    expect(stateOf(container).fix!.accuracyMeters, greaterThanOrEqualTo(0));
  });

  test('switching off clears the fix, so the next one reads as a first', () async {
    platform.permission = LocationPermission.whileInUse;
    final (container, controller) = open();
    await controller.start();
    platform.emit(latitude: 53.55, longitude: 10.0, accuracy: 12);
    await pumpEventQueue();

    await controller.toggle();

    // The null-to-fix transition is how a listener recognizes the first reading
    // of a session and centers the map on it exactly once. Leaving the old fix
    // in place would cost the *next* session its centering.
    expect(stateOf(container).fix, isNull);
    expect(stateOf(container).on, isFalse);
    expect(
      platform.streamCancelled,
      isTrue,
      reason: 'the receiver is released',
    );
  });

  test(
    'a reading that arrives after switching off does not switch it on',
    () async {
      platform.permission = LocationPermission.whileInUse;
      final (container, controller) = open();
      await controller.start();
      await controller.toggle();

      platform.emit(latitude: 53.55, longitude: 10.0, accuracy: 12);
      await pumpEventQueue();

      expect(stateOf(container).on, isFalse);
      expect(stateOf(container).fix, isNull);
    },
  );

  test('an error from the stream is reported and stops it', () async {
    platform.permission = LocationPermission.whileInUse;
    final (container, controller) = open();
    await controller.start();

    platform.fail(Exception('no receiver'));
    await pumpEventQueue();

    expect(stateOf(container).problem, LocationProblem.failed);
    expect(stateOf(container).on, isFalse);
  });

  test('the provider stops the receiver when the last screen goes', () async {
    platform.permission = LocationPermission.whileInUse;
    final container = ProviderContainer();
    final subscription = container.listen(
      deviceLocationProvider,
      (_, _) {},
      fireImmediately: true,
    );
    await container.read(deviceLocationProvider.notifier).start();

    subscription.close();
    await pumpEventQueue();
    container.dispose();

    // `autoDispose` is what makes "leaving the map switches the sensor off" a
    // property of the provider rather than something every screen must remember.
    expect(platform.streamCancelled, isTrue);
  });
}
