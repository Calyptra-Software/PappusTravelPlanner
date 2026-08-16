import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart';

import '../app_database.dart';
import '../tables.dart';
import '../track_points.dart';

part 'track_dao.g.dart';

/// The lines itinerary entries actually followed.
///
/// A track hangs off an item and cascades with it, so there is no "orphan track"
/// state to clean up and no trip column to keep in step with the item's. What
/// this adds beyond plain CRUD is the two *reading* queries the maps need, both
/// of which apply the live rule in SQL — the same rule, in the same place, as
/// `ItineraryDao.watchPositionedItems` and `CostDao._countsTowardTotals`. A road
/// not taken is not drawn, and deciding that in Dart afterwards would mean a
/// second copy of the definition.
@DriftAccessor(tables: [Tracks, ItineraryItems, Alternatives])
class TrackDao extends DatabaseAccessor<AppDatabase> with _$TrackDaoMixin {
  TrackDao(super.db);

  /// Every live track of one trip, in the order its entries read in.
  Stream<List<Track>> watchTracksForTrip(int tripId) =>
      _liveTracks(itineraryItems.tripId.equals(tripId)).watch();

  /// Every live track of every trip — the all-trips map's reading, and the only
  /// query here that is not about one trip.
  ///
  /// No trip filter at all, for the reason `watchPositionedItems` has none: a
  /// stream keyed by a list of ids compares by identity and would rebuild on
  /// every frame. The caller already holds the trips it is drawing and groups
  /// by [Track.itemId] against the items it fetched beside this.
  Stream<List<Track>> watchAllTracks() => _liveTracks(null).watch();

  /// The tracks of one item, whatever its trip is doing — the item form's own
  /// reading, where the question is "what is on this leg" rather than "what
  /// should the map draw".
  Stream<List<Track>> watchTracksForItem(int itemId) =>
      (select(tracks)
            ..where((t) => t.itemId.equals(itemId))
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .watch();

  JoinedSelectStatement<HasResultSet, dynamic> _liveTracksQuery(
    Expression<bool>? extra,
  ) {
    final query = select(tracks).join([
      innerJoin(itineraryItems, itineraryItems.id.equalsExp(tracks.itemId)),
      leftOuterJoin(
        alternatives,
        alternatives.id.equalsExp(itineraryItems.alternativeId),
      ),
    ]);
    var where =
        itineraryItems.alternativeId.isNull() |
        alternatives.chosen.equals(true);
    if (extra != null) where = where & extra;
    query
      ..where(where)
      ..orderBy([
        OrderingTerm(expression: itineraryItems.tripId),
        OrderingTerm(expression: itineraryItems.date),
        OrderingTerm(expression: itineraryItems.sortOrder),
        OrderingTerm(expression: tracks.sortOrder),
      ]);
    return query;
  }

  Selectable<Track> _liveTracks(Expression<bool>? extra) =>
      _liveTracksQuery(extra).map((row) => row.readTable(tracks));

  /// Writes [lines] onto [itemId], appended after whatever it already carries.
  ///
  /// Takes the points rather than a file: parsing belongs to `parseGpx`, which
  /// is pure and has no database under it, and a later recorder or router will
  /// arrive here with points and no file at all.
  Future<void> addTracks(
    int itemId,
    List<({List<LatLng> points, String? name})> lines, {
    TrackSource source = TrackSource.imported,
  }) async {
    if (lines.isEmpty) return;
    final existing =
        await (selectOnly(tracks)
              ..addColumns([tracks.sortOrder.max()])
              ..where(tracks.itemId.equals(itemId)))
            .map((row) => row.read(tracks.sortOrder.max()))
            .getSingleOrNull();
    var next = (existing ?? -1) + 1;
    await batch((b) {
      for (final line in lines) {
        b.insert(
          tracks,
          TracksCompanion.insert(
            itemId: itemId,
            source: Value(source),
            name: Value(line.name),
            points: encodeTrackPoints(line.points),
            sortOrder: Value(next++),
          ),
        );
      }
    });
  }

  /// Writes one recording across the entries it covered.
  ///
  /// [pieces] is what `splitTrack` divided the line into, one per entry, and
  /// [ends] are the coordinates the import learned along the way: an entry's
  /// start or finish that had none, taken from the recording's own ends or
  /// pointed at on the map. Both in one transaction, because they are one act —
  /// a line landing on entries that did not get the positions it was cut by
  /// would be a plan the map cannot draw and the user did not ask for.
  ///
  /// An end being placed loses its `fromPlaceId` / `toPlaceId`, by the rule that
  /// governs moving one: that column means "the id the search was issued
  /// against", and it cannot go on describing an end whose position now comes
  /// from somewhere else.
  Future<void> importTrackAcross({
    required String? name,
    required List<({int itemId, List<LatLng> points})> pieces,
    required List<({int itemId, bool isStart, LatLng at})> ends,
    TrackSource source = TrackSource.imported,
  }) {
    return transaction(() async {
      for (final end in ends) {
        await (update(
          itineraryItems,
        )..where((i) => i.id.equals(end.itemId))).write(
          end.isStart
              ? ItineraryItemsCompanion(
                  fromLat: Value(end.at.latitude),
                  fromLon: Value(end.at.longitude),
                  fromPlaceId: const Value(null),
                )
              : ItineraryItemsCompanion(
                  toLat: Value(end.at.latitude),
                  toLon: Value(end.at.longitude),
                  toPlaceId: const Value(null),
                ),
        );
      }
      for (final piece in pieces) {
        if (piece.points.length < 2) continue;
        await addTracks(piece.itemId, [
          (points: piece.points, name: name),
        ], source: source);
      }
    });
  }

  Future<void> deleteTrack(int id) =>
      (delete(tracks)..where((t) => t.id.equals(id))).go();

  /// Everything one item carries — what "remove the track" means when an import
  /// arrived as several segments under one name.
  Future<void> deleteTracksForItem(int itemId) =>
      (delete(tracks)..where((t) => t.itemId.equals(itemId))).go();

  /// Copies every track of [fromItemId] onto [toItemId].
  ///
  /// **A track travels with a copy.** A routine's walk to the station is part of
  /// the plan, not of one morning, so stamping the routine out has to bring it —
  /// the same reason the checklist and the fare travel. And the provenance
  /// describes *the line*, not the occurrence: a `recorded` track copied onto
  /// next Tuesday is still a line somebody once walked, so the label is kept
  /// rather than downgraded.
  ///
  /// This is deliberately **not** part of `copyItemPlan`, which builds a
  /// companion out of columns and cannot reach a second table. Every path that
  /// duplicates an item has to call this as well, which is exactly where the
  /// rule will rot if it is not written down — see `AGENTS.md`.
  /// Set [reversed] when the copy runs the other way — the reversed routine,
  /// where the way home covers the ground the way out covered. A path from A to
  /// B *is* the path from B to A, unlike the times and the stops beside it,
  /// which that copy drops rather than reverse into a plausible-looking fiction.
  /// Only the order of the points changes, so nothing is invented; it is done at
  /// all because a line stored backwards would be a lie waiting for the first
  /// thing that draws direction.
  Future<void> copyItemTracks(
    int fromItemId,
    int toItemId, {
    bool reversed = false,
  }) async {
    final source = await (select(
      tracks,
    )..where((t) => t.itemId.equals(fromItemId))).get();
    if (source.isEmpty) return;
    await batch((b) {
      for (final track in source) {
        b.insert(
          tracks,
          TracksCompanion.insert(
            itemId: toItemId,
            source: Value(track.source),
            name: Value(track.name),
            points: reversed
                ? encodeTrackPoints(
                    decodeTrackPoints(track.points).reversed.toList(),
                  )
                : track.points,
            sortOrder: Value(track.sortOrder),
          ),
        );
      }
    });
  }
}
