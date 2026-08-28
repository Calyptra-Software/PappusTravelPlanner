import '../../data/database/app_database.dart';
import '../../data/database/tables.dart';
import '../../data/database/track_points.dart';
import 'map_features.dart';

/// One stored line, as the form that lists it needs to read it: what it is, and
/// how long it runs.
///
/// A track's identity is not its row id, which says nothing, and not a made-up
/// "Line 1", which the table refuses to invent. What distinguishes two rows on
/// one entry is the name the file gave them (when it gave one), where the line
/// came from, and how far it goes — a recording that stopped and started again
/// leaves two segments under one name, and the length is then the only thing
/// that tells them apart.
final class TrackSummary {
  const TrackSummary({
    required this.id,
    required this.source,
    required this.name,
    required this.meters,
  });

  final int id;
  final TrackSource source;

  /// The name the file gave the line, or null — never filled in with anything.
  final String? name;

  /// How far the line runs, or **null** when it is not a line the map can draw:
  /// a string that will not decode (one may arrive from a shared bundle, which
  /// is a file from outside), or fewer than two points. Both are the same fact
  /// to a reader deciding whether to keep the row — nothing is drawn for it —
  /// and the row is listed rather than hidden, since a line that draws nothing
  /// is exactly the one worth being able to delete.
  final double? meters;
}

/// Reads [rows] as the item form lists them, in the order they were given.
///
/// Decoding is the only expensive thing a track does, which is why this is
/// called from a provider and not from `build` — the same rule
/// `groupTrackPoints` follows for the map.
List<TrackSummary> summarizeTracks(List<Track> rows) => [
  for (final row in rows)
    TrackSummary(
      id: row.id,
      source: row.source,
      name: row.name,
      meters: _lengthOf(row.points),
    ),
];

double? _lengthOf(String packed) {
  try {
    final points = decodeTrackPoints(packed);
    if (points.length < 2) return null;
    return lineLength(points);
  } on FormatException {
    return null;
  }
}
