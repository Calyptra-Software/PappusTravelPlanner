import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/features/trips/application/stats_trips_provider.dart';
import 'package:travelplanner/features/trips/application/trip_providers.dart';

/// Which trips the all-trips statistics count — decided once, so the tabs
/// cannot disagree about it.
void main() {
  Trip row(int id, TripKind kind) => Trip(
    id: id,
    title: 'Trip $id',
    destination: '',
    kind: kind,
    colorValue: 0xFF112233,
    coverHidden: false,
    photosCollapsed: false,
    createdAt: DateTime(2026),
  );

  ItineraryItem leg(int id, int tripId) => ItineraryItem(
    id: id,
    tripId: tripId,
    date: DateTime(2026, 5, 1),
    sortOrder: id,
    kind: ItemKind.transport,
    spansNextDay: false,
    mode: 1,
    startMinutes: 480,
    endMinutes: 510,
  );

  test(
    'the transport tab leaves the routines out, as the expenses do',
    () async {
      final trip = row(1, TripKind.trip);
      final routine = row(2, TripKind.routine);
      final container = ProviderContainer(
        overrides: [
          tripListProvider.overrideWith((ref) => Stream.value([trip, routine])),
          for (final id in [1, 2]) ...[
            itineraryProvider(
              id,
            ).overrideWith((ref) => Stream.value([leg(id, id)])),
            alternativeBranchesProvider(
              id,
            ).overrideWith((ref) => Stream.value(const {})),
          ],
        ],
      );
      addTearDown(container.dispose);

      // Held open, since everything here is autoDispose; the streams then need
      // a turn of the event loop to deliver.
      final trips = container.listen(statsTripsProvider, (_, _) {});
      final transport = container.listen(
        allTripsTransportStatsProvider,
        (_, _) {},
      );
      await pumpEventQueue();

      expect([for (final t in trips.read()) t.id], [1]);
      // One commute made, not one made plus the template it was made from.
      expect(transport.read().totalLegs, 1);
      expect(transport.read().totalPlannedMinutes, 30);
    },
  );
}
