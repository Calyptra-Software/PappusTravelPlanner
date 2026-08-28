import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/features/trips/application/routine_query_provider.dart';
import 'package:travelplanner/features/trips/application/trip_query_provider.dart';
import 'package:travelplanner/features/trips/routine_filter.dart';
import 'package:travelplanner/features/trips/trip_filter.dart';

/// How the routine list's filters and sort survive a restart — the same rules
/// the overview's do, plus the one that only arises with two lists: they are
/// stored apart, so filtering one never moves the other.
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
    const defaults = RoutineQuery();
    final query = launch().read(routineQueryProvider);
    expect(query.text, defaults.text);
    expect(query.tagIds, defaults.tagIds);
    expect(query.participantIds, defaults.participantIds);
    expect(query.sort, defaults.sort);
  });

  test(
    'every filter facet and the sort come back on the next launch',
    () async {
      await launch()
          .read(routineQueryProvider.notifier)
          .setQuery(
            const RoutineQuery(
              tagIds: {1, 4},
              participantIds: {3, 7},
              sort: RoutineSort.createdDesc,
            ),
          );

      final restored = launch().read(routineQueryProvider);
      expect(restored.tagIds, {1, 4});
      expect(restored.participantIds, {3, 7});
      expect(restored.sort, RoutineSort.createdDesc);
    },
  );

  test('the search text is not remembered — a search is one act', () async {
    await launch()
        .read(routineQueryProvider.notifier)
        .setQuery(
          const RoutineQuery(text: 'commute', sort: RoutineSort.createdDesc),
        );

    final restored = launch().read(routineQueryProvider);
    expect(restored.text, isEmpty);
    expect(
      restored.sort,
      RoutineSort.createdDesc,
      reason: 'the rest still travels',
    );
  });

  test('typing in the search box writes nothing', () {
    final container = launch();
    container.read(routineQueryProvider.notifier).setText('Co');
    expect(container.read(routineQueryProvider).text, 'Co');
    expect(prefs.getKeys(), isEmpty);
  });

  test('clearing the filters clears what was stored', () async {
    final first = launch();
    await first
        .read(routineQueryProvider.notifier)
        .setQuery(
          const RoutineQuery(
            tagIds: {2},
            participantIds: {5},
            sort: RoutineSort.createdDesc,
          ),
        );
    await first
        .read(routineQueryProvider.notifier)
        .setQuery(first.read(routineQueryProvider).clearedFilters());

    final restored = launch().read(routineQueryProvider);
    expect(restored.hasActiveFilters, isFalse);
    // Clearing the filters is not clearing the sort.
    expect(restored.sort, RoutineSort.createdDesc);
  });

  test('the two lists are filtered apart', () async {
    final container = launch();
    await container
        .read(routineQueryProvider.notifier)
        .setQuery(const RoutineQuery(tagIds: {1}));

    expect(container.read(tripQueryProvider).tagIds, isEmpty);

    await container
        .read(tripQueryProvider.notifier)
        .setQuery(const TripQuery(tagIds: {9}));

    expect(container.read(routineQueryProvider).tagIds, {1});
  });

  group('a store written by another build', () {
    test('a sort index this build has no name for falls back', () async {
      await seed({'routines_sort': RoutineSort.values.length});

      expect(
        launch().read(routineQueryProvider).sort,
        const RoutineQuery().sort,
      );
    });

    test(
      'an unreadable id is skipped rather than failing the launch',
      () async {
        await seed({
          'routines_filter_tag_ids': ['2', 'seven'],
        });

        expect(launch().read(routineQueryProvider).tagIds, {2});
      },
    );
  });
}
