import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
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
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeGeolocator platform;
  late SharedPreferences prefs;

  setUp(() async {
    platform = FakeGeolocator();
    GeolocatorPlatform.instance = platform;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// A container with the provider kept alive, as a screen watching it would —
  /// which is also what makes the remembered switch resume, since that is the
  /// moment the provider is built.
  (ProviderContainer, DeviceLocationController) open() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    container.listen(deviceLocationProvider, (_, _) {}, fireImmediately: true);
    return (container, container.read(deviceLocationProvider.notifier));
  }

  /// What a previous session left behind: the switch as the user last set it.
  /// Written into the instance the container is about to read, rather than
  /// through `setMockInitialValues` again — that replaces the store under an
  /// already-loaded [SharedPreferences], which would keep answering from its
  /// own cache.
  Future<void> remembered(bool on) => prefs.setBool('map_show_my_location', on);

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

    await controller.stop();

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
      await controller.stop();

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
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
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

  group('the remembered switch', () {
    test('is what a press stores, and switching off clears', () async {
      platform.permission = LocationPermission.whileInUse;
      final (_, controller) = open();

      await controller.start();
      expect(prefs.getBool('map_show_my_location'), isTrue);

      await controller.stop();
      expect(
        prefs.getBool('map_show_my_location'),
        isFalse,
        reason: 'switching off is also a statement about the next map',
      );
    });

    test('survives a press that came to nothing', () async {
      // The receiver was off at the time, which is the case where the *next*
      // map should try again rather than ask again.
      platform.serviceEnabled = false;
      final (_, controller) = open();

      await controller.start();

      expect(prefs.getBool('map_show_my_location'), isTrue);
    });

    test('puts the mark back on when a map opens', () async {
      platform.permission = LocationPermission.whileInUse;
      await remembered(true);

      final (container, _) = open();
      await pumpEventQueue();

      expect(stateOf(container).on, isTrue);
      expect(platform.streamRequested, isTrue);
      expect(
        stateOf(container).startedByHand,
        isFalse,
        reason: 'nobody pressed anything, so no camera moves',
      );
    });

    test('never brings up a permission dialog on its own', () async {
      // The one thing a screen may not do by being opened. Without a grant the
      // resume simply ends, leaving the button to ask.
      platform.permission = LocationPermission.denied;
      await remembered(true);

      final (container, _) = open();
      await pumpEventQueue();

      expect(platform.permissionRequests, 0);
      expect(platform.streamRequested, isFalse);
      expect(stateOf(container).on, isFalse);
    });

    test('says nothing when it comes to nothing', () async {
      platform.serviceEnabled = false;
      await remembered(true);

      final (container, _) = open();
      await pumpEventQueue();

      // A pressed start would report `serviceOff` here, and should. A resume
      // must not: a snackbar on every map opened with location switched off is
      // the sort of help that gets the feature switched back off.
      expect(stateOf(container).problem, isNull);
      expect(stateOf(container).on, isFalse);
    });

    test('is not written by a resume, only read', () async {
      platform.permission = LocationPermission.whileInUse;
      await remembered(true);
      final (_, controller) = open();
      await pumpEventQueue();

      await controller.stop();

      // The resume must not be able to undo the off that follows it.
      expect(prefs.getBool('map_show_my_location'), isFalse);
    });

    test('leaves a fresh install off', () async {
      platform.permission = LocationPermission.whileInUse;
      final (container, _) = open();
      await pumpEventQueue();

      expect(stateOf(container).on, isFalse);
      expect(platform.streamRequested, isFalse);
    });

    test('yields to a press made in the same turn', () async {
      // The connection search's *Use my position* is what makes this ordinary:
      // there the press is what first makes anything watch the provider, so the
      // resume the build schedules and the press race each other. The press
      // wins outright, because it is the half that may bring up the dialog —
      // a resume replacing it would withdraw the question just asked.
      platform.permission = LocationPermission.denied;
      await remembered(true);
      final (container, controller) = open();

      await controller.start();
      await pumpEventQueue();

      expect(platform.permissionRequests, 1, reason: 'the press may ask');
      expect(stateOf(container).problem, LocationProblem.denied);
    });

    test('switching off mid-start leaves no receiver behind', () async {
      // The window is the width of the checks a start waits on, and the resume
      // puts one in flight on every map that opens — so an off pressed in the
      // first second used to leave a receiver running under a button that read
      // *off*.
      platform.permission = LocationPermission.whileInUse;
      final (container, controller) = open();

      final starting = controller.start();
      await controller.stop();
      await starting;
      await pumpEventQueue();

      expect(platform.streamRequested, isFalse);
      expect(stateOf(container).on, isFalse);
    });

    test('a press still centers the map', () async {
      platform.permission = LocationPermission.whileInUse;
      final (container, controller) = open();

      await controller.start();
      platform.emit(latitude: 53.55, longitude: 10.0, accuracy: 12);
      await pumpEventQueue();

      expect(stateOf(container).startedByHand, isTrue);
    });
  });
}
