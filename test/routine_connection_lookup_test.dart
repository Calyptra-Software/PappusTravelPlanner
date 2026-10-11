import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/transport_search/application/transport_search.dart';
import 'package:travelplanner/features/transport_search/application/transport_search_controller.dart'
    show JourneyImportLabels;
import 'package:travelplanner/features/transport_search/application/transport_search_providers.dart'
    show transportSearchProvider;
import 'package:travelplanner/features/transport_search/data/motis_client.dart'
    show TransportSearchException;
import 'package:travelplanner/features/transport_search/domain/journey.dart';
import 'package:travelplanner/features/transport_search/domain/journey_options.dart';
import 'package:travelplanner/features/transport_search/domain/transit_mode.dart';
import 'package:travelplanner/features/transport_search/domain/transport_place.dart';
import 'package:travelplanner/features/transport_search/domain/via_stop.dart';
import 'package:travelplanner/features/transport_search/presentation/connection_search_sheet.dart';
import 'package:travelplanner/features/trips/application/routine_controller.dart';
import 'package:travelplanner/features/trips/planned_journey.dart';
import 'package:travelplanner/features/trips/presentation/create_trip_from_routine.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// The round of offers made after a trip is stamped out of a routine.
///
/// Each journey used to get exactly two answers — the first connection found,
/// or the copied plan — and a journey for which nothing was found was only
/// counted, into a snack bar at the end naming none of them. Both now lead to
/// the ordinary search form for that run, where the question can be asked
/// slightly differently: another train, a later hour.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  late AppDatabase db;
  late TripRepository repo;
  late SharedPreferences prefs;
  late _FakeRoutineController controller;

  final day = DateTime(2026, 8, 3);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Büro',
        startDate: Value(day),
        endDate: Value(day),
      ),
    );
  });
  tearDown(() => db.close());

  /// Two copied runs, each a single addressable leg: out in the morning, back
  /// in the evening.
  Future<List<PlannedJourney>> plan() async {
    Future<void> leg(String from, String to, int start) =>
        db.itineraryDao.addItem(
          ItineraryItemsCompanion.insert(
            tripId: 1,
            date: day,
            kind: ItemKind.transport,
            title: const Value('RB81'),
            startMinutes: Value(start),
            endMinutes: Value(start + 20),
            fromLocation: Value(from),
            toLocation: Value(to),
            fromPlaceId: Value('id:$from'),
            toPlaceId: Value('id:$to'),
          ),
        );
    await leg('Rahlstedt', 'Hamburg Hbf', 452);
    await leg('Hamburg Hbf', 'Rahlstedt', 1050);
    final items = await (db.select(
      db.itineraryItems,
    )..orderBy([(i) => OrderingTerm(expression: i.id)])).get();
    return [
      for (final item in items) PlannedJourney(groupId: null, legs: [item]),
    ];
  }

  Future<void> start(
    WidgetTester tester,
    List<PlannedJourney> journeys,
    List<Object> answers,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
          transportSearchProvider.overrideWithValue(_NoSearch()),
          routineControllerProvider.overrideWith((ref) {
            return controller = _FakeRoutineController(ref, journeys, answers);
          }),
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
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => lookUpRoutineConnections(context, ref, 1),
                child: const Text('look up'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('look up'));
    await tester.pumpAndSettle();
  }

  testWidgets('says at the journey itself that nothing was found', (
    tester,
  ) async {
    final journeys = await plan();
    await start(tester, journeys, [[], []]);

    expect(find.text('No connection found'), findsOneWidget);
    expect(
      find.textContaining('Rahlstedt → Hamburg Hbf on August 3, 2026, 7:32 AM'),
      findsOneWidget,
    );

    // Keeping the plan moves on to the next journey, which is asked about too.
    await tester.tap(find.text('Keep the plan'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Hamburg Hbf → Rahlstedt on August 3, 2026, 5:30 PM'),
      findsOneWidget,
    );
    await tester.tap(find.text('Keep the plan'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(controller.used, isEmpty);
  });

  testWidgets('nothing found leads into the search form for that run', (
    tester,
  ) async {
    final journeys = await plan();
    await start(tester, journeys, [[], []]);

    await tester.tap(find.text('Adjust search…'));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionSearchSheet), findsOneWidget);
    expect(find.text('Rahlstedt'), findsWidgets);

    // Closing the form leaves the plan and asks about the next journey.
    Navigator.of(tester.element(find.byType(ConnectionSearchSheet))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionSearchSheet), findsNothing);
    expect(
      find.textContaining('Hamburg Hbf → Rahlstedt on August 3, 2026'),
      findsOneWidget,
    );
  });

  testWidgets('an offer can be taken, kept, or searched again', (tester) async {
    final journeys = await plan();
    await start(tester, journeys, [
      [_option(7, 40)],
      [_option(17, 35)],
    ]);

    // First journey: the search is adjusted rather than the offer answered.
    expect(find.text('Adjust search…'), findsOneWidget);
    await tester.tap(find.text('Adjust search…'));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionSearchSheet), findsOneWidget);
    Navigator.of(tester.element(find.byType(ConnectionSearchSheet))).pop();
    await tester.pumpAndSettle();
    expect(controller.used, isEmpty);

    // Second journey: taken as offered.
    await tester.tap(find.text('Use this'));
    await tester.pumpAndSettle();
    expect(controller.used, [journeys[1].legIds]);
  });

  group('a failed lookup says what it was', () {
    const offline = TransportSearchException('Connection search timed out');
    const noTimetable = TransportSearchException(
      'MOTIS request failed (400)',
      statusCode: 400,
      serverMessage:
          'query time 2026-08-03 05:32 is outside of loaded timetable window '
          '[2026-09-09 00:00, 2027-10-10 00:00[',
    );
    const unknownStop = TransportSearchException(
      'MOTIS request failed (404)',
      statusCode: 404,
      serverMessage: 'Could not find timetable location "id:Rahlstedt"',
    );
    const overloaded = TransportSearchException(
      'MOTIS request failed (503)',
      statusCode: 503,
    );

    testWidgets('no answer at all is "unreachable" and ends the round', (
      tester,
    ) async {
      final journeys = await plan();
      await start(tester, journeys, [offline, <JourneyOption>[]]);

      expect(
        find.text(
          "Couldn't reach the routing service. "
          'The plan was copied as it stands.',
        ),
        findsOneWidget,
      );
      expect(controller.asked, 1);
    });

    testWidgets('a date without a timetable says so, not "unreachable"', (
      tester,
    ) async {
      final journeys = await plan();
      await start(tester, journeys, [noTimetable, noTimetable]);

      expect(
        find.text(
          'The routing service has no timetable for this date. '
          'The plan was copied as it stands.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining("Couldn't reach"), findsNothing);
      // Both journeys sit on that day: the second is not asked about again.
      expect(controller.asked, 1);
    });

    testWidgets('an unknown stop is said at its journey, and the round goes '
        'on', (tester) async {
      final journeys = await plan();
      await start(tester, journeys, [
        unknownStop,
        [_option(17, 35)],
      ]);

      expect(find.text('Place not found'), findsOneWidget);
      expect(find.textContaining('Rahlstedt → Hamburg Hbf'), findsOneWidget);
      await tester.tap(find.text('Keep the plan'));
      await tester.pumpAndSettle();

      // The evening journey is offered as usual.
      expect(find.text('Use this'), findsOneWidget);
      expect(controller.asked, 2);
    });

    testWidgets('any other refusal is an error, and ends the round', (
      tester,
    ) async {
      final journeys = await plan();
      await start(tester, journeys, [overloaded, <JourneyOption>[]]);

      expect(
        find.text(
          'The routing service answered with an error. '
          'The plan was copied as it stands.',
        ),
        findsOneWidget,
      );
      expect(controller.asked, 1);
    });
  });
}

JourneyOption _option(int hour, int minute) {
  final from = DateTime.utc(2026, 8, 3, hour - 2, minute);
  final to = from.add(const Duration(minutes: 20));
  final leg = JourneyLeg(
    mode: TransitMode.regionalRail,
    line: 'RB81',
    realTime: false,
    from: LegPoint(name: 'A', scheduled: from, timeZone: 'Europe/Berlin'),
    to: LegPoint(name: 'B', scheduled: to, timeZone: 'Europe/Berlin'),
  );
  return JourneyOption(
    departure: from,
    arrival: to,
    duration: to.difference(from),
    transfers: 0,
    legs: [leg],
  );
}

/// Hands out canned answers in order and records which runs were replaced,
/// leaving the database alone: what is under test is the round of questions,
/// not the swap, which `journey_lookup_test.dart` covers.
class _FakeRoutineController extends RoutineController {
  _FakeRoutineController(super.ref, this.journeys, this.answers);

  final List<PlannedJourney> journeys;

  /// One per lookup, in order: the options found, or an exception to throw.
  final List<Object> answers;
  final used = <List<int>>[];
  var _asked = 0;
  int get asked => _asked;

  @override
  Future<List<PlannedJourney>> lookUpCandidates(int tripId) async => journeys;

  @override
  Future<List<JourneyOption>> lookUp(PlannedJourney journey) async {
    final answer = answers[_asked++];
    if (answer is Exception) throw answer;
    return (answer as List).cast<JourneyOption>();
  }

  @override
  Future<void> useConnection(
    int tripId,
    PlannedJourney journey,
    JourneyOption option, {
    required JourneyImportLabels labels,
  }) async {
    used.add(journey.legIds);
  }
}

/// The search form opened here is only looked at, never searched from.
class _NoSearch implements TransportSearch {
  @override
  Future<JourneyResults> journeys({
    required String fromId,
    required String toId,
    required DateTime time,
    bool arriveBy = false,
    JourneySearchOptions options = const JourneySearchOptions(),
    ViaStops via = ViaStops.none,
    String? pageCursor,
  }) async => const JourneyResults(options: []);

  @override
  Future<List<TransportPlace>> searchPlaces(String query) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
