import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/features/trips/application/trip_query_provider.dart';
import 'package:travelplanner/features/trips/trip_filter.dart';

/// How the overview's filters and sort survive a restart: what is stored, what
/// deliberately is not, and what a store written by another build reads as.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Replaces the store's contents — a launch onto preferences this build did
  /// not write.
  Future<void> seed(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
  }

  /// A fresh container over the same store — i.e. the next launch.
  ProviderContainer launch() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a store with nothing in it reads as the default query', () {
    const defaults = TripQuery();
    final query = launch().read(tripQueryProvider);
    expect(query.text, defaults.text);
    expect(query.statuses, defaults.statuses);
    expect(query.participantIds, defaults.participantIds);
    expect(query.tagIds, defaults.tagIds);
    expect(query.from, isNull);
    expect(query.to, isNull);
    expect(query.sort, defaults.sort);
  });

  test(
    'every filter facet and the sort come back on the next launch',
    () async {
      await launch()
          .read(tripQueryProvider.notifier)
          .setQuery(
            TripQuery(
              statuses: const {TripStatus.upcoming, TripStatus.ongoing},
              participantIds: const {3, 7},
              tagIds: const {1, 4},
              from: DateTime(2026, 7, 1),
              to: DateTime(2026, 7, 31),
              sort: TripSort.expenseDesc,
            ),
          );

      final restored = launch().read(tripQueryProvider);
      expect(restored.statuses, {TripStatus.upcoming, TripStatus.ongoing});
      expect(restored.participantIds, {3, 7});
      expect(restored.tagIds, {1, 4});
      expect(restored.from, DateTime(2026, 7, 1));
      expect(restored.to, DateTime(2026, 7, 31));
      expect(restored.sort, TripSort.expenseDesc);
    },
  );

  test('the search text is not remembered — a search is one act', () async {
    await launch()
        .read(tripQueryProvider.notifier)
        .setQuery(const TripQuery(text: 'Rome', sort: TripSort.nameAsc));

    final restored = launch().read(tripQueryProvider);
    expect(restored.text, isEmpty);
    expect(restored.sort, TripSort.nameAsc, reason: 'the rest still travels');
  });

  test('typing in the search box writes nothing', () async {
    final container = launch();
    container.read(tripQueryProvider.notifier).setText('Ro');
    expect(container.read(tripQueryProvider).text, 'Ro');
    expect(prefs.getKeys(), isEmpty);
  });

  test('clearing the filters clears what was stored', () async {
    final first = launch();
    await first
        .read(tripQueryProvider.notifier)
        .setQuery(
          TripQuery(
            statuses: const {TripStatus.past},
            tagIds: const {2},
            from: DateTime(2026, 7, 1),
            to: DateTime(2026, 7, 31),
            sort: TripSort.nameAsc,
          ),
        );
    await first
        .read(tripQueryProvider.notifier)
        .setQuery(first.read(tripQueryProvider).clearedFilters());

    final restored = launch().read(tripQueryProvider);
    expect(restored.hasActiveFilters, isFalse);
    expect(restored.from, isNull);
    expect(restored.to, isNull);
    // Clearing the filters is not clearing the sort.
    expect(restored.sort, TripSort.nameAsc);
  });

  test('a date bound is stored as a day, whatever time it carried', () async {
    await launch()
        .read(tripQueryProvider.notifier)
        .setQuery(TripQuery(from: DateTime(2026, 7, 1, 18, 30)));

    expect(launch().read(tripQueryProvider).from, DateTime(2026, 7, 1));
  });

  group('a store written by another build', () {
    test('a status bit this build has no name for is dropped', () async {
      await seed({
        'trips_filter_statuses':
            (1 << TripStatus.ongoing.index) | (1 << TripStatus.values.length),
      });

      expect(launch().read(tripQueryProvider).statuses, {TripStatus.ongoing});
    });

    test('a sort index this build has no name for falls back', () async {
      await seed({'trips_sort': TripSort.values.length});

      expect(launch().read(tripQueryProvider).sort, const TripQuery().sort);
    });

    test(
      'an unreadable id is skipped rather than failing the launch',
      () async {
        await seed({
          'trips_filter_tag_ids': ['2', 'seven'],
        });

        expect(launch().read(tripQueryProvider).tagIds, {2});
      },
    );
  });
}
