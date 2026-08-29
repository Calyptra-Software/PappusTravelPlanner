import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/track_points.dart';
import '../../map/map_features.dart';
import '../../map/track_summary.dart';
import '../../../data/database/app_database.dart';
import '../../trips/application/trip_providers.dart';
import '../live_items.dart';
import '../transport_stats.dart';

/// Every itinerary item of a trip, already ordered by day / sort / time —
/// including the items of alternative branches that were not chosen (the
/// timeline needs them to draw the branch being looked at). For the plan as it
/// stands, filter with [liveItems] and [chosenBranchIdsProvider].
final itineraryProvider = StreamProvider.autoDispose
    .family<List<ItineraryItem>, int>((ref, tripId) {
      return ref.watch(repositoryProvider).watchItems(tripId);
    });

/// Every *live* entry that carries a position, across all trips — the one query
/// here that is not about a single trip.
///
/// Deliberately unfiltered: the overview's map draws whatever `applyTripQuery`
/// left visible, and asking this stream per visible trip would need a family
/// keyed by a list, which compares by identity and would rebuild on every frame.
/// One stream, grouped by trip id where it is drawn.
final positionedItemsProvider = StreamProvider.autoDispose<List<ItineraryItem>>(
  (ref) => ref.watch(repositoryProvider).watchPositionedItems(),
);

/// The lines one trip's entries actually followed, decoded and keyed by entry.
///
/// Decoded **here**, once per change, rather than in the widget that draws them:
/// unpacking is the only expensive thing a track does, and doing it inside
/// `build` would repeat it on every camera tick — which is the shape of the
/// pinch freeze this map has already been through once.
final tripTracksProvider = StreamProvider.autoDispose
    .family<Map<int, List<TrackLine>>, int>((ref, tripId) {
      return ref
          .watch(repositoryProvider)
          .watchTracksForTrip(tripId)
          .map(groupTrackPoints);
    });

/// The same for every trip at once — the all-trips map's reading, unfiltered for
/// the reason [positionedItemsProvider] is.
final allTracksProvider = StreamProvider.autoDispose
    .family<Map<int, List<TrackLine>>, void>((ref, _) {
      return ref
          .watch(repositoryProvider)
          .watchAllTracks()
          .map(groupTrackPoints);
    });

/// What one entry carries, for the form that edits it.
final itemTracksProvider = StreamProvider.autoDispose.family<List<Track>, int>((
  ref,
  itemId,
) {
  return ref.watch(repositoryProvider).watchTracksForItem(itemId);
});

/// The same rows, read as the form lists them — one summary per line.
///
/// Derived rather than a second stream, so the decoding runs once per change of
/// the rows and not on every rebuild of the form around it: an entry's form
/// rebuilds on every keystroke, and unpacking a dense recording there is the
/// shape of the freeze the map has already been through once.
final itemTrackSummariesProvider = Provider.autoDispose
    .family<AsyncValue<List<TrackSummary>>, int>((ref, itemId) {
      return ref.watch(itemTracksProvider(itemId)).whenData(summarizeTracks);
    });

/// Rows to points, grouped by the entry they belong to.
///
/// A row whose string is not one of ours is **dropped**, not thrown on: it
/// reached the database from a shared bundle, which is a file from outside, and
/// one unreadable line must not blank the map for the whole trip. What is lost
/// is exactly that line, which is what an unreadable line means.
Map<int, List<TrackLine>> groupTrackPoints(List<Track> rows) {
  final byItem = <int, List<TrackLine>>{};
  for (final row in rows) {
    final List<LatLng> points;
    try {
      points = decodeTrackPoints(row.points);
    } on FormatException {
      continue;
    }
    if (points.length < 2) continue;
    byItem
        .putIfAbsent(row.itemId, () => [])
        .add(
          TrackLine(
            id: row.id,
            points: points,
            source: row.source,
            display: row.display,
          ),
        );
  }
  return byItem;
}

/// The set of a trip's days (normalized to midnight) currently collapsed in the
/// overview. Days not in the set are expanded (the default).
final collapsedDaysProvider = StreamProvider.autoDispose
    .family<Set<DateTime>, int>((ref, tripId) {
      return ref.watch(repositoryProvider).watchCollapsedDays(tripId);
    });

/// A trip's item groups, keyed by id, so the timeline and item sheet can resolve
/// an item's group (its label and collapsed state) by [ItineraryItem.groupId].
final groupsProvider = StreamProvider.autoDispose
    .family<Map<int, ItemGroup>, int>((ref, tripId) {
      return ref.watch(repositoryProvider).watchGroups(tripId);
    });

/// A trip's decision points ([AlternativeSet]s), keyed by id, so the timeline can
/// place each one in its day.
final alternativeSetsProvider = StreamProvider.autoDispose
    .family<Map<int, AlternativeSet>, int>((ref, tripId) {
      return ref.watch(repositoryProvider).watchAlternativeSets(tripId);
    });

/// The branches of each decision, keyed by set id and in swipe order.
final alternativeBranchesProvider = StreamProvider.autoDispose
    .family<Map<int, List<Alternative>>, int>((ref, tripId) {
      return ref.watch(repositoryProvider).watchAlternativeBranches(tripId);
    });

/// The chosen branch of every decision in a trip — the ids that decide which
/// items are part of the plan as it stands (see [isLiveItem]).
final chosenBranchIdsProvider = Provider.autoDispose.family<Set<int>, int>((
  ref,
  tripId,
) {
  final branches = ref.watch(alternativeBranchesProvider(tripId)).value;
  return branches == null ? const {} : chosenBranchIds(branches);
});

/// Per-mode transport statistics for a trip: how many legs and how much time
/// each [TransportMode] accounts for. Derives from the trip's *live* legs (the
/// plan as it stands — unchosen alternatives are excluded, just as they are
/// from the money) via [computeTransportStats].
final transportStatsProvider = Provider.autoDispose.family<TransportStats, int>(
  (ref, tripId) {
    final items = ref.watch(itineraryProvider(tripId)).value;
    if (items == null) return const TransportStats([]);
    final chosen = ref.watch(chosenBranchIdsProvider(tripId));
    return computeTransportStats(liveItems(items, chosen));
  },
);

/// Transport statistics pooled across **all** trips — the overall overview. Each
/// trip is aggregated (and time-balanced) on its own and the results are summed
/// per mode; see [mergeTransportStats].
final allTripsTransportStatsProvider = Provider.autoDispose<TransportStats>((
  ref,
) {
  final trips = ref.watch(tripListProvider).value ?? const <Trip>[];
  return mergeTransportStats([
    for (final trip in trips) ref.watch(transportStatsProvider(trip.id)),
  ]);
});
