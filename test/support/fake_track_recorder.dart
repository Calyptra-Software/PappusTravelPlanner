import 'package:travelplanner/features/map/location/track_recorder.dart';

/// A recorder that holds [initial] and remembers what it was asked to do,
/// without a database or a receiver behind it — for widget tests of the
/// screens that show a recording, where drift's streams and timers would only
/// get in the way. Override with
/// `trackRecorderProvider.overrideWith(() => FakeTrackRecorder(...))`.
class FakeTrackRecorder extends TrackRecorderController {
  FakeTrackRecorder([this.initial = TrackRecorderState.idle]);

  final TrackRecorderState initial;

  /// What was pressed, in order: `start:<tripId>`, `stop`, `resume`,
  /// `discard`.
  final List<String> calls = [];

  @override
  TrackRecorderState build() => initial;

  /// Lets a test move the recorder on, as fixes or a stop would.
  void set(TrackRecorderState next) => state = next;

  @override
  Future<void> start({int? tripId}) async => calls.add('start:$tripId');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> resume({int? recordingId}) async => calls.add('resume');

  @override
  Future<void> discard() async {
    calls.add('discard');
    state = TrackRecorderState.idle;
  }
}
