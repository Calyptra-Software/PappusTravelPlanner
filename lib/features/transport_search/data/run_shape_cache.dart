import 'dart:convert';

import '../../../core/format/civil_date.dart';
import 'run_shape_files.dart';

/// How many days after its last travel day a run's route is kept. A few, not
/// none: a journey is looked at again on the way back, or the day after, and a
/// run whose travel day has passed is not going to be asked about much longer.
const int kRunShapeKeepDays = 3;

/// The routes of whole runs, kept outside the database: the database holds the
/// plan and what was traveled, while a run's route is the router's to give
/// again, about 50 KB a run, and only wanted while somebody is looking at it.
///
/// Two levels. Memory, for as long as the app runs, on every platform; and,
/// where there is one, the app's cache directory ([RunShapeFiles]), so a route
/// once fetched is there after a restart and offline on the train. The system
/// may empty that directory whenever it likes, which costs one request the
/// next time the run is asked for. Entries are dropped [kRunShapeKeepDays]
/// after their run's last travel day, once, the first time the cache is used.
///
/// Keyed by the router's trip id: a run that is found again under a new one
/// (see `trip_relocation.dart`) is asked for again, which is right, since the
/// id is all that says the shape belongs to the run.
class RunShapeCache {
  /// [_files] is where routes outlive the session, or null where there is no
  /// such place; [today] says what day it is, for dropping old ones.
  RunShapeCache(this._files, {DateTime Function()? today})
    : _today = today ?? DateTime.now;

  final Future<RunShapeFiles?> _files;
  final DateTime Function() _today;
  final Map<String, String> _memory = {};
  Future<void>? _pruned;

  /// The route of the run [tripId], at the router's precision, or null when
  /// it has not been kept.
  Future<String?> read(String tripId) async {
    final remembered = _memory[tripId];
    if (remembered != null) return remembered;
    final files = await _ready();
    if (files == null) return null;
    final entry = _decode(await files.read(_key(tripId)));
    if (entry == null || entry.tripId != tripId) return null;
    return _memory[tripId] = entry.shape;
  }

  /// Keeps [shape] as the route of the run [tripId], whose last travel day
  /// (the day its leg arrives on) is [lastDay].
  Future<void> write(
    String tripId,
    String shape, {
    required DateTime lastDay,
  }) async {
    _memory[tripId] = shape;
    final files = await _ready();
    await files?.write(
      _key(tripId),
      jsonEncode({
        'tripId': tripId,
        'lastDay': _dateKey(lastDay),
        'shape': shape,
      }),
    );
  }

  Future<RunShapeFiles?> _ready() async {
    final files = await _files;
    if (files != null) await (_pruned ??= _prune(files));
    return files;
  }

  /// Drops every kept route whose run is more than [kRunShapeKeepDays] past,
  /// and every file that does not read as one of ours.
  Future<void> _prune(RunShapeFiles files) async {
    final now = _today();
    final today = DateTime(now.year, now.month, now.day);
    for (final key in await files.keys()) {
      final entry = _decode(await files.read(key));
      if (entry == null ||
          daysBetween(entry.lastDay, today) > kRunShapeKeepDays) {
        await files.delete(key);
      }
    }
  }

  /// A file name for [tripId]: trip ids carry `:` and `/`, which file systems
  /// do not all allow, so the id goes in as URL-safe Base64.
  static String _key(String tripId) =>
      base64Url.encode(utf8.encode(tripId)).replaceAll('=', '');

  static String _dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static ({String tripId, DateTime lastDay, String shape})? _decode(
    String? content,
  ) {
    if (content == null) return null;
    try {
      final json = jsonDecode(content);
      if (json is! Map<String, dynamic>) return null;
      final tripId = json['tripId'];
      final shape = json['shape'];
      final lastDay = DateTime.tryParse(json['lastDay'] as String? ?? '');
      if (tripId is! String || shape is! String || lastDay == null) {
        return null;
      }
      return (tripId: tripId, lastDay: lastDay, shape: shape);
    } on FormatException {
      return null;
    }
  }
}
