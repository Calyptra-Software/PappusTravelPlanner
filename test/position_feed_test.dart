import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:travelplanner/features/map/location/position_feed.dart';

/// One platform stream for every reader, opened for the most demanding one.
void main() {
  late List<LocationSettings> opened;
  late List<StreamController<Position>> streams;
  late PositionFeed feed;

  setUp(() {
    opened = [];
    streams = [];
    feed = PositionFeed(
      open: (settings) {
        opened.add(settings);
        final stream = StreamController<Position>();
        streams.add(stream);
        return stream.stream;
      },
    );
  });
  tearDown(() => feed.dispose());

  Position at(double latitude) => Position(
    latitude: latitude,
    longitude: 9.9,
    timestamp: DateTime.utc(2026, 5, 1, 12),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  bool isOpen(StreamController<Position> stream) => stream.hasListener;

  test(
    'one reader opens the stream with its settings, and closes it',
    () async {
      final reader = feed.listen(PositionDemand.mark, onData: (_) {});
      expect(opened.single.distanceFilter, 5);
      expect(feed.openFor, PositionDemand.mark);

      reader.cancel();
      await pumpEventQueue();
      expect(isOpen(streams.single), isFalse);
      expect(feed.openFor, isNull);
    },
  );

  test('a reading right after listening is not lost', () {
    // Opened in the same breath, not a microtask later: a stream that delivers
    // at once would otherwise deliver to nobody.
    final got = <double>[];
    feed.listen(PositionDemand.mark, onData: (p) => got.add(p.latitude));
    streams.single.add(at(53.5));
    return pumpEventQueue().then((_) => expect(got, [53.5]));
  });

  test('a recording under a mark reopens the stream for both', () async {
    final mark = <double>[];
    final recorded = <double>[];
    feed.listen(PositionDemand.mark, onData: (p) => mark.add(p.latitude));
    final recording = feed.listen(
      PositionDemand.recording,
      onData: (p) => recorded.add(p.latitude),
    );
    await pumpEventQueue();

    // The mark's stream is closed and one with the recording's settings opened
    // in its place — asking geolocator for a second would have returned the
    // first, settings and all.
    expect(opened, hasLength(2));
    expect(opened.last.distanceFilter, 0);
    expect(isOpen(streams.first), isFalse);
    expect(feed.openFor, PositionDemand.recording);

    streams.last.add(at(53.6));
    await pumpEventQueue();
    expect(mark, [53.6], reason: 'the mark goes on being drawn');
    expect(recorded, [53.6]);

    // And back to the mark's own settings when the recording ends.
    recording.cancel();
    await pumpEventQueue();
    expect(opened, hasLength(3));
    expect(opened.last.distanceFilter, 5);
    streams.last.add(at(53.7));
    await pumpEventQueue();
    expect(mark, [53.6, 53.7]);
    expect(recorded, [53.6]);
  });

  test('a mark joining a recording changes nothing', () async {
    feed.listen(PositionDemand.recording, onData: (_) {});
    final mark = feed.listen(PositionDemand.mark, onData: (_) {});
    mark.cancel();
    await pumpEventQueue();
    expect(opened, hasLength(1));
    expect(isOpen(streams.single), isTrue);
  });

  test('a failure reaches every reader', () async {
    final errors = <String>[];
    feed.listen(
      PositionDemand.mark,
      onData: (_) {},
      onError: (_) => errors.add('mark'),
    );
    feed.listen(
      PositionDemand.mark,
      onData: (_) {},
      onError: (_) => errors.add('other'),
    );
    streams.single.addError(StateError('no receiver'));
    await pumpEventQueue();
    expect(errors, ['mark', 'other']);
  });

  test('a reader cancelled is not called again, and cancelling twice is '
      'harmless', () async {
    final got = <double>[];
    final reader = feed.listen(
      PositionDemand.mark,
      onData: (p) => got.add(p.latitude),
    );
    final other = feed.listen(PositionDemand.mark, onData: (_) {});
    reader.cancel();
    reader.cancel();
    streams.single.add(at(53.5));
    await pumpEventQueue();
    expect(got, isEmpty);
    expect(isOpen(streams.single), isTrue, reason: 'the other one stays');
    other.cancel();
  });

  test('disposing closes the stream', () async {
    feed.listen(PositionDemand.recording, onData: (_) {});
    await feed.dispose();
    expect(isOpen(streams.single), isFalse);
  });

  group('settings', () {
    const notice = RecordingNotice(
      title: 'Recording a track',
      text: 'Stop it in the app.',
      channelName: 'Track recording',
    );
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('on Android a recording runs in the foreground service', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final settings = positionSettingsFor(
        PositionDemand.recording,
        notice: notice,
      );
      expect(settings, isA<AndroidSettings>());
      final config =
          (settings as AndroidSettings).foregroundNotificationConfig!;
      expect(config.notificationTitle, 'Recording a track');
      expect(config.notificationText, 'Stop it in the app.');
      expect(config.notificationChannelName, 'Track recording');
      expect(config.notificationIcon.name, 'ic_stat_recording');
      expect(config.enableWakeLock, isFalse);
      expect(settings.distanceFilter, 0, reason: 'acceptFix decides');
    });

    test('the mark never does, on Android or anywhere', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final mark = positionSettingsFor(PositionDemand.mark, notice: notice);
      expect(mark, isNot(isA<AndroidSettings>()));
      expect(mark.distanceFilter, 5);
    });

    test('elsewhere a recording asks for nothing Android-specific', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final settings = positionSettingsFor(
        PositionDemand.recording,
        notice: notice,
      );
      expect(settings, isNot(isA<AndroidSettings>()));
      expect(settings.distanceFilter, 0);
    });

    test('the recording reader\'s notice is the one the stream opens with', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      feed.listen(PositionDemand.mark, onData: (_) {});
      feed.listen(PositionDemand.recording, onData: (_) {}, notice: notice);
      return pumpEventQueue().then((_) {
        final config =
            (opened.last as AndroidSettings).foregroundNotificationConfig;
        expect(config?.notificationTitle, 'Recording a track');
      });
    });
  });
}
