import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/map/location/device_location.dart';
import 'package:travelplanner/features/map/location/notification_permission.dart';
import 'package:travelplanner/features/map/location/track_recorder.dart';

import 'location_fixture.dart';

/// The recorder: a press starts it, every kept fix is in the database the
/// moment it is kept, and the receiver is shared with the map's mark rather
/// than fought over.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeGeolocator platform;
  late AppDatabase db;
  late SharedPreferences prefs;
  late _FakeNotifications notifications;

  final clock = DateTime.utc(2026, 5, 1, 12);

  setUp(() async {
    platform = FakeGeolocator()..permission = LocationPermission.whileInUse;
    GeolocatorPlatform.instance = platform;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    notifications = _FakeNotifications();
  });
  tearDown(() => db.close());

  (ProviderContainer, TrackRecorderController) open({TripRepository? repo}) {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        if (repo != null) repositoryProvider.overrideWithValue(repo),
        sharedPreferencesProvider.overrideWithValue(prefs),
        recorderClockProvider.overrideWithValue(() => clock),
        notificationPermissionProvider.overrideWithValue(notifications),
      ],
    );
    addTearDown(container.dispose);
    container.listen(trackRecorderProvider, (_, _) {}, fireImmediately: true);
    return (container, container.read(trackRecorderProvider.notifier));
  }

  TrackRecorderState stateOf(ProviderContainer c) =>
      c.read(trackRecorderProvider);

  /// A fix [north] × 0.001° (about 111 m) up the line, [seconds] in.
  Future<void> walk(double north, int seconds, {double accuracy = 5}) async {
    platform.emit(
      latitude: 53.5 + north * 0.001,
      longitude: 9.9,
      accuracy: accuracy,
      timestamp: clock.add(Duration(seconds: seconds)),
    );
    await pumpEventQueue();
  }

  Future<List<RecordingFix>> stored() => db.select(db.recordingFixes).get();

  test('a press starts a recording, with its time and zone', () async {
    final (container, recorder) = open();
    await recorder.start(tripId: null);

    final state = stateOf(container);
    expect(state.running, isTrue);
    expect(state.startedAt, clock);
    final row = await db.select(db.recordings).getSingle();
    expect(row.id, state.recordingId);
    expect(row.startedAt, clock.millisecondsSinceEpoch);
    expect(row.utcOffsetMinutes, clock.toLocal().timeZoneOffset.inMinutes);
    expect(row.stoppedAt, isNull);
  });

  test('every kept fix is written as it is kept; the rest are not', () async {
    final (container, recorder) = open();
    await recorder.start();

    await walk(0, 0);
    await walk(1, 60);
    await walk(1.00002, 61); // about 2 m: the fix wandering
    await walk(1.5, 62, accuracy: 120); // too unsure of itself
    await walk(2, 120);
    await pumpEventQueue();

    final fixes = await stored();
    expect(fixes, hasLength(3));
    expect({for (final f in fixes) f.segment}, {0});
    expect(fixes.last.recordedAt, clock.millisecondsSinceEpoch + 120000);

    final state = stateOf(container);
    expect(state.lines.single, hasLength(3));
    expect(state.meters, closeTo(222, 2));
  });

  test('a declined permission is an answer, and nothing is written', () async {
    platform.permission = LocationPermission.denied;
    final (container, recorder) = open();
    await recorder.start();

    expect(stateOf(container).problem, LocationProblem.denied);
    expect(stateOf(container).recordingId, isNull);
    expect(await db.select(db.recordings).get(), isEmpty);
    expect(platform.streamRequested, isFalse);
  });

  test('stopping releases the receiver and marks the recording', () async {
    final (container, recorder) = open();
    await recorder.start();
    await walk(0, 0);
    await walk(1, 60);

    await recorder.stop();
    await pumpEventQueue();

    expect(platform.streamCancelled, isTrue);
    final state = stateOf(container);
    expect(state.running, isFalse);
    expect(state.recordingId, isNotNull, reason: 'held, not thrown away');
    final row = await db.select(db.recordings).getSingle();
    expect(row.stoppedAt, clock.millisecondsSinceEpoch);
    expect(await stored(), hasLength(2));

    // A reading arriving afterwards is not recorded.
    await walk(2, 120);
    expect(await stored(), hasLength(2));
  });

  test('resuming records into a new segment, keeping the gap', () async {
    final (container, recorder) = open();
    await recorder.start();
    await walk(0, 0);
    await walk(1, 60);
    await recorder.stop();

    await recorder.resume();
    // Close to where it stopped, which would not be a step if it were measured
    // against the last fix: a new segment starts afresh.
    await walk(1.00002, 600);
    await walk(2, 660);
    await pumpEventQueue();

    final fixes = await stored();
    expect([for (final f in fixes) f.segment], [0, 0, 1, 1]);
    final state = stateOf(container);
    expect(state.running, isTrue);
    expect(state.lines, hasLength(2));
    expect(
      state.meters,
      closeTo(222, 2),
      reason: 'the gap is not counted as distance',
    );
    expect((await db.select(db.recordings).getSingle()).stoppedAt, isNull);
  });

  test('a recording the app was stopped in can be continued', () async {
    // What a fresh start finds: a recording with fixes and no stop.
    final id = await db.recordingDao.startRecording(
      startedAt: clock,
      utcOffset: const Duration(hours: 2),
    );
    await db.recordingDao.addFixes(id, 0, [
      (position: const LatLng(53.5, 9.9), at: clock),
      (position: const LatLng(53.501, 9.9), at: clock.add(_minute)),
    ]);

    final (container, recorder) = open();
    await recorder.resume();

    final state = stateOf(container);
    expect(state.recordingId, id);
    expect(state.running, isTrue);
    expect(state.startedAt, clock);
    expect(state.lines.first, hasLength(2), reason: 'what it had is drawn');
    expect(state.lines.last, isEmpty, reason: 'and the next is new');
    expect(state.meters, closeTo(111, 1));

    await walk(3, 900);
    await pumpEventQueue();
    expect([for (final f in await stored()) f.segment], [0, 0, 1]);
  });

  group('a recording left in the database', () {
    Future<int> left({required bool stopped, int? tripId}) async {
      final trip = tripId == null
          ? null
          : await db.into(db.trips).insert(TripsCompanion.insert(title: 'T'));
      final id = await db.recordingDao.startRecording(
        tripId: trip,
        startedAt: clock,
        utcOffset: const Duration(hours: 2),
      );
      await db.recordingDao.addFixes(id, 0, [
        (position: const LatLng(53.5, 9.9), at: clock),
        (position: const LatLng(53.501, 9.9), at: clock.add(_minute)),
      ]);
      if (stopped) await db.recordingDao.stopRecording(id, clock.add(_minute));
      return id;
    }

    test('is found again, held: interrupted when it had no stop', () async {
      final id = await left(stopped: false, tripId: 1);
      final (container, _) = open();
      await pumpEventQueue();

      final state = stateOf(container);
      expect(state.recordingId, id);
      expect(state.running, isFalse, reason: 'nothing starts unasked');
      expect(state.interrupted, isTrue);
      expect(state.tripId, isNotNull);
      expect(state.utcOffset, const Duration(hours: 2));
      expect(state.lines.single, hasLength(2));
      expect(state.meters, closeTo(111, 1));
      expect(platform.streamRequested, isFalse);
    });

    test('and stopped when it was stopped', () async {
      await left(stopped: true);
      final (container, _) = open();
      await pumpEventQueue();
      expect(stateOf(container).interrupted, isFalse);
      expect(stateOf(container).tripId, isNull);
    });

    test('a start pressed at once waits for it, and starts nothing', () async {
      final id = await left(stopped: true);
      final (container, recorder) = open();
      await recorder.start();

      expect(stateOf(container).recordingId, id);
      expect(stateOf(container).running, isFalse);
      expect(await db.select(db.recordings).get(), hasLength(1));
    });
  });

  test('a declined continue keeps the recording held, and says why', () async {
    final (container, recorder) = open();
    await recorder.start();
    await walk(0, 0);
    await walk(1, 60);
    await recorder.stop();

    platform.permission = LocationPermission.deniedForever;
    await recorder.resume();

    final state = stateOf(container);
    expect(state.problem, LocationProblem.deniedForever);
    expect(state.running, isFalse);
    expect(state.recordingId, isNotNull, reason: 'nothing is lost by asking');
    expect(state.lines.single, hasLength(2));
    expect(state.meters, closeTo(111, 1));
  });

  test(
    'a stop while the recording is being created takes it back out',
    () async {
      final gate = Completer<void>();
      final repo = _GatedRepository(db)..gate = gate;
      final (container, recorder) = open(repo: repo);

      final starting = recorder.start();
      await repo.reached.future;
      await recorder.stop();
      gate.complete();
      await starting;
      await pumpEventQueue();

      expect(stateOf(container).recordingId, isNull);
      expect(await db.select(db.recordings).get(), isEmpty);
      expect(platform.streamRequested, isFalse);
    },
  );

  test('a recording that cannot be looked for is reported, and the button '
      'still works', () async {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);

    final (container, recorder) = open(
      repo: _GatedRepository(db)..lookFails = true,
    );
    await recorder.start();

    expect(reported.single.library, 'track recorder');
    expect(stateOf(container).running, isTrue);
  });

  test('the press is timed by the device\'s clock', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final before = DateTime.now();
    final read = container.read(recorderClockProvider)();
    expect(read.isBefore(before), isFalse);
    expect(read.difference(before).inSeconds, lessThan(5));
  });

  test('discarding throws the recording away', () async {
    final (container, recorder) = open();
    await recorder.start();
    await walk(0, 0);

    await recorder.discard();
    expect(stateOf(container).recordingId, isNull);
    expect(await db.select(db.recordings).get(), isEmpty);
    expect(await stored(), isEmpty);
  });

  test('one recording at a time', () async {
    final (_, recorder) = open();
    await recorder.start();
    await recorder.stop();
    await recorder.start();
    expect(await db.select(db.recordings).get(), hasLength(1));
  });

  test('a stop while the permission is being asked leaves nothing', () async {
    platform.permission = LocationPermission.denied;
    platform.dialog = Completer<void>();
    final (container, recorder) = open();

    final starting = recorder.start();
    await pumpEventQueue();
    expect(stateOf(container).starting, isTrue);
    await recorder.stop();

    platform.permission = LocationPermission.whileInUse;
    platform.dialog!.complete();
    await starting;
    await pumpEventQueue();

    expect(stateOf(container).recordingId, isNull);
    expect(stateOf(container).starting, isFalse);
    expect(await db.select(db.recordings).get(), isEmpty);
    expect(platform.streamRequested, isFalse);
  });

  group('the receiver is shared with the map', () {
    test('a recording under a running mark takes the stream over', () async {
      final (container, recorder) = open();
      container.listen(deviceLocationProvider, (_, _) {});
      await container.read(deviceLocationProvider.notifier).start();
      expect(platform.requestedSettings.single?.distanceFilter, 5);

      await recorder.start();
      await pumpEventQueue();

      // Reopened with the recording's settings — not handed the mark's stream,
      // which is what asking geolocator a second time would have done.
      expect(platform.requestedSettings, hasLength(2));
      expect(platform.requestedSettings.last?.distanceFilter, 0);

      await walk(0, 0);
      await walk(1, 60);
      expect(await stored(), hasLength(2));
      expect(
        container.read(deviceLocationProvider).fix?.position.latitude,
        closeTo(53.501, 1e-9),
        reason: 'the mark goes on following the device',
      );
    });

    test('leaving the map does not stop the recording', () async {
      final (container, recorder) = open();
      final map = container.listen(deviceLocationProvider, (_, _) {});
      await container.read(deviceLocationProvider.notifier).start();
      await recorder.start();
      await pumpEventQueue();

      map.close();
      await pumpEventQueue();

      await walk(0, 0);
      await walk(1, 60);
      expect(await stored(), hasLength(2));
      expect(stateOf(container).running, isTrue);
    });

    test(
      'the mark gets its own settings back when the recording stops',
      () async {
        final (container, recorder) = open();
        container.listen(deviceLocationProvider, (_, _) {});
        await container.read(deviceLocationProvider.notifier).start();
        await recorder.start();
        await pumpEventQueue();

        await recorder.stop();
        await pumpEventQueue();

        expect(platform.requestedSettings, hasLength(3));
        expect(platform.requestedSettings.last?.distanceFilter, 5);
        expect(container.read(deviceLocationProvider).on, isTrue);
      },
    );
  });

  test(
    'on Android it says so in a notification, in the app\'s language',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await prefs.setString('locale_code', 'de');
      final (_, recorder) = open();

      await recorder.start();
      await pumpEventQueue();

      final settings = platform.requestedSettings.single as AndroidSettings;
      final config = settings.foregroundNotificationConfig!;
      expect(config.notificationTitle, 'Track wird aufgezeichnet');
      expect(config.notificationChannelName, 'Track-Aufzeichnung');
      // Before the stop: tests otherwise end with the override still set.
      await recorder.stop();
    },
  );

  group('the notification permission', () {
    test('is asked for on a start, after the location', () async {
      final (_, recorder) = open();
      await recorder.start();
      expect(notifications.asked, 1);
    });

    test('is not asked for when the location was refused', () async {
      platform.permission = LocationPermission.denied;
      final (_, recorder) = open();
      await recorder.start();
      expect(notifications.asked, 0);
    });

    test('refused, the recording runs all the same', () async {
      notifications.answer = false;
      final (container, recorder) = open();
      await recorder.start();
      await walk(0, 0);
      await walk(1, 60);

      expect(stateOf(container).running, isTrue);
      expect(stateOf(container).problem, isNull);
      expect(await stored(), hasLength(2));
    });

    test('a resume does not ask again', () async {
      final (_, recorder) = open();
      await recorder.start();
      await recorder.stop();
      await recorder.resume();
      expect(notifications.asked, 1);
    });

    test('a stop while it is being asked leaves nothing', () async {
      notifications.dialog = Completer<void>();
      final (container, recorder) = open();

      final starting = recorder.start();
      await pumpEventQueue();
      expect(notifications.asked, 1);
      expect(stateOf(container).starting, isTrue);
      await recorder.stop();

      notifications.dialog!.complete();
      await starting;
      await pumpEventQueue();

      expect(stateOf(container).recordingId, isNull);
      expect(await db.select(db.recordings).get(), isEmpty);
      expect(platform.streamRequested, isFalse);
    });
  });

  test('a failing receiver stops the recording and says so', () async {
    final (container, recorder) = open();
    await recorder.start();
    await walk(0, 0);

    platform.fail(StateError('receiver gone'));
    await pumpEventQueue();

    final state = stateOf(container);
    expect(state.running, isFalse);
    expect(state.problem, LocationProblem.failed);
    expect(state.recordingId, isNotNull, reason: 'what it had is kept');
    expect((await db.select(db.recordings).getSingle()).stoppedAt, isNotNull);
  });
}

const _minute = Duration(minutes: 1);

/// The notification permission, answered without a platform: [answer], after
/// [dialog] completes when one is set.
class _FakeNotifications implements NotificationPermissionChannel {
  int asked = 0;
  bool answer = true;
  Completer<void>? dialog;

  @override
  Future<bool> request() async {
    asked++;
    await dialog?.future;
    return answer;
  }
}

/// The real repository, with two ways to get in its way: [gate] holds a new
/// recording's row until it is completed (and [reached] says the row is being
/// written), and [lookFails] makes the look for a held recording throw.
class _GatedRepository extends TripRepository {
  _GatedRepository(super.db);

  Completer<void>? gate;
  final reached = Completer<void>();
  bool lookFails = false;

  @override
  Future<int> startRecording({
    int? tripId,
    required DateTime startedAt,
    required Duration utcOffset,
  }) async {
    final id = await super.startRecording(
      tripId: tripId,
      startedAt: startedAt,
      utcOffset: utcOffset,
    );
    reached.complete();
    await gate?.future;
    return id;
  }

  @override
  Future<List<Recording>> unfiledRecordings() async {
    if (lookFails) throw StateError('database gone');
    return super.unfiledRecordings();
  }
}
