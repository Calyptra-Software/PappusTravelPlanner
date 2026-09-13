import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../trip_filter.dart';
import 'trip_providers.dart';

/// The filter the all-trips statistics are read through.
///
/// A query of its **own**, not the overview's [tripQueryProvider]: the
/// statistics answer "how much" and "how far", and an answer that moved because
/// a tag chip had been tapped on another screen would not be an answer to
/// either. Narrowing them is fine; narrowing them unnoticed is not — so the
/// filter is set on the statistics screen, and said there.
///
/// And **not remembered**: `autoDispose`, so leaving the screen drops it and
/// every visit opens on every trip. The overview persists its filter because
/// it is a way of reading a list used daily; a statistic is one question, and a
/// subset left standing from last time would be read as the whole record, which
/// is exactly the misreading a count line can say but not prevent.
final statsTripQueryProvider =
    NotifierProvider.autoDispose<StatsTripQueryController, TripQuery>(
      StatsTripQueryController.new,
    );

class StatsTripQueryController extends Notifier<TripQuery> {
  @override
  TripQuery build() => const TripQuery();

  void setQuery(TripQuery query) => state = query;
}

/// Every trip the all-trips statistics could count: the whole trip list less
/// the routines. The denominator of the statistics' count line.
///
/// Read through [applyTripQuery] with nothing asked of it, not by testing the
/// kind here, so that what "a trip" means is decided in one place.
final allStatsTripsProvider = Provider.autoDispose<List<Trip>>((ref) {
  final trips = ref.watch(tripListProvider).value ?? const <Trip>[];
  return applyTripQuery(
    trips,
    query: const TripQuery(),
    participantsByTrip: const {},
    today: DateTime.now(),
  );
});

/// The trips the all-trips statistics count, decided **once** for every tab.
///
/// Each tab used to walk [tripListProvider] on its own, and they disagreed:
/// the expenses left the routines out, while the transport tab and the
/// countries tab took them in — so a commute described once as a template and
/// stamped out every morning was counted once more than it was traveled. A
/// routine is a plan, not something that happened; [applyTripQuery] already
/// drops it, and reading the answer through that function — with
/// [statsTripQueryProvider] — is what keeps the three tabs from drifting apart
/// again.
///
/// The tag and participant maps are watched only while a facet asks for them:
/// they are two more database streams, and the unfiltered statistics, which is
/// how the screen always opens, have no use for either.
final statsTripsProvider = Provider.autoDispose<List<Trip>>((ref) {
  final all = ref.watch(allStatsTripsProvider);
  final query = ref.watch(statsTripQueryProvider);
  if (!query.hasActiveFilters) return all;

  final tagsByTrip = query.tagIds.isEmpty
      ? const <int, List<Tag>>{}
      : (ref.watch(tagsByTripProvider).value ?? const {});
  final participantsByTrip = query.participantIds.isEmpty
      ? const <int, List<Person>>{}
      : (ref.watch(allParticipantsProvider).value ?? const {});
  return applyTripQuery(
    all,
    query: query,
    participantsByTrip: {
      for (final entry in participantsByTrip.entries)
        entry.key: {for (final person in entry.value) person.id},
    },
    tagsByTrip: {
      for (final entry in tagsByTrip.entries)
        entry.key: {for (final tag in entry.value) tag.id},
    },
    today: DateTime.now(),
  );
});
