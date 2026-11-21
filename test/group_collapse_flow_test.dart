import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
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
import 'package:travelplanner/features/trips/application/trip_providers.dart';
import 'package:travelplanner/features/trips/presentation/trip_detail_screen.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'currency_fixture.dart';
import 'support/attachment_overrides.dart';

/// Folding a run from the trip screen: the label of a run on a day and of a
/// run inside an option writes the state the band is drawn from.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late SharedPreferences prefs;
  late int tripId;
  final day = DateTime(2026, 5, 1);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Karwendel',
        startDate: Value(day),
        endDate: Value(day),
      ),
    );
  });
  tearDown(() => db.close());

  /// Two legs in one group, on the day or in [alternativeId]; the group's id.
  Future<int> run({int? alternativeId}) async {
    final a = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: day,
        kind: ItemKind.transport,
        title: const Value('Gondola'),
        sortOrder: const Value(10),
        alternativeId: Value(alternativeId),
      ),
    );
    final b = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: tripId,
        date: day,
        kind: ItemKind.transport,
        title: const Value('Descent'),
        sortOrder: const Value(11),
        alternativeId: Value(alternativeId),
      ),
    );
    return db.groupDao.groupItems(a, b);
  }

  Future<bool> collapsed(int groupId) async => (await (db.select(
    db.itemGroups,
  )..where((g) => g.id.equals(groupId))).getSingle()).collapsed;

  /// Pumps the trip screen over what the database now holds.
  Future<void> pumpDetail(WidgetTester tester) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(900, 2400);
    addTearDown(tester.view.reset);
    final data = (await tester.runAsync(() async {
      return (
        trip: (await db.tripDao.findTrip(tripId))!,
        items: await repo.itemsFor(tripId),
        groups: await db.groupDao.watchGroupsForTrip(tripId).first,
        sets: await db.alternativeDao.setsForTrip(tripId),
        branches: await db.alternativeDao.branchesForTrip(tripId),
      );
    }))!;
    final router = GoRouter(
      initialLocation: '/trip/$tripId',
      routes: [
        GoRoute(
          path: '/trip/:id',
          builder: (_, state) =>
              TripDetailScreen(tripId: int.parse(state.pathParameters['id']!)),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...currencyOverrides,
          repositoryProvider.overrideWithValue(repo),
          databaseProvider.overrideWithValue(db),
          ...attachmentTestOverrides,
          sharedPreferencesProvider.overrideWithValue(prefs),
          appVersionProvider.overrideWithValue('0.0.0-test'),
          tripProvider(tripId).overrideWith((ref) => Stream.value(data.trip)),
          itineraryProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(data.items)),
          alternativeSetsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(data.sets)),
          alternativeBranchesProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(data.branches)),
          collapsedDaysProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(const {})),
          groupsProvider(
            tripId,
          ).overrideWith((ref) => Stream.value(data.groups)),
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
          nowProvider.overrideWith(
            (ref) => Stream.value(DateTime(2026, 4, 1, 9)),
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
    await tester.pumpAndSettle();
  }

  testWidgets('a run on a day folds from its label', (tester) async {
    final groupId = (await tester.runAsync(run))!;
    await pumpDetail(tester);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(ValueKey('group-label-$groupId')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    expect(await tester.runAsync(() => collapsed(groupId)), isTrue);
  });

  testWidgets('a run in an option folds from its label', (tester) async {
    final groupId = (await tester.runAsync(() async {
      final seed = await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: day,
          kind: ItemKind.place,
          title: const Value('Museum'),
        ),
      );
      final setId = await db.alternativeDao.createSetFromItem(seed);
      final option = await db.alternativeDao.addAlternative(setId);
      await db.alternativeDao.chooseAlternative(option);
      return run(alternativeId: option);
    }))!;
    await pumpDetail(tester);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(ValueKey('group-label-$groupId')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    expect(await tester.runAsync(() => collapsed(groupId)), isTrue);
  });

  testWidgets('a folded run shows its summary, not its members', (
    tester,
  ) async {
    final groupId = (await tester.runAsync(run))!;
    await tester.runAsync(() => repo.setGroupCollapsed(groupId, true));
    await pumpDetail(tester);

    expect(find.text('Gondola'), findsNothing);
    expect(find.textContaining('2 entries'), findsOneWidget);
  });
}
