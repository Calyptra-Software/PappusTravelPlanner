import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/trips/presentation/trip_detail_screen.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Drives the real routine screens against a real in-memory database, through
/// the same widgets the app runs — the run sheet, the timeline, the header.
///
/// Regression: a one-day routine whose legs had been imported for a real
/// timetable offered "1 August 2026 – 1 March 2083" when asked to stamp out a
/// trip, because the plan's length was read as the distance from its 1970
/// anchor rather than as the days it actually shows.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpRoutine(WidgetTester tester, AppDatabase db, int id) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripDetailScreen(tripId: id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a one-day routine offers a one-day trip, whatever dates its '
      'legs were imported with', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final routineId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'To work',
        kind: const Value(TripKind.routine),
      ),
    );
    // Exactly the shape the bug produced: a leg carrying the real date its
    // connection was searched on, not a day of the plan.
    await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: routineId,
        date: DateTime(2026, 8, 3),
        kind: ItemKind.transport,
        mode: const Value(6),
        fromLocation: const Value('Home'),
        toLocation: const Value('Office'),
      ),
    );

    await pumpRoutine(tester, db, routineId);

    // The routine's own screen numbers its days rather than dating them.
    expect(find.text('Home  →  Office'), findsOneWidget);
    expect(find.textContaining('2083'), findsNothing);

    // Open the run sheet.
    await tester.tap(find.text('Create trip'));
    await tester.pumpAndSettle();
    expect(find.text('Create trip for'), findsOneWidget);

    // One day means one date, with no range and nothing in the far future.
    expect(find.textContaining('2083'), findsNothing);
    expect(find.textContaining('–'), findsNothing);

    // Stamp it out and check the trip that lands.
    await tester.tap(find.widgetWithText(FilledButton, 'Create trip'));
    await tester.pumpAndSettle();

    final trips = await (db.select(
      db.trips,
    )..where((t) => t.kind.equalsValue(TripKind.trip))).get();
    expect(trips, hasLength(1));
    final trip = trips.single;
    expect(
      trip.endDate,
      trip.startDate,
      reason: 'a one-day routine makes a one-day trip',
    );
    expect(trip.fromRoutineId, routineId);

    // And its entry landed on that one day, not on the date it was imported for.
    final items = await (db.select(
      db.itineraryItems,
    )..where((i) => i.tripId.equals(trip.id))).get();
    expect(items.single.date, trip.startDate);
  });

  testWidgets('a three-day routine reads as Day 1..3 and stamps out three '
      'consecutive days', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final routineId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Cabin run',
        kind: const Value(TripKind.routine),
      ),
    );
    for (final (index, date) in [
      DateTime(1970, 1, 1),
      DateTime(1970, 1, 2),
      DateTime(1970, 1, 3),
    ].indexed) {
      await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: routineId,
          date: date,
          kind: ItemKind.place,
          location: Value('Stop $index'),
        ),
      );
    }

    await pumpRoutine(tester, db, routineId);

    // A routine has no dates, so its days are numbered — and no day of it is
    // "today", however the clock reads.
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('Day 2'), findsOneWidget);
    expect(find.text('Day 3'), findsOneWidget);
    expect(find.textContaining('1970'), findsNothing);

    await tester.tap(find.text('Create trip'));
    await tester.pumpAndSettle();
    // Three days is a range, and the sheet says so before anything is written.
    expect(find.textContaining('–'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Create trip'));
    await tester.pumpAndSettle();

    final trip = (await (db.select(
      db.trips,
    )..where((t) => t.kind.equalsValue(TripKind.trip))).get()).single;
    expect(trip.endDate!.difference(trip.startDate!).inDays, 3 - 1);
  });

  testWidgets('the header lengthens as soon as a second day is planned', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final routineId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Cabin run',
        kind: const Value(TripKind.routine),
      ),
    );
    await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: routineId,
        date: DateTime(1970, 1, 1),
        kind: ItemKind.place,
        location: const Value('Stop 0'),
      ),
    );

    await pumpRoutine(tester, db, routineId);
    expect(find.textContaining('1 day'), findsOneWidget);

    // A second day is planned while the screen is open. Regression: the header
    // was read once when the screen opened, so it went on claiming one day
    // until the routine was closed and reopened.
    await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: routineId,
        date: DateTime(1970, 1, 2),
        kind: ItemKind.place,
        location: const Value('Stop 1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2 days'), findsOneWidget);
    expect(find.text('Day 2'), findsOneWidget);
  });

  testWidgets('a day is added by asking for one, and planned on by ordinal', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final routineId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Cabin run',
        kind: const Value(TripKind.routine),
      ),
    );
    await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: routineId,
        date: DateTime(1970, 1, 1),
        kind: ItemKind.place,
        location: const Value('Stop 0'),
      ),
    );

    await pumpRoutine(tester, db, routineId);

    // Day two is reached by asking for it — not by knowing it is stored as the
    // day after a 1970 anchor and typing that into a calendar.
    await tester.tap(find.text('Add day'));
    await tester.pumpAndSettle();
    expect(find.text('Day 2'), findsOneWidget);

    // Plan something on it. The new day's own add-row is the second one.
    await tester.tap(find.widgetWithText(TextButton, 'Add place').last);
    await tester.pumpAndSettle();

    // The form asks which day as an ordinal, and never shows the anchor date.
    expect(find.text('Day 2'), findsWidgets);
    expect(find.textContaining('1970'), findsNothing);

    // The days on offer are the plan's, by position — day one, day two, and one
    // more to grow into. No calendar, and no 1 January 1970 anywhere.
    await tester.tap(find.byType(DropdownButtonFormField<DateTime>));
    await tester.pumpAndSettle();
    expect(find.text('Day 1'), findsWidgets);
    expect(find.text('Day 3 (new)'), findsOneWidget);
    expect(find.textContaining('1970'), findsNothing);
    expect(find.textContaining('Jan'), findsNothing);
  });

  testWidgets('the "trip created" message can be got rid of', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final routineId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'To work',
        kind: const Value(TripKind.routine),
      ),
    );
    await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: routineId,
        date: DateTime(1970, 1, 1),
        kind: ItemKind.place,
        location: const Value('Office'),
      ),
    );

    await pumpRoutine(tester, db, routineId);
    await tester.tap(find.text('Create trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create trip'));
    await tester.pumpAndSettle();

    expect(find.text('Trip created.'), findsOneWidget);

    // "Open" is an offer, not the only way out. A snackbar carrying an action
    // never times out while the platform reports accessibleNavigation, so this
    // one carries a close button — without which the message could only be got
    // rid of by taking the action or restarting the app.
    final close = find.byTooltip('Close');
    expect(close, findsOneWidget);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.text('Trip created.'), findsNothing);
  });
}
