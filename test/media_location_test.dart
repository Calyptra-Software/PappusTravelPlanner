import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/features/attachments/application/media_location.dart';

import 'support/fake_media_location.dart';

/// The switch that lets a photograph bring its place, and the permission behind
/// it — two facts that are deliberately not one, which is exactly what these
/// stand on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// A container with the platform standing still — [startup] being what it
  /// said before the first frame (which `main` resolves and overrides in), and
  /// [now] what it would say if asked again, which is how a permission revoked
  /// while the app runs is modelled.
  ProviderContainer containerWith(
    MediaLocationAccess startup, {
    MediaLocationAccess? now,
    LatLng? position,
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bootstrapMediaLocationProvider.overrideWithValue(startup),
        mediaLocationProvider.overrideWithValue(
          FakeMediaLocation(access: now ?? startup, position: position),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a fresh install is off, whatever the platform would say', () async {
    final container = containerWith(MediaLocationAccess.granted);
    final controller = container.read(photoLocationProvider.notifier);

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
      final container = containerWith(MediaLocationAccess.denied);
      final controller = container.read(photoLocationProvider.notifier);

      expect(await controller.enable(), MediaLocationAccess.denied);
      // A switch left standing over a refusal would be a control claiming the
      // feature is running when nothing can come of it.
      expect(container.read(photoLocationProvider).enabled, isFalse);
      expect(prefs.getBool('photo_location_enabled'), isNot(true));
    },
  );

  test('turning it on and being allowed survives a relaunch', () async {
    final first = containerWith(MediaLocationAccess.granted);
    expect(
      await first.read(photoLocationProvider.notifier).enable(),
      MediaLocationAccess.granted,
    );
    expect(first.read(photoLocationProvider).active, isTrue);

    // A second container is the next launch: nothing but the stored bool
    // crosses over, and the permission is asked about again.
    final next = containerWith(MediaLocationAccess.granted);
    expect(next.read(photoLocationProvider).enabled, isTrue);
    expect(await next.read(photoLocationProvider.notifier).activeNow(), isTrue);
  });

  test('a permission taken away since leaves the switch inactive', () async {
    await prefs.setBool('photo_location_enabled', true);
    // Granted when the app started, gone by the time a photograph is picked.
    final container = containerWith(
      MediaLocationAccess.granted,
      now: MediaLocationAccess.deniedForever,
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
    final container = containerWith(MediaLocationAccess.granted);
    final controller = container.read(photoLocationProvider.notifier);
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
        final container = containerWith(access);
        expect(container.read(photoLocationProvider).supported, isTrue);
      }
    });

    test('nowhere a photograph arrives intact', () async {
      for (final access in [
        MediaLocationAccess.notNeeded,
        MediaLocationAccess.unsupported,
      ]) {
        final container = containerWith(access);
        // No switch is drawn: one offering to turn on what is already on would
        // be a control that does nothing.
        expect(container.read(photoLocationProvider).supported, isFalse);
      }
    });

    test('and it is known on the very first read', () {
      final container = containerWith(MediaLocationAccess.denied);
      // No await anywhere. The answer was fetched before the first frame, so
      // the settings list cannot grow a section under a finger already
      // scrolling it.
      expect(container.read(photoLocationProvider).supported, isTrue);
      expect(
        container.read(photoLocationProvider).access,
        MediaLocationAccess.denied,
      );
    });
  });

  /// The channel itself, against a messenger standing in for Android.
  ///
  /// Everything above stubs [MediaLocationChannel] out; this is the one place
  /// its own two jobs are exercised — turning the bridge's four words into an
  /// answer, and turning a pair of numbers into a position — including every way
  /// the platform can decline to say anything, each of which has to come back as
  /// an answer rather than as an exception in the middle of an import.
  group('the channel into the platform', () {
    const channel = MethodChannel('dev.calyptra.pappus/media_location');
    const platform = MediaLocationChannel();
    late List<MethodCall> calls;

    /// Answers every call with [reply], recording what was asked. Not calling
    /// this at all is itself a case: an unanswered channel is what a build
    /// without the bridge looks like.
    void answering(Object? Function(MethodCall call) reply) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return reply(call);
          });
    }

    setUp(() {
      calls = [];
      // flutter_test reports Android by default, which is the platform this
      // whole file is about; named rather than assumed, since every branch
      // below turns on it.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('reads the four words the bridge can say', () async {
      const words = {
        'granted': MediaLocationAccess.granted,
        'denied': MediaLocationAccess.denied,
        'deniedForever': MediaLocationAccess.deniedForever,
        'notNeeded': MediaLocationAccess.notNeeded,
      };
      for (final entry in words.entries) {
        answering((_) => entry.key);
        expect(await platform.status(), entry.value);
        expect(await platform.request(), entry.value);
      }
      expect(calls.map((c) => c.method), contains('status'));
      expect(calls.map((c) => c.method), contains('request'));
    });

    test('anything else it might say is no answer', () async {
      answering((_) => 'perhaps');
      expect(await platform.status(), MediaLocationAccess.unsupported);
      answering((_) => null);
      expect(await platform.status(), MediaLocationAccess.unsupported);
    });

    test('a refusal from the platform is an answer, not a crash', () async {
      answering((_) => throw PlatformException(code: 'no'));
      expect(await platform.status(), MediaLocationAccess.unsupported);
      expect(await platform.readLocation('content://x'), isNull);
      // Nothing to open and nothing to say about it.
      await expectLater(platform.openSettings(), completes);
    });

    test('no bridge at all is an answer too', () async {
      // No handler registered: the build this app runs in on every platform
      // but Android, and the state a stale engine leaves behind.
      expect(await platform.status(), MediaLocationAccess.unsupported);
      expect(await platform.readLocation('content://x'), isNull);
    });

    test('the way out of a permanent refusal is one call', () async {
      answering((_) => null);
      await platform.openSettings();
      expect(calls.single.method, 'openSettings');
    });

    test('a position comes back as one, and is asked for by URI', () async {
      answering((_) => {'lat': 53.55, 'lon': 10.0});
      expect(
        await platform.readLocation('content://media/external/images/media/7'),
        const LatLng(53.55, 10.0),
      );
      expect(calls.single.method, 'readLocation');
      expect(calls.single.arguments, {
        'uri': 'content://media/external/images/media/7',
      });
    });

    test('and a reading that is not a place does not', () async {
      // Every one of these refused for the reason `exifPosition` refuses it:
      // nothing said, something that is not a number, somewhere off the world,
      // and Null Island — which is what a camera with no fix writes and what a
      // redaction leaves behind.
      final refused = <Object?>[
        null,
        {'lat': '53.55', 'lon': '10.0'},
        {'lat': 91.0, 'lon': 10.0},
        {'lat': 53.55, 'lon': 181.0},
        {'lat': 0.0, 'lon': 0.0},
      ];
      for (final answer in refused) {
        answering((_) => answer);
        expect(await platform.readLocation('content://x'), isNull);
      }
    });

    test('and off Android nothing is asked at all', () async {
      answering((_) => 'granted');
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      // The desktop and the web never had anything taken out of a photograph,
      // so there is no bridge, no permission, and nothing to ask about.
      expect(await platform.status(), MediaLocationAccess.notNeeded);
      expect(await platform.readLocation('content://x'), isNull);
      await platform.openSettings();
      expect(calls, isEmpty);
    });
  });
}
