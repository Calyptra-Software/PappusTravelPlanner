import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/costs/application/cost_providers.dart';
import 'package:travelplanner/features/costs/application/currency_providers.dart';
import 'package:travelplanner/features/trips/application/trip_connections_controller.dart';
import 'package:travelplanner/features/trips/application/trip_providers.dart';
import 'package:travelplanner/features/trips/planned_journey.dart';
import 'package:travelplanner/features/trips/presentation/trip_form_screen.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'currency_fixture.dart';

/// Saving the trip form with a new start date: the question whether the
/// entries move along, and what each answer writes.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late int tripId;
  late int entryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    final routineId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Ski template',
        kind: const Value(TripKind.routine),
      ),
    );
    tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Ski',
        startDate: Value(DateTime(2027, 3, 1)),
        endDate: Value(DateTime(2027, 3, 3)),
        fromRoutineId: Value(routineId),
      ),
    );
    entryId = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: DateTime(2027, 3, 2),
        kind: ItemKind.place,
        title: const Value('Hotel'),
      ),
    );
  });
  tearDown(() => db.close());

  /// Opens the form over a home screen, as the trip's screen does, and returns
  /// what the form closed with once it has.
  Future<({bool closed, bool? result}) Function()> open(
    WidgetTester tester, {
    List<PlannedJourney> journeys = const [],
  }) async {
    var closed = false;
    bool? result;
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await context.push<bool>('/edit');
                closed = true;
              },
              child: const Text('edit'),
            ),
          ),
        ),
        GoRoute(
          path: '/edit',
          builder: (_, _) => TripFormScreen(tripId: tripId),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          // What the form only shows, stubbed: drift streams do not resolve
          // under the test clock (docs/design/testing.md).
          tagListProvider.overrideWith((ref) => Stream.value(const [])),
          tripParticipantsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const [])),
          costsForTripProvider(tripId).overrideWith(
            (ref) => Stream.value((
              byItem: const <int, List<Cost>>{},
              byGroup: const <int, List<Cost>>{},
              tripLevel: const <Cost>[],
            )),
          ),
          currencyBookProvider.overrideWithValue(seededBook),
          tripConnectionsControllerProvider.overrideWith(
            (ref) => _Journeys(ref, journeys),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.tap(find.text('edit'));
    // The form loads its trip and tags before it draws the fields.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('Save changes'), findsOneWidget);
    return () => (closed: closed, result: result);
  }

  /// Picks [start] to [end] in the date range picker, typed into its input
  /// mode rather than tapped through months of calendar.
  Future<void> pickRange(WidgetTester tester, String start, String end) async {
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.byIcon(Icons.date_range),
          matching: find.byType(InputDecorator),
        ),
        // Not the clear button's: the one holding the range as text.
        matching: find.byWidgetPredicate(
          (w) => w is InkWell && w.child is Text,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    // The picker's own two fields, not the form's beneath it.
    final fields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), start);
    await tester.enterText(fields.at(1), end);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  /// The one entry as stored. Read with `get`, inside `runAsync`: a drift
  /// `watch` never resolves under the test clock.
  Future<ItineraryItem> entryRow(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.itineraryItems).getSingle()))!;

  Future<void> settleWrites(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets('a new start moves the entries when asked to', (tester) async {
    final closed = await open(tester, journeys: [_journey()]);
    await pickRange(tester, '03/05/2027', '03/07/2027');
    await save(tester);

    expect(find.text('Move the entries too?'), findsOneWidget);
    expect(find.text('Every entry moves 4 days later.'), findsOneWidget);
    await tester.tap(find.text('Move entries'));
    await settleWrites(tester);

    final trip = await repo.findTrip(tripId);
    expect(trip!.startDate, DateTime(2027, 3, 5));
    expect(trip.endDate, DateTime(2027, 3, 7));
    final entry = await entryRow(tester);
    expect(entry.id, entryId);
    expect(entry.date, DateTime(2027, 3, 6));
    // Closed with the request to look the journeys up, for the screen beneath.
    expect(closed(), (closed: true, result: true));
  });

  testWidgets('dates only leaves the entries where they are', (tester) async {
    final closed = await open(tester);
    await pickRange(tester, '03/05/2027', '03/07/2027');
    await save(tester);

    // No journey to look up: no switch for it.
    expect(find.byType(Checkbox), findsNothing);
    await tester.tap(find.text('Dates only'));
    await settleWrites(tester);

    final trip = await repo.findTrip(tripId);
    expect(trip!.startDate, DateTime(2027, 3, 5));
    final entry = await entryRow(tester);
    expect(entry.date, DateTime(2027, 3, 2));
    expect(closed(), (closed: true, result: false));
  });

  testWidgets('cancel keeps the form open and writes nothing', (tester) async {
    final closed = await open(tester);
    await pickRange(tester, '03/05/2027', '03/07/2027');
    await save(tester);
    await tester.tap(find.text('Cancel'));
    await settleWrites(tester);

    expect(find.text('Save changes'), findsOneWidget);
    expect((await repo.findTrip(tripId))!.startDate, DateTime(2027, 3, 1));
    expect((closed()).closed, isFalse);
  });

  testWidgets('a new end alone asks nothing', (tester) async {
    final closed = await open(tester);
    await pickRange(tester, '03/01/2027', '03/09/2027');
    await save(tester);

    expect(find.text('Move the entries too?'), findsNothing);
    expect((await repo.findTrip(tripId))!.endDate, DateTime(2027, 3, 9));
    expect(closed(), (closed: true, result: false));
  });

  testWidgets('editing keeps the routine the trip was made from', (
    tester,
  ) async {
    // Regression: the form wrote a fresh row and dropped `fromRoutineId`.
    final before = (await repo.findTrip(tripId))!.fromRoutineId;
    expect(before, isNotNull);

    final closed = await open(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Ski'), 'Skiing');
    await save(tester);

    final trip = await repo.findTrip(tripId);
    expect(trip!.title, 'Skiing');
    expect(trip.fromRoutineId, before);
    expect(closed(), (closed: true, result: false));
  });
}

PlannedJourney _journey() => PlannedJourney(
  groupId: null,
  legs: [
    ItineraryItem(
      id: 99,
      tripId: 1,
      date: DateTime(2027, 3, 1),
      sortOrder: 0,
      kind: ItemKind.transport,
      endDayOffset: 0,
      chordDisplay: TrackDisplay.auto,
      startMinutes: 480,
      fromPlaceId: 'stop:a',
      toPlaceId: 'stop:b',
    ),
  ],
);

/// Answers the form's question "are there journeys to look up" without the
/// database, which a widget test cannot watch.
class _Journeys extends TripConnectionsController {
  _Journeys(super.ref, this.journeys);

  final List<PlannedJourney> journeys;

  @override
  Future<List<PlannedJourney>> lookUpCandidates(int tripId) async => journeys;
}
