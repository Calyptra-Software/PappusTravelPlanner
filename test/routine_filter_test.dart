import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/trips/routine_filter.dart';

/// How the routine list is narrowed. The sibling of `trip_filter_test.dart`,
/// and deliberately a shorter question: a routine has no dates, so there is no
/// status, no range and no date order to test.
void main() {
  Trip routine({
    required int id,
    String title = 'Routine',
    String destination = '',
    String? notes,
    DateTime? createdAt,
    TripKind kind = TripKind.routine,
  }) {
    return Trip(
      id: id,
      title: title,
      destination: destination,
      notes: notes,
      kind: kind,
      colorValue: 0xFF00695C,
      coverHidden: false,
      photosCollapsed: false,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
    );
  }

  List<Trip> run(
    List<Trip> routines,
    RoutineQuery query, {
    Map<int, Set<int>> tags = const {},
    Map<int, Set<int>> participants = const {},
  }) => applyRoutineQuery(
    routines,
    query: query,
    tagsByTrip: tags,
    participantsByTrip: participants,
  );

  test('a trip is never in the routine list', () {
    final rows = [
      routine(id: 1, title: 'Commute'),
      routine(id: 2, title: 'Commute to Rome', kind: TripKind.trip),
    ];
    expect(run(rows, const RoutineQuery()).map((r) => r.id), [1]);
  });

  group('text search', () {
    final rows = [
      routine(id: 1, title: 'Morning commute', destination: 'Office'),
      routine(id: 2, title: 'Saturday ride', notes: 'Along the Elbe'),
      routine(id: 3, title: 'Shopping run', destination: 'Rahlstedt'),
    ];

    test('matches title, destination and notes, case-insensitively', () {
      expect(run(rows, const RoutineQuery(text: 'COMMUTE')).map((r) => r.id), [
        1,
      ]);
      expect(
        run(rows, const RoutineQuery(text: 'rahlstedt')).map((r) => r.id),
        [3],
      );
      expect(run(rows, const RoutineQuery(text: 'elbe')).map((r) => r.id), [2]);
    });

    test('whitespace alone is no search at all', () {
      expect(run(rows, const RoutineQuery(text: '   ')).length, rows.length);
    });
  });

  group('tags', () {
    final rows = [routine(id: 1), routine(id: 2), routine(id: 3)];
    const tags = {
      1: {10},
      2: {20},
    };

    test('match any-of, and an untagged routine matches none of them', () {
      expect(
        run(
          rows,
          const RoutineQuery(tagIds: {10, 20}),
          tags: tags,
        ).map((r) => r.id),
        [1, 2],
      );
      expect(
        run(
          rows,
          const RoutineQuery(tagIds: {10}),
          tags: tags,
        ).map((r) => r.id),
        [1],
      );
    });

    test('an empty selection is no restriction', () {
      expect(run(rows, const RoutineQuery(), tags: tags).length, 3);
    });
  });

  test('participants match any-of', () {
    final rows = [routine(id: 1), routine(id: 2), routine(id: 3)];
    const participants = {
      1: {5},
      2: {6, 7},
    };
    expect(
      run(
        rows,
        const RoutineQuery(participantIds: {7}),
        participants: participants,
      ).map((r) => r.id),
      [2],
    );
  });

  test('the facets compose with AND', () {
    final rows = [
      routine(id: 1, title: 'Commute'),
      routine(id: 2, title: 'Commute'),
    ];
    expect(
      run(
        rows,
        const RoutineQuery(text: 'commute', tagIds: {10}),
        tags: {
          2: {10},
        },
      ).map((r) => r.id),
      [2],
    );
  });

  group('sort', () {
    final rows = [
      routine(id: 1, title: 'shopping', createdAt: DateTime(2026, 3, 1)),
      routine(id: 2, title: 'Commute', createdAt: DateTime(2026, 5, 1)),
      routine(id: 3, title: 'Ride', createdAt: DateTime(2026, 1, 1)),
    ];

    test('by name, case-insensitively', () {
      expect(
        run(
          rows,
          const RoutineQuery(sort: RoutineSort.nameAsc),
        ).map((r) => r.id),
        [2, 3, 1],
      );
    });

    test('by when it was made, newest first', () {
      expect(
        run(
          rows,
          const RoutineQuery(sort: RoutineSort.createdDesc),
        ).map((r) => r.id),
        [2, 1, 3],
      );
    });

    test('same name falls back to the newer one first', () {
      final same = [
        routine(id: 1, title: 'Commute', createdAt: DateTime(2026, 1, 1)),
        routine(id: 2, title: 'commute', createdAt: DateTime(2026, 6, 1)),
      ];
      expect(run(same, const RoutineQuery()).map((r) => r.id), [2, 1]);
    });
  });

  group('activeFilterCount', () {
    test('counts the filter facets, not the search or the sort', () {
      expect(const RoutineQuery().activeFilterCount, 0);
      expect(
        const RoutineQuery(
          text: 'commute',
          sort: RoutineSort.createdDesc,
        ).activeFilterCount,
        0,
      );
      expect(
        const RoutineQuery(tagIds: {1}, participantIds: {2}).activeFilterCount,
        2,
      );
    });

    test('clearedFilters keeps the search and the sort', () {
      const query = RoutineQuery(
        text: 'commute',
        tagIds: {1},
        participantIds: {2},
        sort: RoutineSort.createdDesc,
      );
      final cleared = query.clearedFilters();
      expect(cleared.hasActiveFilters, isFalse);
      expect(cleared.text, 'commute');
      expect(cleared.sort, RoutineSort.createdDesc);
    });
  });
}
