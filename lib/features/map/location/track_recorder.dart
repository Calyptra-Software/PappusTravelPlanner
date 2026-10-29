/// Recording a track from the device's own position.
///
/// The other half of `device_location.dart`. The mark shows where the device is
/// and forgets it; the recorder keeps it, every accepted fix written to the
/// database as it arrives (`Recordings` / `RecordingFixes`), so that a recording
/// survives the app being stopped behind the user's back. What it becomes is
/// decided later, by the ordinary track import — the recorder only has to make
/// sure nothing accepted is lost before then.
///
/// Rules this leans on:
///
/// * **Nothing starts unasked.** A recording begins on a press and on nothing
///   else, and the permission is asked for on that press, through the same
///   [checkLocationAccess] the mark uses.
/// * **Not `autoDispose`.** Leaving the map is no reason to stop recording —
///   it is the ordinary thing to do while walking with the phone in a pocket.
///   The provider lives as long as the app, or until the database is switched:
///   it watches [repositoryProvider], so pointing the app at another file
///   rebuilds it, and the recording left running in the old file is found there
///   again as one nobody stopped.
/// * **One receiver.** The position comes through the [PositionFeed], never a
///   platform stream of its own, so starting a recording under a map's mark
///   reopens the one stream with the recording's settings instead of quietly
///   getting the mark's.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../../../core/settings/locale_provider.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../track_recording.dart';
import 'device_location.dart' show LocationProblem, checkLocationAccess;
import 'position_feed.dart';

const Distance _distance = Distance(calculator: Haversine());

/// Where the recorder reads the time of a press from — the start and the stop.
/// The fixes carry their own. A provider so tests can hold the clock still.
final recorderClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// What the recorder is doing, and what it has kept so far.
final class TrackRecorderState {
  const TrackRecorderState({
    this.recordingId,
    this.running = false,
    this.starting = false,
    this.startedAt,
    this.lines = const [],
    this.meters = 0,
    this.problem,
  });

  /// The recording being made or held, or null when there is none.
  final int? recordingId;

  /// Whether fixes are being taken. False for a recording that is held —
  /// paused, or stopped and not yet filed.
  final bool running;

  /// A start pressed and not yet answered: the permission is being asked for.
  final bool starting;

  /// When the recording was started (UTC).
  final DateTime? startedAt;

  /// What has been kept, one list per segment, for drawing while it is made.
  /// The last one is the segment being recorded, empty until its first fix.
  final List<List<LatLng>> lines;

  /// How far the kept fixes run, never across the gap between two segments.
  final double meters;

  /// Why the last start or resume came to nothing, or why a running recording
  /// stopped by itself.
  final LocationProblem? problem;

  static const idle = TrackRecorderState();
}

/// The app's recorder. One recording at a time.
final trackRecorderProvider =
    NotifierProvider<TrackRecorderController, TrackRecorderState>(
      TrackRecorderController.new,
    );

class TrackRecorderController extends Notifier<TrackRecorderState> {
  late TripRepository _repo;

  PositionListening? _listening;

  /// The segment fixes are written into: 0 for a fresh recording, one past the
  /// last one written for a resumed one.
  int _segment = 0;

  /// The last fix kept in the current segment — what [acceptFix] measures the
  /// next one against. Null at the start of a segment.
  FixReading? _last;

  /// The writes, one after another, so fixes land in the order they were
  /// taken and a stop can wait for the last of them.
  Future<void> _writes = Future.value();

  /// Which start or resume is the current one, as in `DeviceLocationController`:
  /// the permission dialog can be on screen for minutes, and a stop pressed
  /// meanwhile must win over the answer that arrives afterwards.
  int _generation = 0;

  @override
  TrackRecorderState build() {
    _repo = ref.watch(repositoryProvider);
    ref.onDispose(_cancel);
    return TrackRecorderState.idle;
  }

  DateTime _now() => ref.read(recorderClockProvider)().toUtc();

  void _cancel() {
    _generation++;
    _listening?.cancel();
    _listening = null;
  }

  /// Starts recording, from [tripId] when one was open — a hint for filing it
  /// later, not a claim that it belongs there.
  ///
  /// Does nothing while a recording is held: there is one at a time, and the
  /// held one is resumed, filed or thrown away first.
  Future<void> start({int? tripId}) async {
    if (state.recordingId != null || state.starting) return;
    _cancel();
    final generation = _generation;
    bool superseded() => !ref.mounted || generation != _generation;

    state = const TrackRecorderState(starting: true);
    final problem = await checkLocationAccess(
      mayAsk: true,
      abandoned: superseded,
    );
    if (superseded()) return;
    if (problem != null) {
      state = TrackRecorderState(problem: problem);
      return;
    }
    final startedAt = _now();
    final id = await _repo.startRecording(
      tripId: tripId,
      startedAt: startedAt,
      utcOffset: startedAt.toLocal().timeZoneOffset,
    );
    if (superseded()) {
      // Stopped while the row was being written: there is nothing in it, and
      // leaving it would greet the next start with an interrupted recording
      // nobody made.
      _repo.deleteRecording(id).ignore();
      return;
    }
    _segment = 0;
    _last = null;
    state = TrackRecorderState(
      recordingId: id,
      running: true,
      startedAt: startedAt,
      lines: const [<LatLng>[]],
    );
    _listen();
  }

  /// Stops taking fixes and holds the recording — to be resumed, filed or
  /// thrown away. A start still waiting for its permission is withdrawn.
  Future<void> stop() async {
    final id = state.recordingId;
    if (id == null) {
      if (state.starting) {
        _cancel();
        state = TrackRecorderState.idle;
      }
      return;
    }
    if (!state.running) return;
    await _hold(id, problem: null);
  }

  /// Takes up a held recording again — the one held now, or [recordingId],
  /// which is how a recording the app was stopped in the middle of is
  /// continued. Its next fixes go into a new segment, so the gap stays a gap.
  Future<void> resume({int? recordingId}) async {
    final id = recordingId ?? state.recordingId;
    if (id == null || state.running || state.starting) return;
    _cancel();
    final generation = _generation;
    bool superseded() => !ref.mounted || generation != _generation;

    final held = state;
    final problem = await checkLocationAccess(
      mayAsk: true,
      abandoned: superseded,
    );
    if (superseded()) return;
    if (problem != null) {
      state = TrackRecorderState(
        recordingId: held.recordingId,
        startedAt: held.startedAt,
        lines: held.lines,
        meters: held.meters,
        problem: problem,
      );
      return;
    }

    var lines = held.lines;
    var meters = held.meters;
    var startedAt = held.startedAt;
    if (id != held.recordingId) {
      final row = await _repo.recordingOf(id);
      if (superseded()) return;
      if (row == null) return;
      final stored = recordedLines(await _repo.recordingFixes(id));
      lines = [for (final line in stored) line.points];
      meters = recordedDistanceMeters(stored);
      startedAt = DateTime.fromMillisecondsSinceEpoch(
        row.startedAt,
        isUtc: true,
      );
    }
    final segment = await _repo.resumeRecording(id);
    if (superseded()) return;
    _segment = segment;
    _last = null;
    state = TrackRecorderState(
      recordingId: id,
      running: true,
      startedAt: startedAt,
      lines: [...lines.where((line) => line.isNotEmpty), <LatLng>[]],
      meters: meters,
    );
    _listen();
  }

  /// Throws the recording away, fixes and all — once the import has filed it,
  /// or because the user said so.
  Future<void> discard() async {
    final id = state.recordingId;
    _cancel();
    state = TrackRecorderState.idle;
    if (id == null) return;
    await _writes;
    await _repo.deleteRecording(id);
  }

  void _listen() {
    _listening = ref
        .read(positionFeedProvider)
        .listen(
          PositionDemand.recording,
          notice: _notice(),
          onData: _received,
          onError: (_) {
            final id = state.recordingId;
            if (id != null && state.running) {
              _hold(id, problem: LocationProblem.failed);
            }
          },
        );
  }

  /// The notification Android shows while the recording runs, in the
  /// language the app is shown in.
  RecordingNotice _notice() {
    final l10n = lookupAppLocalizations(appLocaleFor(ref.read(localeProvider)));
    return RecordingNotice(
      title: l10n.recordingNotificationTitle,
      text: l10n.recordingNotificationText,
      channelName: l10n.recordingNotificationChannel,
    );
  }

  /// Stops the receiver and marks the recording stopped, keeping it held.
  Future<void> _hold(int id, {required LocationProblem? problem}) async {
    _cancel();
    state = TrackRecorderState(
      recordingId: id,
      startedAt: state.startedAt,
      lines: state.lines,
      meters: state.meters,
      problem: problem,
    );
    await _writes;
    await _repo.stopRecording(id, _now());
  }

  void _received(Position position) {
    final id = state.recordingId;
    if (id == null || !state.running) return;
    final reading = FixReading(
      position: LatLng(position.latitude, position.longitude),
      accuracyMeters: position.accuracy.abs(),
      at: position.timestamp.toUtc(),
    );
    final last = _last;
    if (!acceptFix(last, reading)) return;
    _last = reading;

    final segment = _segment;
    _writes = _writes
        .then(
          (_) => _repo.addRecordingFixes(id, segment, [
            (position: reading.position, at: reading.at),
          ]),
        )
        // Reported, and not allowed to stop the writes after it: one failed
        // insert must not silently cost the rest of the walk.
        .onError<Object>(
          (error, stack) => FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'track recorder',
            ),
          ),
        );

    final lines = state.lines;
    state = TrackRecorderState(
      recordingId: id,
      running: true,
      startedAt: state.startedAt,
      lines: [
        ...lines.take(lines.length - 1),
        [...lines.last, reading.position],
      ],
      meters:
          state.meters +
          (last == null
              ? 0
              : _distance.as(
                  LengthUnit.Meter,
                  last.position,
                  reading.position,
                )),
    );
  }
}
