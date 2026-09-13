import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../trip_filter.dart';
import 'trip_providers.dart';

/// The trips the all-trips statistics count, decided **once** for every tab.
///
/// Each tab used to walk [tripListProvider] on its own, and they disagreed:
/// the expenses left the routines out, while the transport tab and the
/// countries tab took them in — so a commute described once as a template and
/// stamped out every morning was counted once more than it was traveled. A
/// routine is a plan, not something that happened; [applyTripQuery] already
/// drops it, and reading the answer through that function is what keeps the
/// three tabs from drifting apart again.
final statsTripsProvider = Provider.autoDispose<List<Trip>>((ref) {
  final trips = ref.watch(tripListProvider).value ?? const <Trip>[];
  return applyTripQuery(
    trips,
    query: const TripQuery(),
    participantsByTrip: const {},
    today: DateTime.now(),
  );
});
