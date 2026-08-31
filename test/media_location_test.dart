import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/features/attachments/application/media_location.dart';

/// The switch that lets a photograph bring its place, and the permission behind
/// it — two facts that are deliberately not one, which is exactly what these
/// stand on.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// A container with the platform standing still.
  ProviderContainer containerWith(FakePlatform platform) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        mediaLocationProvider.overrideWithValue(platform),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a fresh install is off, whatever the platform would say', () async {
    final container = containerWith(FakePlatform(MediaLocationAccess.granted));
    final controller = container.read(photoLocationProvider.notifier);
    await controller.refresh();

    // Granted and still off: the permission may be left over from another
    // feature, or from an install before this one. The switch is the answer to
    // "should the app read this", and only the user writes it.
    expect(container.read(photoLocationProvider).enabled, isFalse);
    expect(container.read(photoLocationProvider).active, isFalse);
    expect(await controller.activeNow(), isFalse);
  });

  test(
    'turning it on remembers it only when the permission is given',
    () async {
      final container = containerWith(FakePlatform(MediaLocationAccess.denied));
      final controller = container.read(photoLocationProvider.notifier);

      expect(await controller.enable(), MediaLocationAccess.denied);
      // A switch left standing over a refusal would be a control claiming the
      // feature is running when nothing can come of it.
      expect(container.read(photoLocationProvider).enabled, isFalse);
      expect(prefs.getBool('photo_location_enabled'), isNot(true));
    },
  );

  test('turning it on and being allowed survives a relaunch', () async {
    final first = containerWith(FakePlatform(MediaLocationAccess.granted));
    expect(
      await first.read(photoLocationProvider.notifier).enable(),
      MediaLocationAccess.granted,
    );
    expect(first.read(photoLocationProvider).active, isTrue);

    // A second container is the next launch: nothing but the stored bool
    // crosses over, and the permission is asked about again.
    final next = containerWith(FakePlatform(MediaLocationAccess.granted));
    expect(next.read(photoLocationProvider).enabled, isTrue);
    expect(await next.read(photoLocationProvider.notifier).activeNow(), isTrue);
  });

  test('a permission taken away since leaves the switch inactive', () async {
    await prefs.setBool('photo_location_enabled', true);
    final container = containerWith(
      FakePlatform(MediaLocationAccess.deniedForever),
    );
    final controller = container.read(photoLocationProvider.notifier);

    expect(await controller.activeNow(), isFalse);
    // The stored switch is untouched — the user did not change their mind, the
    // system did — but nothing reads it on its own.
    expect(container.read(photoLocationProvider).enabled, isTrue);
    expect(container.read(photoLocationProvider).active, isFalse);
  });

  test('turning it off is the switch alone', () async {
    await prefs.setBool('photo_location_enabled', true);
    final container = containerWith(FakePlatform(MediaLocationAccess.granted));
    final controller = container.read(photoLocationProvider.notifier);
    await controller.refresh();
    expect(container.read(photoLocationProvider).active, isTrue);

    await controller.disable();

    // The grant stays — an app cannot hand one back without killing its own
    // process — and what stops is the app asking.
    expect(container.read(photoLocationProvider).active, isFalse);
    expect(await controller.activeNow(), isFalse);
    expect(
      container.read(photoLocationProvider).access,
      MediaLocationAccess.granted,
    );
  });

  group('where the question exists at all', () {
    test('Android 10 and later, whichever way the answer went', () async {
      for (final access in [
        MediaLocationAccess.granted,
        MediaLocationAccess.denied,
        MediaLocationAccess.deniedForever,
      ]) {
        final container = containerWith(FakePlatform(access));
        await container.read(photoLocationProvider.notifier).refresh();
        expect(container.read(photoLocationProvider).supported, isTrue);
      }
    });

    test('nowhere a photograph arrives intact', () async {
      for (final access in [
        MediaLocationAccess.notNeeded,
        MediaLocationAccess.unsupported,
      ]) {
        final container = containerWith(FakePlatform(access));
        await container.read(photoLocationProvider.notifier).refresh();
        // No switch is drawn: one offering to turn on what is already on would
        // be a control that does nothing.
        expect(container.read(photoLocationProvider).supported, isFalse);
      }
    });

    test('and not before the platform has answered', () {
      final container = containerWith(FakePlatform(MediaLocationAccess.denied));
      // Read before the refresh has come back: still unknown, which is not the
      // same as "no", and a control drawn on the guess would flip under the
      // finger a moment later.
      expect(container.read(photoLocationProvider).access, isNull);
      expect(container.read(photoLocationProvider).supported, isFalse);
    });
  });
}

/// The platform with one fixed answer. The real one is a method channel into
/// `MediaLocationBridge.kt`, which no test can reach.
class FakePlatform extends MediaLocationChannel {
  FakePlatform(this.access, {this.position});

  final MediaLocationAccess access;
  final LatLng? position;

  @override
  Future<MediaLocationAccess> status() async => access;

  @override
  Future<MediaLocationAccess> request() async => access;

  @override
  Future<LatLng?> readLocation(String uri) async =>
      access == MediaLocationAccess.granted ? position : null;
}
