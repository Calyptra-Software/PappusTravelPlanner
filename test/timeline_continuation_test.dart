import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/costs/application/cost_providers.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/itinerary/widgets/itinerary_timeline.dart';
import 'package:travelplanner/features/itinerary/widgets/now_line.dart';
import 'package:travelplanner/features/itinerary/widgets/timeline_tile.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'currency_fixture.dart';
import 'support/attachment_overrides.dart';

/// Covers what a day shows of an entry that began on an earlier one: the
/// morning a night train arrives used to read "Nothing planned yet" while the
/// traveller was still on the train.
void main() {
  final monday = DateTime(2026, 7, 6);
  final tuesday = DateTime(2026, 7, 7);
  final wednesday = DateTime(2026, 7, 8);

  ItineraryItem nightTrain({
    int endDayOffset = 1,
    int? actualEnd,
    DateTime? date,
  }) => ItineraryItem(
    id: 1,
    tripId: 1,
    date: date ?? monday,
    sortOrder: 0,
    kind: ItemKind.transport,
    endDayOffset: endDayOffset,
    chordDisplay: TrackDisplay.auto,
    title: 'NJ 40',
    fromLocation: 'Hamburg',
    toLocation: 'Vienna',
    mode: 6,
    startMinutes: 22 * 60 + 14,
    endMinutes: 7 * 60 + 12,
    actualEndMinutes: actualEnd,
  );

  Future<List<ItineraryItem>> pump(
    WidgetTester tester, {
    required List<ItineraryItem> items,
    required DateTime start,
    required DateTime end,
    DateTime? now,
    ValueChanged<ItineraryItem>? onTapItem,
  }) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(420, 2400);
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...currencyOverrides,
          repositoryProvider.overrideWithValue(TripRepository(db)),
          ...attachmentTestOverrides,
          sharedPreferencesProvider.overrideWithValue(prefs),
          reasonRowsProvider.overrideWith((ref) => Stream.value(const [])),
          transportModesProvider.overrideWith(
            (ref) => Stream.value([
              TransportModeRow(id: 6, builtinKey: 'train', sortOrder: 0),
            ]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItineraryTimeline(
                items: items,
                accent: Colors.teal,
                tripStart: start,
                tripEnd: end,
                onTapItem: onTapItem ?? (_) {},
                onAddPlace: (_, {alternativeId}) {},
                onQuickAddPlace: (_, _, {alternativeId}) {},
                onAddTransport: (_, _, {alternativeId}) {},
                onReorder: (_, _, _) {},
                onReorderBranch: (_, _, _) {},
                onReorderRun: (_, _, _) {},
                costsByItem: const {},
                groups: const {},
                costsByGroup: const {},
                sets: const {},
                branches: const {},
                localeName: 'en',
                onTapCost: (_) {},
                collapsedDays: const {},
                onToggleDayCollapsed: (_, _) {},
                now: now ?? DateTime(2026, 1, 1, 12),
                held: null,
                onPutDown: (_, {alternativeId}) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return items;
  }

  testWidgets('the morning after says when the train arrives', (tester) async {
    await pump(tester, items: [nightTrain()], start: monday, end: tuesday);

    // The departure day draws the entry itself, with its arrival day marked.
    expect(find.text('22:14 – 07:12 +1'), findsOneWidget);
    // The arrival day refers to it, and is not "nothing planned".
    expect(find.byType(ContinuationTile), findsOneWidget);
    expect(find.text('Arrives 07:12'), findsOneWidget);
    expect(find.text('Nothing planned yet.'), findsNothing);
  });

  testWidgets('a late arrival carries its delay onto the arrival day', (
    tester,
  ) async {
    await pump(
      tester,
      items: [nightTrain(actualEnd: 7 * 60 + 27)],
      start: monday,
      end: tuesday,
    );
    expect(find.text('Arrives 07:12 (+15)'), findsOneWidget);
  });

  testWidgets('a two-night journey runs through the day between', (
    tester,
  ) async {
    await pump(
      tester,
      items: [nightTrain(endDayOffset: 2)],
      start: monday,
      end: wednesday,
    );
    expect(find.byType(ContinuationTile), findsNWidgets(2));
    expect(find.text('Continues all day'), findsOneWidget);
    expect(find.text('Arrives 07:12'), findsOneWidget);
  });

  testWidgets('the arrival day is shown even outside the trip\'s dates', (
    tester,
  ) async {
    // A trip that says it is one day long, with a train leaving on it.
    await pump(tester, items: [nightTrain()], start: monday, end: monday);
    expect(find.byType(ContinuationTile), findsOneWidget);
  });

  testWidgets('a tap opens the entry it refers to', (tester) async {
    ItineraryItem? tapped;
    await pump(
      tester,
      items: [nightTrain()],
      start: monday,
      end: tuesday,
      onTapItem: (item) => tapped = item,
    );
    await tester.tap(find.text('Arrives 07:12'));
    expect(tapped?.id, 1);
  });

  testWidgets('on the morning it is still running, it is what is happening', (
    tester,
  ) async {
    await pump(
      tester,
      items: [nightTrain()],
      start: monday,
      end: tuesday,
      now: DateTime(2026, 7, 7, 6, 30),
    );
    expect(
      find.descendant(
        of: find.byType(ContinuationTile),
        matching: find.byType(NowBadge),
      ),
      findsOneWidget,
    );
  });

  testWidgets('and once it has arrived, it is not', (tester) async {
    await pump(
      tester,
      items: [nightTrain()],
      start: monday,
      end: tuesday,
      now: DateTime(2026, 7, 7, 8),
    );
    expect(find.byType(NowBadge), findsNothing);
  });

  testWidgets('the night the clocks go back is still one day', (tester) async {
    // Europe/Berlin falls back on 2026-10-25; that day is 25 hours long, and
    // adding 24 of them to its midnight once gave it a second heading.
    // (Only meaningful where the test runs in a zone with that change; in UTC
    // it passes trivially.)
    final items = [
      for (final (i, d) in [
        DateTime(2026, 10, 24),
        DateTime(2026, 10, 25),
        DateTime(2026, 10, 26),
      ].indexed)
        ItineraryItem(
          id: 100 + i,
          tripId: 1,
          date: d,
          sortOrder: 0,
          kind: ItemKind.place,
          endDayOffset: 0,
          chordDisplay: TrackDisplay.auto,
          title: 'Place $i',
        ),
    ];
    await pump(
      tester,
      items: items,
      start: DateTime(2026, 10, 24),
      end: DateTime(2026, 10, 26),
    );
    // Three days, three headings, each numbered once.
    for (final n in ['1', '2', '3']) {
      expect(find.text(n), findsOneWidget);
    }
    expect(find.text('4'), findsNothing);
  });
}
