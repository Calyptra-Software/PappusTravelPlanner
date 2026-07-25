import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/features/trips/trip_filter.dart';

void main() {
  final today = DateTime(2026, 7, 10);

  Trip trip({
    required int id,
    String title = 'Trip',
    String destination = '',
    String? notes,
    DateTime? start,
    DateTime? end,
    DateTime? createdAt,
  }) {
    return Trip(
      id: id,
      title: title,
      destination: destination,
      startDate: start,
      endDate: end,
      notes: notes,
      colorValue: 0xFF00695C,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
    );
  }

  List<Trip> run(
    List<Trip> trips,
    TripQuery query, {
    Map<int, Set<int>> participants = const {},
    Map<int, Map<String, int>> totals = const {},
  }) => applyTripQuery(
    trips,
    query: query,
    participantsByTrip: participants,
    today: today,
    totalsByTrip: totals,
  );

  group('tripStatus', () {
    test('classifies relative to today', () {
      expect(
        tripStatus(trip(id: 1, start: DateTime(2026, 8, 1)), today),
        TripStatus.upcoming,
      );
      expect(
        tripStatus(
          trip(id: 2, start: DateTime(2026, 7, 8), end: DateTime(2026, 7, 12)),
          today,
        ),
        TripStatus.ongoing,
      );
      expect(
        tripStatus(trip(id: 3, start: DateTime(2026, 6, 1)), today),
        TripStatus.past,
      );
      expect(tripStatus(trip(id: 4), today), TripStatus.undated);
    });

    test('single-day trip with no end date is ongoing on that day', () {
      expect(tripStatus(trip(id: 1, start: today), today), TripStatus.ongoing);
    });
  });

  group('text search', () {
    final trips = [
      trip(id: 1, title: 'Rome getaway', destination: 'Italy'),
      trip(
        id: 2,
        title: 'Ski week',
        destination: 'Austria',
        notes: 'bring gloves',
      ),
    ];

    test('matches title, destination and notes case-insensitively', () {
      expect(run(trips, const TripQuery(text: 'rome')).map((t) => t.id), [1]);
      expect(run(trips, const TripQuery(text: 'austria')).map((t) => t.id), [
        2,
      ]);
      expect(run(trips, const TripQuery(text: 'GLOVES')).map((t) => t.id), [2]);
    });

    test('empty query returns all', () {
      expect(run(trips, const TripQuery()).length, 2);
    });
  });

  test('status filter keeps only matching statuses', () {
    final trips = [
      trip(id: 1, start: DateTime(2026, 8, 1)), // upcoming
      trip(id: 2, start: DateTime(2026, 6, 1)), // past
      trip(id: 3), // undated
    ];
    final result = run(trips, const TripQuery(statuses: {TripStatus.upcoming}));
    expect(result.map((t) => t.id), [1]);
  });

  test('participant filter matches trips including any selected person', () {
    final trips = [trip(id: 1), trip(id: 2), trip(id: 3)];
    final result = run(
      trips,
      const TripQuery(participantIds: {10}),
      participants: {
        1: {10, 11},
        2: {11},
        3: {12},
      },
    );
    expect(result.map((t) => t.id), [1]);
  });

  group('date range', () {
    final trips = [
      trip(id: 1, start: DateTime(2026, 7, 1), end: DateTime(2026, 7, 5)),
      trip(id: 2, start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 10)),
      trip(id: 3), // undated
    ];

    test('keeps trips overlapping the range and drops undated', () {
      final result = run(
        trips,
        TripQuery(from: DateTime(2026, 7, 4), to: DateTime(2026, 7, 20)),
      );
      expect(result.map((t) => t.id), [1]);
    });
  });

  group('sort', () {
    final trips = [
      trip(id: 1, title: 'Zurich', start: DateTime(2026, 8, 1)),
      trip(id: 2, title: 'Athens', start: DateTime(2026, 6, 1)),
      trip(
        id: 3,
        title: 'Berlin',
        createdAt: DateTime(2026, 5, 1),
      ), // undated, newest
    ];

    test('dateAsc orders by start with undated last', () {
      expect(
        run(trips, const TripQuery(sort: TripSort.dateAsc)).map((t) => t.id),
        [2, 1, 3],
      );
    });

    test('dateDesc orders by start descending with undated still last', () {
      expect(
        run(trips, const TripQuery(sort: TripSort.dateDesc)).map((t) => t.id),
        [1, 2, 3],
      );
    });

    test('nameAsc orders alphabetically', () {
      expect(
        run(trips, const TripQuery(sort: TripSort.nameAsc)).map((t) => t.id),
        [2, 3, 1],
      );
    });

    // Trip 1 ranks by its largest bucket (GBP 500), not the EUR+USD sum;
    // trip 3 has no costs and ranks as 0.
    final totals = {
      1: {'EUR': 30000, 'USD': 5000, 'GBP': 50000},
      2: {'EUR': 40000},
    };

    test(
      'expenseDesc orders by largest currency bucket, no-cost trips last',
      () {
        expect(
          run(
            trips,
            const TripQuery(sort: TripSort.expenseDesc),
            totals: totals,
          ).map((t) => t.id),
          [1, 2, 3],
        );
      },
    );

    test('expenseAsc orders ascending with no-cost trips first', () {
      expect(
        run(
          trips,
          const TripQuery(sort: TripSort.expenseAsc),
          totals: totals,
        ).map((t) => t.id),
        [3, 2, 1],
      );
    });
  });

  group('tripExpenseKey', () {
    test(
      'is the largest single-currency bucket, never a cross-currency sum',
      () {
        expect(tripExpenseKey({'EUR': 30000, 'GBP': 50000}), 50000);
      },
    );

    test('is 0 for a trip with no costs', () {
      expect(tripExpenseKey(null), 0);
      expect(tripExpenseKey(const {}), 0);
    });
  });

  test('activeFilterCount counts facets, not search or sort', () {
    expect(
      const TripQuery(text: 'x', sort: TripSort.nameAsc).activeFilterCount,
      0,
    );
    expect(
      TripQuery(
        statuses: const {TripStatus.past},
        participantIds: const {1},
        from: DateTime(2026, 1, 1),
      ).activeFilterCount,
      3,
    );
  });
}
