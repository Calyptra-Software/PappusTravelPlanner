import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/database/track_points.dart';
import 'package:travelplanner/features/map/track_summary.dart';

/// What the item form reads off a stored line.
///
/// The point is that two rows on one entry can be told apart: a recording that
/// stopped and started again leaves two segments under one name, and the length
/// is then the only thing that separates them.
void main() {
  Track row(
    int id, {
    required List<LatLng> points,
    String? name,
    TrackSource source = TrackSource.imported,
  }) => Track(
    id: id,
    itemId: 7,
    source: source,
    name: name,
    points: encodeTrackPoints(points),
    sortOrder: id,
  );

  test('a line is summarized by its name, its source and its length', () {
    final summaries = summarizeTracks([
      row(
        1,
        name: 'Morning walk',
        points: const [LatLng(53.55, 9.99), LatLng(53.56, 9.99)],
      ),
    ]);

    expect(summaries, hasLength(1));
    expect(summaries.single.id, 1);
    expect(summaries.single.name, 'Morning walk');
    expect(summaries.single.source, TrackSource.imported);
    // One hundredth of a degree of latitude is about 1.1 km.
    expect(summaries.single.meters, closeTo(1112, 5));
  });

  test('two segments under one name are told apart by their lengths', () {
    final summaries = summarizeTracks([
      row(
        1,
        name: 'Morning walk',
        points: const [LatLng(53.55, 9.99), LatLng(53.56, 9.99)],
      ),
      row(
        2,
        name: 'Morning walk',
        points: const [LatLng(53.60, 9.99), LatLng(53.63, 9.99)],
      ),
    ]);

    expect(summaries.map((s) => s.id), [1, 2]);
    expect(summaries[1].meters, greaterThan(summaries[0].meters! * 2));
  });

  test('the name is left null rather than made up', () {
    expect(
      summarizeTracks([
        row(1, points: const [LatLng(53.55, 9.99), LatLng(53.56, 9.99)]),
      ]).single.name,
      isNull,
    );
  });

  test('a row the map cannot draw is listed with no length', () {
    // Both cases are the same fact to a reader deciding whether to keep it, and
    // a row that draws nothing is exactly the one worth being able to delete —
    // so it is listed rather than dropped, unlike on the map.
    final summaries = summarizeTracks([
      row(1, points: const [LatLng(53.55, 9.99)]),
      Track(
        id: 2,
        itemId: 7,
        source: TrackSource.imported,
        name: null,
        points: 'not a polyline at all ~~~',
        sortOrder: 2,
      ),
    ]);

    expect(summaries.map((s) => s.id), [1, 2]);
    expect(summaries.every((s) => s.meters == null), isTrue);
  });
}
