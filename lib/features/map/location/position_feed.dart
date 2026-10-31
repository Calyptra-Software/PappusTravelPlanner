/// The one place the app opens the platform's position stream.
///
/// Two things in this app want the device's position — the map's mark
/// (`device_location.dart`) and the recorder (`track_recorder.dart`) — and the
/// platform gives them **one** stream between them. `geolocator` keeps the
/// stream it handed out first and returns that same stream to every later
/// caller, *with the settings it was opened with*, until its last listener has
/// gone. So asking for a second stream with other settings does not fail: it
/// silently answers with the first. A recording started while a map's mark was
/// on would have been running on the mark's settings, which on Android means
/// without the foreground service that keeps it alive with the screen off — and
/// the mark is on whenever its remembered switch is, which is often.
///
/// Hence one owner. Every reader listens here, saying what it needs the
/// position *for* ([PositionDemand]), and the feed holds a single platform
/// subscription opened for the most demanding reader present. When that
/// changes — a recording starts under a running mark, or ends beneath one — the
/// subscription is closed and opened again with the other settings, and every
/// reader goes on receiving through the change.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// What a reader needs the position for, in increasing order of demand.
///
/// Persisted nowhere, so the order may change; it is what [PositionFeed] reads
/// to decide which settings win.
enum PositionDemand {
  /// The map's mark: where the device is, while a map is open.
  mark,

  /// A track being recorded: every reading, for as long as the recording
  /// runs.
  recording,
}

/// What Android shows while a recording keeps the receiver running, in the
/// user's language. A reader brings it along because the feed has no widget to
/// look a text up from.
final class RecordingNotice {
  const RecordingNotice({
    required this.title,
    required this.text,
    required this.channelName,
  });

  final String title;
  final String text;

  /// The name the notification's channel has in the system settings.
  final String channelName;
}

/// The small icon of that notification: `res/drawable/ic_stat_recording.xml`,
/// a white mark on nothing, which is what Android draws a status-bar icon
/// from. Looked up by name on the native side, which is why
/// `res/raw/keep.xml` keeps it from the resource shrinker.
const _recordingIcon = AndroidResource(name: 'ic_stat_recording');

/// The settings the platform stream is opened with for [demand].
///
/// For the mark, readings only once the device has moved a few meters: a
/// receiver standing still emits a jittering fix several times a second, and
/// every one of them would redraw a marker layer over a moving map. For a
/// recording, every reading — which of them are kept is `acceptFix`'s decision,
/// and it takes the receiver's own uncertainty into account, which a fixed
/// distance filter cannot.
///
/// On **Android** a recording runs the receiver in `geolocator`'s foreground
/// service, with [notice] as its notification: without it, the system stops
/// delivering positions to an app the moment it is no longer on screen, and a
/// recording would end with the phone going into a pocket. It needs no
/// `ACCESS_BACKGROUND_LOCATION`, because the service is started from the
/// foreground, on a press — which is also why the mark never asks for one: it
/// exists while a map is on screen and has nothing to keep alive. One reading a
/// second, the receiver's own pace for a walk, and no wake lock: the fixes
/// carry the time they were taken, so a reading delivered late after the CPU
/// slept still lands at the moment it was measured.
LocationSettings positionSettingsFor(
  PositionDemand demand, {
  RecordingNotice? notice,
}) => switch (demand) {
  PositionDemand.mark => const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5,
  ),
  PositionDemand.recording
      when !kIsWeb && defaultTargetPlatform == TargetPlatform.android =>
    AndroidSettings(
      accuracy: LocationAccuracy.high,
      intervalDuration: const Duration(seconds: 1),
      foregroundNotificationConfig: notice == null
          ? null
          : ForegroundNotificationConfig(
              notificationTitle: notice.title,
              notificationText: notice.text,
              notificationChannelName: notice.channelName,
              notificationIcon: _recordingIcon,
              setOngoing: true,
            ),
    ),
  PositionDemand.recording => const LocationSettings(
    accuracy: LocationAccuracy.high,
  ),
};

/// One reader's place in the feed. Cancelling it is the only way to leave.
final class PositionListening {
  PositionListening._(
    this._feed,
    this.demand,
    this.notice,
    this._onData,
    this._onError,
  );

  final PositionFeed _feed;
  final PositionDemand demand;

  /// What to show while this reader keeps the receiver running, where the
  /// platform shows anything — see [positionSettingsFor].
  final RecordingNotice? notice;
  final void Function(Position) _onData;
  final void Function(Object error)? _onError;

  bool _cancelled = false;

  /// Stops delivering to this reader. Idempotent.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _feed._remove(this);
  }
}

/// The single platform subscription, shared by every reader.
class PositionFeed {
  /// [open] is how the platform stream is obtained, injectable so the feed can
  /// be tested without a receiver; the default is `geolocator`'s.
  PositionFeed({Stream<Position> Function(LocationSettings settings)? open})
    : _open =
          open ??
          ((settings) =>
              Geolocator.getPositionStream(locationSettings: settings));

  final Stream<Position> Function(LocationSettings settings) _open;

  final List<PositionListening> _readers = [];

  StreamSubscription<Position>? _platform;

  /// What [_platform] was opened for, or null while it is closed.
  PositionDemand? _openFor;

  /// The close in progress, while the stream is being reopened with other
  /// settings. Closing has to be finished before opening again, or `geolocator`
  /// hands back the very stream being closed — the cached one this class exists
  /// to manage.
  Future<void>? _closing;

  bool _disposed = false;

  /// What the platform stream is open for right now, or null when it is not.
  /// For tests and for nothing else.
  PositionDemand? get openFor => _openFor;

  /// Delivers every reading to [onData] until the answer is cancelled, and a
  /// failure of the platform stream to [onError]. A recording brings its
  /// [notice] along.
  PositionListening listen(
    PositionDemand demand, {
    required void Function(Position) onData,
    void Function(Object error)? onError,
    RecordingNotice? notice,
  }) {
    final reader = PositionListening._(this, demand, notice, onData, onError);
    _readers.add(reader);
    _reconcile();
    return reader;
  }

  void _remove(PositionListening reader) {
    _readers.remove(reader);
    _reconcile();
  }

  /// The most demanding of the readers present, or null when there are none.
  PositionDemand? get _wanted {
    PositionDemand? wanted;
    for (final reader in _readers) {
      if (wanted == null || reader.demand.index > wanted.index) {
        wanted = reader.demand;
      }
    }
    return wanted;
  }

  /// Brings the platform stream in line with the readers present.
  ///
  /// Synchronous whenever nothing has to be closed first, so a reader that
  /// listens and is handed a reading in the same breath receives it — the
  /// common case of all, since most of the time one reader comes and goes
  /// alone. Only a change of settings under a running stream waits, for the
  /// close; and the readers who arrive meanwhile are counted when it is done.
  void _reconcile() {
    if (_closing != null) return;
    final wanted = _disposed ? null : _wanted;
    if (wanted == _openFor) return;
    final closing = _platform;
    _platform = null;
    _openFor = null;
    if (closing == null) {
      if (wanted != null) _openNow(wanted);
      return;
    }
    _closing = closing.cancel().whenComplete(() {
      _closing = null;
      _reconcile();
    });
  }

  void _openNow(PositionDemand demand) {
    _openFor = demand;
    final notice = _readers
        .where((reader) => reader.demand == demand)
        .map((reader) => reader.notice)
        .nonNulls
        .firstOrNull;
    _platform = _open(positionSettingsFor(demand, notice: notice)).listen(
      (position) {
        // A copy: a reader may cancel itself from inside its own callback.
        for (final reader in [..._readers]) {
          if (!reader._cancelled) reader._onData(position);
        }
      },
      onError: (Object error) {
        for (final reader in [..._readers]) {
          if (!reader._cancelled) reader._onError?.call(error);
        }
      },
    );
  }

  /// Closes the platform stream for good.
  Future<void> dispose() async {
    _disposed = true;
    _readers.clear();
    _reconcile();
    await _closing;
  }
}

/// The app's [PositionFeed]. Not `autoDispose`: it holds the platform stream
/// only while somebody is listening, so it costs nothing to keep, and keeping
/// it is what guarantees there is only ever one.
final positionFeedProvider = Provider<PositionFeed>((ref) {
  final feed = PositionFeed();
  ref.onDispose(feed.dispose);
  return feed;
});
