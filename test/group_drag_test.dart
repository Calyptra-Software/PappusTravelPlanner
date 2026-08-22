import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/clock.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/checklist/application/checklist_providers.dart';
import 'package:travelplanner/features/costs/application/cost_providers.dart';
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/itinerary/widgets/timeline_tile.dart';
import 'package:travelplanner/features/trips/application/trip_providers.dart';
import 'package:travelplanner/features/trips/presentation/trip_detail_screen.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'currency_fixture.dart';
import 'support/attachment_overrides.dart';

/// Covers dragging where a **group** is involved: a run of entries sharing one
/// ticket is one block of its day, so it drags as one thing and no drag can
/// leave a leg behind in the middle of the day. Its members are still ordered
/// among themselves, in the run's own list inside the band.
///
/// The writes under test are the screen's renumbering, so the repository is a
/// real in-memory database; every stream the screen watches is a plain
/// `Stream.value` (drift's `.watch()` never resolves under fake-async), which is
/// why the assertions read the rows back instead of looking at the timeline.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late SharedPreferences prefs;
  late int tripId;

  final day = DateTime(2026, 7, 5);
  final now = DateTime(2026, 7, 5, 9);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Rome',
        startDate: Value(day),
        endDate: Value(day),
      ),
    );
  });
  tearDown(() => db.close());

  Future<int> addItem(String title, {required int sortOrder}) =>
      db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: day,
          kind: ItemKind.place,
          title: Value(title),
          sortOrder: Value(sortOrder),
        ),
      );

  /// The day as it now stands, in the order the timeline reads it.
  Future<List<ItineraryItem>> readItems() =>
      (db.select(db.itineraryItems)
            ..where((i) => i.tripId.equals(tripId))
            ..orderBy([
              (i) => OrderingTerm(expression: i.sortOrder),
              (i) => OrderingTerm(expression: i.id),
            ]))
          .get();

  Future<void> pumpDetail(WidgetTester tester) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);

    final trip = (await db.tripDao.findTrip(tripId))!;
    final items = await readItems();
    final groupRows = await (db.select(
      db.itemGroups,
    )..where((g) => g.tripId.equals(tripId))).get();
    final groups = {for (final g in groupRows) g.id: g};

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...currencyOverrides,
          repositoryProvider.overrideWithValue(repo),
          ...attachmentTestOverrides,
          sharedPreferencesProvider.overrideWithValue(prefs),
          tripProvider(tripId).overrideWith((ref) => Stream.value(trip)),
          itineraryProvider(tripId).overrideWith((ref) => Stream.value(items)),
          alternativeSetsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const {})),
          alternativeBranchesProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const {})),
          collapsedDaysProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const {})),
          groupsProvider(tripId).overrideWith((ref) => Stream.value(groups)),
          costsForTripProvider(tripId).overrideWith(
            (ref) => Stream.value((
              byItem: const <int, List<Cost>>{},
              byGroup: const <int, List<Cost>>{},
              tripLevel: const <Cost>[],
            )),
          ),
          countedCostsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const [])),
          tripParticipantsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const [])),
          checklistsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const [])),
          reasonRowsProvider.overrideWith((ref) => Stream.value(const [])),
          mePersonProvider.overrideWith((ref) => Stream.value(null)),
          transportModesProvider.overrideWith((ref) => Stream.value(const [])),
          nowProvider.overrideWith((ref) => Stream.value(now)),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripDetailScreen(tripId: tripId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drags [handle] by [dy] the way a finger does: a reorderable's handle starts
  /// the drag immediately, so no long press is needed.
  Future<void> dragBy(WidgetTester tester, Finder handle, double dy) async {
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    // In steps, so the list sees the drag cross each tile rather than teleport.
    for (var moved = 0.0; moved.abs() < dy.abs(); moved += dy / 8) {
      await gesture.moveBy(Offset(0, dy / 8));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  /// The run's own handle: the one in the band's header, above its members'.
  Finder runHandle() => find.descendant(
    of: find.byType(GroupRunTile),
    matching: find.byIcon(Icons.drag_indicator),
  );

  testWidgets('a run drags as one, taking its members with it', (tester) async {
    final leg1 = await addItem('Leg 1', sortOrder: 0);
    final leg2 = await addItem('Leg 2', sortOrder: 1);
    final museum = await addItem('Museum', sortOrder: 2);
    await db.groupDao.groupItems(leg1, leg2);

    await pumpDetail(tester);
    // The day has two slots, not three: the run is one of them.
    expect(find.byType(GroupRunTile), findsOneWidget);

    await dragBy(tester, runHandle().first, 300);

    // The museum comes first now and the run follows it, still contiguous and
    // still in its own order — a drag can move a run, never break it open.
    final items = await readItems();
    expect(items.map((i) => i.title), ['Museum', 'Leg 1', 'Leg 2']);
    expect(items.map((i) => i.sortOrder), [0, 1, 2]);
    expect(items.map((i) => i.id), [museum, leg1, leg2]);
  });

  testWidgets('a member drags within its run, which keeps its slot', (
    tester,
  ) async {
    final museum = await addItem('Museum', sortOrder: 0);
    final leg1 = await addItem('Leg 1', sortOrder: 1);
    final leg2 = await addItem('Leg 2', sortOrder: 2);
    await db.groupDao.groupItems(leg1, leg2);

    await pumpDetail(tester);
    // The run's members have handles of their own, under the run's.
    final handles = runHandle();
    expect(handles, findsNWidgets(3));

    // The first member's handle is the second in the band (after the run's).
    await dragBy(tester, handles.at(1), 120);

    final items = await readItems();
    // The legs swapped, the run stayed put: the museum still opens the day and
    // the two slots the run held are the two it still holds.
    expect(items.map((i) => i.title), ['Museum', 'Leg 2', 'Leg 1']);
    expect(items.map((i) => i.sortOrder), [0, 1, 2]);
    expect(items.map((i) => i.id), [museum, leg2, leg1]);
  });
}
