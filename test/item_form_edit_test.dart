import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/stopovers.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/costs/application/cost_providers.dart';
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/itinerary/presentation/item_form_sheet.dart';
import 'package:travelplanner/features/trips/application/trip_providers.dart';
import 'package:travelplanner/features/transport_search/presentation/connection_search_sheet.dart';
import 'package:travelplanner/features/transport_search/presentation/journey_destination.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'currency_fixture.dart';
import 'support/attachment_overrides.dart';

/// Covers what an edit must *not* touch. Saving the sheet replaces the whole
/// row, so every column the form does not show has to be written back — the
/// stops an imported leg calls at and the ids its journey was searched by among
/// them. Recording that a train ran late is the ordinary reason to open this
/// sheet on an imported leg, and it used to cost the leg its stop list.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late SharedPreferences prefs;

  final day = DateTime(2026, 8, 3);

  final modes = [
    TransportModeRow(id: 1, builtinKey: 'walk', sortOrder: 0),
    TransportModeRow(id: 6, builtinKey: 'train', sortOrder: 1),
  ];

  final stops = encodeStopovers(const [
    Stopover(name: 'Tonndorf', minutes: 456),
    Stopover(name: 'Hasselbrook', minutes: 462, delayMinutes: 1),
  ]);

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

  /// An imported leg, as the connection search writes one: a source trip, the
  /// endpoint ids the search was issued against, coordinates, and its stops.
  Future<ItineraryItem> importedLeg() async {
    final id = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: 1,
        date: day,
        kind: ItemKind.transport,
        title: const Value('RB81 (11357)'),
        startMinutes: const Value(452),
        endMinutes: const Value(468),
        mode: const Value(6),
        fromLocation: const Value('Rahlstedt'),
        toLocation: const Value('Hamburg Hbf'),
        notes: const Value('Richtung Bad Oldesloe'),
        fromLat: const Value(53.60486),
        fromLon: const Value(10.154396),
        toLat: const Value(53.552734),
        toLon: const Value(10.006909),
        sourceTripId: const Value('20260803_07:13_de-DELFI_3311450311'),
        fromPlaceId: const Value('de-DELFI_de:02000:81501:1:2'),
        toPlaceId: const Value('de-DELFI_de:02000:10951:1:6'),
        stopovers: Value(stops),
      ),
    );
    return (db.select(
      db.itineraryItems,
    )..where((i) => i.id.equals(id))).getSingle();
  }

  Future<ItineraryItem> reread(int id) =>
      (db.select(db.itineraryItems)..where((i) => i.id.equals(id))).getSingle();

  Widget wrap(
    Widget sheet, {
    List<ItineraryItem> items = const [],
  }) => ProviderScope(
    overrides: [
      ...currencyOverrides,
      repositoryProvider.overrideWithValue(repo),
      ...attachmentTestOverrides,
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Every drift-backed stream the sheet touches is stubbed: the real
      // `.watch()` never resolves under fake-async, which hangs the test.
      transportModesProvider.overrideWith((ref) => Stream.value(modes)),
      itineraryProvider(1).overrideWith((ref) => Stream.value(items)),
      // The color an entry is drawn in on the map falls back to the trip's own
      // accent, so the form reads the trip — one more drift stream to stub.
      tripProvider(1).overrideWith(
        (ref) => Stream.value(
          Trip(
            id: 1,
            title: 'Trip',
            destination: '',
            colorValue: 0xFF00695C,
            photosCollapsed: false,
            createdAt: DateTime(2026),
            kind: TripKind.trip,
          ),
        ),
      ),
      // The line an entry followed is another drift stream, and the form now
      // reads one for the leg it is editing.
      itemTracksProvider.overrideWith((ref, itemId) => Stream.value(const [])),
      groupsProvider(1).overrideWith((ref) => Stream.value(const {})),
      // A routine's form draws a day *field* instead of a date picker, and
      // that reads the plan's days — another drift stream to stub out.
      alternativeSetsProvider(1).overrideWith((ref) => Stream.value(const {})),
      costsForTripProvider(1).overrideWith(
        (ref) => Stream.value((
          byItem: const <int, List<Cost>>{},
          byGroup: const <int, List<Cost>>{},
          tripLevel: const <Cost>[],
        )),
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
      home: Scaffold(body: SingleChildScrollView(child: sheet)),
    ),
  );

  Future<void> save(WidgetTester tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final button = find.widgetWithText(FilledButton, l10n.save);
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('editing an imported leg keeps its stopovers and endpoint ids', (
    tester,
  ) async {
    final leg = await importedLeg();

    await tester.pumpWidget(
      wrap(
        ItemFormSheet(tripId: 1, kind: ItemKind.transport, existing: leg),
        items: [leg],
      ),
    );
    await tester.pump();
    await save(tester);

    final saved = await reread(leg.id);
    expect(saved.stopovers, stops);
    expect(saved.fromPlaceId, leg.fromPlaceId);
    expect(saved.toPlaceId, leg.toPlaceId);
    expect(saved.sourceTripId, leg.sourceTripId);
    expect(saved.fromLat, leg.fromLat);
    expect(saved.toLon, leg.toLon);
    expect(saved.spansNextDay, leg.spansNextDay);
    // The plan and the notes the form does edit come back unchanged too.
    expect(saved.title, leg.title);
    expect(saved.startMinutes, 452);
    expect(saved.endMinutes, 468);
    expect(saved.notes, leg.notes);
  });

  testWidgets('recording the delay leaves the stops it calls at alone', (
    tester,
  ) async {
    final leg = await importedLeg();

    await tester.pumpWidget(
      wrap(
        ItemFormSheet(tripId: 1, kind: ItemKind.transport, existing: leg),
        items: [leg],
      ),
    );
    await tester.pump();

    // The second time row is the actual pair; its "Departs" field opens on the
    // planned departure, so accepting the picker's default records a time.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final departs = find.widgetWithText(InkWell, l10n.timeDeparts);
    expect(departs, findsNWidgets(2));
    await tester.ensureVisible(departs.last);
    await tester.pump();
    await tester.tap(departs.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await save(tester);

    final saved = await reread(leg.id);
    expect(saved.actualStartMinutes, isNotNull);
    expect(saved.stopovers, stops);
    expect(saved.fromPlaceId, leg.fromPlaceId);
  });

  testWidgets('a group joined while the sheet was open survives the save', (
    tester,
  ) async {
    final leg = await importedLeg();
    // The snapshot the sheet opened on is loose; live data has it grouped, and
    // its stops refreshed by a live-times refresh in the meantime.
    final refreshed = encodeStopovers(const [
      Stopover(name: 'Tonndorf', minutes: 456, delayMinutes: 4),
      Stopover(name: 'Hasselbrook', minutes: 462, cancelled: true),
    ]);
    await db
        .into(db.itemGroups)
        .insert(
          ItemGroupsCompanion.insert(tripId: 1, label: const Value('Hinfahrt')),
        );
    await db.itineraryDao.setLiveTimes(
      leg.id,
      actualStart: 466,
      actualEnd: 480,
      stopovers: refreshed,
    );
    await (db.update(db.itineraryItems)..where((i) => i.id.equals(leg.id)))
        .write(const ItineraryItemsCompanion(groupId: Value(1)));
    final now = await reread(leg.id);

    await tester.pumpWidget(
      wrap(
        ItemFormSheet(tripId: 1, kind: ItemKind.transport, existing: leg),
        items: [now],
      ),
    );
    await tester.pump();
    await save(tester);

    final saved = await reread(leg.id);
    expect(saved.groupId, 1);
    expect(saved.stopovers, refreshed);
  });
  group('replacing a leg with a searched connection', () {
    /// A leg typed in by hand: station names, no ids, nothing imported.
    Future<ItineraryItem> manualLeg({int? groupId}) async {
      final id = await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: 1,
          date: day,
          kind: ItemKind.transport,
          groupId: Value(groupId),
          startMinutes: const Value(452),
          endMinutes: const Value(468),
          mode: const Value(6),
          fromLocation: const Value('Rahlstedt'),
          toLocation: const Value('Hamburg Hbf'),
        ),
      );
      return reread(id);
    }

    Future<void> open(WidgetTester tester, ItineraryItem leg) async {
      await tester.pumpWidget(
        wrap(
          ItemFormSheet(tripId: 1, kind: ItemKind.transport, existing: leg),
          items: [leg],
        ),
      );
      await tester.pump();
    }

    testWidgets('a leg on its own offers the search', (tester) async {
      // How a hand-entered leg becomes a real connection: the search opens on
      // the names it carries, and what is taken replaces it.
      await open(tester, await manualLeg());

      expect(find.text('Search online'), findsOneWidget);
    });

    testWidgets('a leg inside a run does not', (tester) async {
      // A grouped leg is one leg of a journey, and a journey is looked up whole
      // from the sheet on its label.
      await db
          .into(db.itemGroups)
          .insert(
            ItemGroupsCompanion.insert(
              tripId: 1,
              label: const Value('Hinfahrt'),
            ),
          );
      await open(tester, await manualLeg(groupId: 1));

      expect(find.text('Search online'), findsNothing);
    });

    testWidgets('a routine\'s leg is offered it too', (tester) async {
      // A routine's leg is re-routed the way one is added to a routine: the
      // search asks a real date and lays the answer back onto the plan day.
      await open(tester, await manualLeg());
      expect(find.text('Search online'), findsOneWidget);

      await tester.pumpWidget(
        wrap(
          ItemFormSheet(
            tripId: 1,
            kind: ItemKind.transport,
            existing: await manualLeg(),
            intoRoutine: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Search online'), findsOneWidget);
    });

    testWidgets('a place is offered no timetable at all', (tester) async {
      final id = await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: 1,
          date: day,
          kind: ItemKind.place,
          title: const Value('Museum'),
        ),
      );
      final place = await reread(id);
      await tester.pumpWidget(
        wrap(
          ItemFormSheet(tripId: 1, kind: ItemKind.place, existing: place),
          items: [place],
        ),
      );
      await tester.pump();

      expect(find.text('Search online'), findsNothing);
    });
  });

  group('where the search plans what it finds', () {
    /// The add-transport form as one of the two buttons opens it: the day's, or
    /// an option's.
    Future<void> openNewLeg(WidgetTester tester, {int? alternativeId}) async {
      await tester.pumpWidget(
        wrap(
          ItemFormSheet(
            tripId: 1,
            kind: ItemKind.transport,
            day: day,
            alternativeId: alternativeId,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Search online'));
      await tester.pumpAndSettle();
    }

    int? searchSheetAlternativeId(WidgetTester tester) =>
        (tester
                    .widget<ConnectionSearchSheet>(
                      find.byType(ConnectionSearchSheet),
                    )
                    .destination
                as AddToDay)
            .alternativeId;

    testWidgets('opened from an option, into that option', (tester) async {
      // The option this form was reached from, carried through to the import —
      // a connection is not a different kind of entry from a hand-written leg,
      // so it lands where the same button plans one. Without this the run was
      // appended to the day *behind* the decision.
      await openNewLeg(tester, alternativeId: 5);

      expect(searchSheetAlternativeId(tester), 5);
    });

    testWidgets('opened from a day, onto the day', (tester) async {
      await openNewLeg(tester);

      expect(searchSheetAlternativeId(tester), isNull);
    });
  });
}
