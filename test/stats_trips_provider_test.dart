import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/features/trips/application/stats_trips_provider.dart';
import 'package:travelplanner/features/trips/application/trip_providers.dart';
import 'package:travelplanner/features/trips/trip_filter.dart';

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
    endDayOffset: 0,
    chordDisplay: TrackDisplay.auto,
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

  Tag tag(int id) => Tag(id: id, name: 'tag $id', colorValue: 0, sortOrder: id);

  ProviderContainer filterable() {
    final container = ProviderContainer(
      overrides: [
        tripListProvider.overrideWith(
          (ref) => Stream.value([
            row(1, TripKind.trip),
            row(2, TripKind.trip),
            row(3, TripKind.routine),
          ]),
        ),
        allParticipantsProvider.overrideWith(
          (ref) => Stream.value(const {
            2: [Person(id: 20, name: 'Ann', isMe: false)],
          }),
        ),
        tagsByTripProvider.overrideWith(
          (ref) => Stream.value({
            1: [tag(10)],
            3: [tag(10)],
          }),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'the statistics filter narrows the counted trips, not the total',
    () async {
      final container = filterable();
      final counted = container.listen(statsTripsProvider, (_, _) {});
      final total = container.listen(allStatsTripsProvider, (_, _) {});
      await pumpEventQueue();
      expect([for (final t in counted.read()) t.id], [1, 2]);

      container
          .read(statsTripQueryProvider.notifier)
          .setQuery(const TripQuery(tagIds: {10}));
      await pumpEventQueue();

      // The routine wears the tag too, and is still no trip.
      expect([for (final t in counted.read()) t.id], [1]);
      expect(total.read().length, 2);
    },
  );

  test('a participant selects the trips they were on', () async {
    final container = filterable();
    final counted = container.listen(statsTripsProvider, (_, _) {});
    container
        .read(statsTripQueryProvider.notifier)
        .setQuery(const TripQuery(participantIds: {20}));
    await pumpEventQueue();

    expect([for (final t in counted.read()) t.id], [2]);
  });

  test('the filter is not remembered once nothing reads it', () async {
    final container = filterable();
    var sub = container.listen(statsTripQueryProvider, (_, _) {});
    container
        .read(statsTripQueryProvider.notifier)
        .setQuery(const TripQuery(tagIds: {10}));
    expect(sub.read().hasActiveFilters, isTrue);

    // Leaving the screen is the last listener going away.
    sub.close();
    await pumpEventQueue();
    sub = container.listen(statsTripQueryProvider, (_, _) {});

    expect(sub.read().hasActiveFilters, isFalse);
  });
}
