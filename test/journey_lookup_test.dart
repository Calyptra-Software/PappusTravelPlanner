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
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/transport_search/application/transport_search.dart';
import 'package:travelplanner/features/transport_search/application/transport_search_providers.dart'
    show geocodeProvider, transportSearchProvider;
import 'package:travelplanner/features/transport_search/data/motis_client.dart'
    show TransportSearchException;
import 'package:travelplanner/features/transport_search/domain/journey.dart';
import 'package:travelplanner/features/transport_search/domain/journey_options.dart';
import 'package:travelplanner/features/transport_search/domain/via_stop.dart';
import 'package:travelplanner/features/transport_search/domain/transit_mode.dart';
import 'package:travelplanner/features/transport_search/domain/transport_place.dart';
import 'package:travelplanner/features/transport_search/presentation/connection_search_sheet.dart';
import 'package:travelplanner/features/transport_search/presentation/journey_details_sheet.dart';
import 'package:travelplanner/features/trips/application/trip_providers.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Looking a journey up **again**, from the sheet that reads it.
///
/// The lookup used to exist only inside `createTripFromRoutine`, so a trip
/// stamped out of a routine with the switch off — or with no signal on the
/// platform — kept a copied plan for good: no `sourceTripId`, and so no live
/// times, with no way back short of deleting the trip. The way back is here,
/// per journey, because that is the unit the question arises in.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  late AppDatabase db;
  late TripRepository repo;
  late SharedPreferences prefs;
  late _FakeSearch search;
  late List<TransportPlace> suggestions;

  final day = DateTime(2026, 8, 3);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    search = _FakeSearch();
    suggestions = const [
      TransportPlace(
        id: 'stop:picked',
        name: 'Rahlstedt',
        kind: PlaceKind.stop,
        area: 'Hamburg',
      ),
    ];
    await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Büro',
        startDate: Value(day),
        endDate: Value(day),
      ),
    );
    await db
        .into(db.itemGroups)
        .insert(
          ItemGroupsCompanion.insert(tripId: 1, label: const Value('Hinfahrt')),
        );
  });
  tearDown(() => db.close());

  /// The copied plan a routine leaves behind: real endpoints the search can be
  /// re-issued against, but no `sourceTripId` — nothing to refresh.
  Future<List<ItineraryItem>> plan({
    bool addressable = true,
    int? groupId = 1,
  }) async {
    await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: 1,
        date: day,
        kind: ItemKind.transport,
        groupId: Value(groupId),
        title: const Value('RB81'),
        startMinutes: const Value(452),
        endMinutes: const Value(468),
        fromLocation: const Value('Rahlstedt'),
        toLocation: const Value('Hamburg Hbf'),
        stopovers: const Value('[{"name":"Tonndorf","minutes":456}]'),
        fromPlaceId: addressable
            ? const Value('de-DELFI_rahlstedt')
            : const Value.absent(),
        // An import gives every leg its ends' coordinates, inner ones included —
        // which is what lets a middle leg be searched on its own.
        fromLat: addressable ? const Value(53.60486) : const Value.absent(),
        fromLon: addressable ? const Value(10.154396) : const Value.absent(),
        toLat: addressable ? const Value(53.552734) : const Value.absent(),
        toLon: addressable ? const Value(10.006909) : const Value.absent(),
      ),
    );
    await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: 1,
        date: day,
        kind: ItemKind.transport,
        groupId: Value(groupId),
        title: const Value('U2'),
        startMinutes: const Value(488),
        endMinutes: const Value(495),
        fromLocation: const Value('Hauptbahnhof Nord'),
        toLocation: const Value('Schlump'),
        toPlaceId: addressable
            ? const Value('de-DELFI_schlump')
            : const Value.absent(),
        fromLat: addressable ? const Value(53.554108) : const Value.absent(),
        fromLon: addressable ? const Value(10.005139) : const Value.absent(),
        toLat: addressable ? const Value(53.56785) : const Value.absent(),
        toLon: addressable ? const Value(9.969647) : const Value.absent(),
      ),
    );
    return (db.select(
      db.itineraryItems,
    )..orderBy([(i) => OrderingTerm(expression: i.sortOrder)])).get();
  }

  Future<void> pump(
    WidgetTester tester,
    List<ItineraryItem> items, {
    TripKind kind = TripKind.trip,
  }) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final trip = await (db.select(
      db.trips,
    )..where((t) => t.id.equals(1))).getSingle();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          sharedPreferencesProvider.overrideWithValue(prefs),
          transportSearchProvider.overrideWithValue(search),
          geocodeProvider.overrideWith((ref, query) async => suggestions),
          // Drift's `.watch()` never resolves under fake-async, so what the
          // sheet reads arrives as a plain stream; what it *writes* goes to the
          // real database, which is what the assertions read back.
          itineraryProvider(1).overrideWith((ref) => Stream.value(items)),
          tripProvider(
            1,
          ).overrideWith((ref) => Stream.value(trip.copyWith(kind: kind))),
          transportModesByIdProvider.overrideWith((ref) => const {}),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: JourneyDetailsSheet(tripId: 1, groupId: 1, title: 'Hinfahrt'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Scoped to the search form: the journey behind it names the same stops and
  /// the same times, so an unscoped finder would match either.
  Finder inForm(Finder matching) => find.descendant(
    of: find.byType(ConnectionSearchSheet),
    matching: matching,
  );

  Finder findButton() => find.widgetWithText(OutlinedButton, 'Find connection');

  Future<List<ItineraryItem>> legs() =>
      (db.select(db.itineraryItems)..where((i) => i.tripId.equals(1))).get();

  testWidgets('a copied plan offers to be looked up again', (tester) async {
    await pump(tester, await plan());

    expect(findButton(), findsOneWidget);
  });

  testWidgets('a hand-entered run is offered the search too', (tester) async {
    await pump(tester, await plan(addressable: false));

    // It has no ids and no coordinates, so nothing can be *searched* for it
    // unattended — but with the user here, naming the station is a question the
    // form can ask.
    expect(findButton(), findsOneWidget);
  });

  testWidgets('a hand-entered run opens the form on its station names', (
    tester,
  ) async {
    await pump(tester, await plan(addressable: false));
    await tester.tap(findButton());
    await tester.pumpAndSettle();

    // The names the legs carry, shown as hints under the empty fields — the app
    // has not turned either into an address behind the user's back.
    expect(inForm(find.text('Rahlstedt')), findsOneWidget);
    expect(inForm(find.text('Schlump')), findsOneWidget);
    expect(inForm(find.text('From')), findsOneWidget);
    expect(inForm(find.text('To')), findsOneWidget);
    // And nothing is searchable until they are named.
    final searchButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Search'),
    );
    expect(searchButton.onPressed, isNull);
  });

  testWidgets('naming both ends makes a hand-entered run searchable', (
    tester,
  ) async {
    await pump(tester, await plan(addressable: false));
    await tester.tap(findButton());
    await tester.pumpAndSettle();

    // The picker opens already searching for what the leg called the stop, so
    // the station is one tap away rather than typed again.
    await tester.tap(inForm(find.text('From')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Rahlstedt'), findsOneWidget);
    await tester.tap(find.text('Rahlstedt').last);
    await tester.pumpAndSettle();
    await tester.tap(inForm(find.text('To')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rahlstedt').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(search.lastFrom, 'stop:picked');

    await tester.tap(inForm(find.textContaining('RB81')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Use this'));
    await tester.pumpAndSettle();

    final after = await legs();
    expect(after, hasLength(1));
    expect(after.single.sourceTripId, 'run-1');
    // The ids **this** search used, not the run's (which had none at all).
    expect(after.single.fromPlaceId, 'stop:picked');
    expect(after.single.toPlaceId, 'stop:picked');
  });

  group('a routine', () {
    testWidgets('is looked up on a real date, not on its own anchor', (
      tester,
    ) async {
      await pump(tester, await plan(), kind: TripKind.routine);

      // A template is as worth re-routing as an outing: a retired 07:32 changes
      // every morning from now on.
      expect(findButton(), findsOneWidget);

      await tester.tap(findButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      // Today, because no timetable answers for a day of a plan — while the time
      // still comes from the run: the commute leaves at 07:32 whichever day it is
      // asked about.
      final asked = search.lastTime!;
      expect(DateUtils.dateOnly(asked), DateUtils.dateOnly(DateTime.now()));
      expect((asked.hour, asked.minute), (7, 32));
    });

    testWidgets('lays what it finds back onto the plan day', (tester) async {
      await pump(tester, await plan(), kind: TripKind.routine);

      await tester.tap(findButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      await tester.tap(inForm(find.textContaining('RB81')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Use this'));
      await tester.pumpAndSettle();

      final after = await legs();
      expect(after, hasLength(1));
      // Back on the plan's own day, whatever date it was searched on.
      expect(after.single.date, day);
      // And carrying nothing that belongs to that one dated run: a template must
      // not look refreshable.
      expect(after.single.sourceTripId, isNull);
      expect(after.single.actualStartMinutes, isNull);
      expect(after.single.actualEndMinutes, isNull);
      // The shape does travel — the ends it was searched by, and its stops.
      expect(after.single.fromPlaceId, 'de-DELFI_rahlstedt');
      expect(after.single.stopovers, isNotNull);
    });
  });

  group('one leg of a run', () {
    /// The search button on a leg card, keyed by the leg's own row. There is one
    /// per leg, plus the journey's own at the foot of the sheet.
    Finder legButtons() => find.descendant(
      of: find.byType(Card),
      matching: find.byIcon(Icons.travel_explore),
    );

    testWidgets('every leg of a run carries its own search', (tester) async {
      await pump(tester, await plan());

      expect(legButtons(), findsNWidgets(2));
    });

    testWidgets('a run of one leg does not: its journey is the leg', (
      tester,
    ) async {
      final items = await plan();
      await pump(tester, [items.first]);

      expect(findButton(), findsOneWidget);
      expect(legButtons(), findsNothing);
    });

    testWidgets('searching one leg leaves the rest of the run alone', (
      tester,
    ) async {
      final items = await plan();
      await pump(tester, items);

      // The second leg — the connection after the change.
      await tester.tap(legButtons().last);
      await tester.pumpAndSettle();

      // Opened on that leg's own ends and its own departure (08:08), not the
      // journey's.
      expect(inForm(find.text('Hauptbahnhof Nord')), findsOneWidget);
      expect(inForm(find.text('8:08 AM')), findsOneWidget);

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      // The inner end has no id of its own — ids live on a run's outer legs —
      // so it goes out as the coordinates the leg carries.
      expect(search.lastFrom, '53.554108,10.005139');
      expect(search.lastTo, 'de-DELFI_schlump');

      await tester.tap(inForm(find.textContaining('RB81')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Use this'));
      await tester.pumpAndSettle();

      final after = await legs();
      // Two legs still: the first one untouched, the second one replaced.
      expect(after, hasLength(2));
      final kept = after.firstWhere((l) => l.id == items.first.id);
      expect(kept.title, 'RB81', reason: 'the leg already travelled is intact');
      expect(kept.sourceTripId, isNull);
      final swapped = after.firstWhere((l) => l.id != items.first.id);
      expect(swapped.sourceTripId, 'run-1');
      expect(swapped.groupId, 1, reason: 'still one journey, one ticket');
      expect(swapped.sortOrder, items.last.sortOrder, reason: 'same slot');
    });

    testWidgets('a delay recorded on the leg before seeds the departure', (
      tester,
    ) async {
      final items = await plan();
      // The RB81 came in at 08:04 instead of 07:48: the 08:08 was missed, and
      // the question is what runs from here now.
      await db.itineraryDao.setLiveTimes(
        items.first.id,
        actualStart: 466,
        actualEnd: 484,
        stopovers: null,
      );
      final current = await legs();
      await pump(tester, current);

      await tester.tap(legButtons().last);
      await tester.pumpAndSettle();

      // 08:04, where the traveller really is — not the 08:08 the plan hoped for.
      expect(inForm(find.text('8:04 AM')), findsOneWidget);
      expect(inForm(find.text('8:08 AM')), findsNothing);
    });
  });

  /// Opens the search for this run and runs it, which is now two taps: the
  /// button opens the form (pre-filled), the form asks the timetable.
  Future<void> openAndSearch(WidgetTester tester) async {
    await tester.tap(findButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
  }

  testWidgets('the form opens on the run it was opened from', (tester) async {
    await pump(tester, await plan());
    await tester.tap(findButton());
    await tester.pumpAndSettle();

    // The ends the run was searched by, named as the trip has them, and the
    // minute it was planned to leave — all still editable.
    expect(find.text('Search connection'), findsOneWidget);
    expect(inForm(find.text('Rahlstedt')), findsOneWidget);
    expect(inForm(find.text('Schlump')), findsOneWidget);
    expect(inForm(find.text('7:32 AM')), findsOneWidget);
    // Nothing has been asked yet: a query is a button, never an arrival. (The
    // journey behind the form is titled RB81 too, so the router is the witness.)
    expect(search.lastTime, isNull);
  });

  testWidgets('taking the connection swaps the legs and keeps the group', (
    tester,
  ) async {
    final items = await plan();
    await pump(tester, items);
    await openAndSearch(tester);

    // Searched by the ends the run was searched by, on its own day, around its
    // planned departure (07:32 local).
    expect(search.lastFrom, 'de-DELFI_rahlstedt');
    expect(search.lastTo, 'de-DELFI_schlump');
    expect(search.lastTime, DateTime(2026, 8, 3, 7, 32));

    // A result only opens; the preview's button is what spends.
    await tester.tap(inForm(find.textContaining('RB81')).first);
    await tester.pumpAndSettle();
    expect(await legs(), hasLength(2));

    await tester.tap(find.widgetWithText(FilledButton, 'Use this'));
    await tester.pumpAndSettle();

    final after = await legs();
    expect(after, hasLength(1), reason: 'the copied run was replaced');
    expect(after.single.sourceTripId, 'run-1', reason: 'now refreshable');
    expect(after.single.groupId, 1, reason: 'the shared ticket survives');
    expect(after.single.stopovers, isNotNull, reason: 'the stops came with it');
    expect(
      items.map((i) => i.id),
      isNot(contains(after.single.id)),
      reason: 'these are the searched legs, not the copied ones',
    );
    // Adding a second run beside the first is what this must never do.
    expect(find.text('Connection added'), findsNothing);
  });

  testWidgets('the query is the form\'s, not the run\'s', (tester) async {
    await pump(tester, await plan());
    await tester.tap(findButton());
    await tester.pumpAndSettle();

    // The run seeded the form; what is asked is whatever the form now says —
    // here, arrive by that time rather than depart at it.
    await tester.tap(inForm(find.text('Arrive by')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(search.lastArriveBy, isTrue);
    expect(search.lastTime, DateTime(2026, 8, 3, 7, 32));
    expect(inForm(find.textContaining('RB81')), findsWidgets);
  });

  testWidgets('keeping the plan leaves the run exactly as it was', (
    tester,
  ) async {
    await pump(tester, await plan());
    await openAndSearch(tester);

    await tester.tap(inForm(find.textContaining('RB81')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Keep the plan'));
    await tester.pumpAndSettle();

    expect(await legs(), hasLength(2));
    expect((await legs()).every((l) => l.sourceTripId == null), isTrue);
  });

  testWidgets('nothing running says so, and changes nothing', (tester) async {
    search.findsNothing = true;
    await pump(tester, await plan());
    await openAndSearch(tester);

    expect(find.text('No connections found'), findsOneWidget);
    expect(await legs(), hasLength(2));
  });

  testWidgets('a service out of reach is not reported as nothing running', (
    tester,
  ) async {
    search.fails = true;
    await pump(tester, await plan());
    await openAndSearch(tester);

    expect(find.text("Couldn't reach the connection service"), findsOneWidget);
    expect(find.text('No connections found'), findsNothing);
    expect(await legs(), hasLength(2));
  });
}

/// A router that answers with one RB81, 08:00 – 08:20 Berlin time on the day it
/// was asked about — the date matters, since a routine's re-route is measured by
/// how far the answer has to move back onto the plan.
class _FakeSearch implements TransportSearch {
  bool findsNothing = false;
  bool fails = false;
  bool? lastArriveBy;
  String? lastFrom;
  String? lastTo;
  DateTime? lastTime;

  @override
  Future<JourneyResults> journeys({
    required String fromId,
    required String toId,
    required DateTime time,
    bool arriveBy = false,
    JourneySearchOptions options = const JourneySearchOptions(),
    ViaStops via = ViaStops.none,
    String? pageCursor,
  }) async {
    lastFrom = fromId;
    lastTo = toId;
    lastTime = time;
    lastArriveBy = arriveBy;
    if (fails) throw const TransportSearchException('offline');
    if (findsNothing) return const JourneyResults(options: []);
    final asked = DateTime.utc(time.year, time.month, time.day);
    final leg = JourneyLeg(
      mode: TransitMode.regionalRail,
      line: 'RB81',
      tripId: 'run-1',
      realTime: false,
      from: LegPoint(
        name: 'Rahlstedt',
        scheduled: asked.add(const Duration(hours: 6)),
        timeZone: 'Europe/Berlin',
      ),
      to: LegPoint(
        name: 'Schlump',
        scheduled: asked.add(const Duration(hours: 6, minutes: 20)),
        timeZone: 'Europe/Berlin',
      ),
      stops: [
        LegStop(
          name: 'Tonndorf',
          scheduledDeparture: asked.add(const Duration(hours: 6, minutes: 6)),
          timeZone: 'Europe/Berlin',
        ),
      ],
    );
    return JourneyResults(
      options: [
        JourneyOption(
          departure: leg.from.scheduled,
          arrival: leg.to.scheduled,
          duration: const Duration(minutes: 20),
          transfers: 0,
          legs: [leg],
        ),
      ],
    );
  }

  @override
  Future<List<TransportPlace>> searchPlaces(String query) async => const [];

  @override
  Future<List<TripStop>> tripStops(String tripId) => throw UnimplementedError();
}
