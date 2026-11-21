import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/costs/application/cost_providers.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/itinerary/widgets/now_line.dart';
import 'package:travelplanner/features/itinerary/widgets/timeline_tile.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'currency_fixture.dart';
import 'support/attachment_overrides.dart';

/// A run of entries folds away under its label, the way a day does, and the
/// state travels with the run.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late int tripId;
  late SharedPreferences prefs;
  final day = DateTime(2026, 3, 14);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Ski day',
        startDate: Value(day),
        endDate: Value(day),
      ),
    );
  });
  tearDown(() => db.close());

  ItineraryItem leg(
    int id, {
    String? to,
    int? start,
    int? end,
    int endDayOffset = 0,
  }) => ItineraryItem(
    id: id,
    tripId: 1,
    date: day,
    sortOrder: id,
    kind: ItemKind.transport,
    groupId: 9,
    toLocation: to,
    startMinutes: start,
    endMinutes: end,
    endDayOffset: endDayOffset,
    chordDisplay: TrackDisplay.auto,
  );

  Cost ticket() => Cost(
    id: 1,
    groupId: 9,
    amountMinor: 4900,
    currency: 1,
    reason: 'Ski pass',
    isTransfer: false,
    isReimbursement: false,
    paid: true,
    createdAt: DateTime(2026),
  );

  Future<void> pumpRun(
    WidgetTester tester, {
    required bool collapsed,
    VoidCallback? onToggle,
    bool isNow = false,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...currencyOverrides,
        sharedPreferencesProvider.overrideWithValue(prefs),
        repositoryProvider.overrideWithValue(repo),
        transportModesProvider.overrideWith((ref) => Stream.value(const [])),
        // The ticket's chip reads the reasons' icons, a database stream.
        reasonRowsProvider.overrideWith((ref) => Stream.value(const [])),
        ...attachmentTestOverrides,
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
          body: SizedBox(
            width: 500,
            child: GroupRunTile(
              groupId: 9,
              label: 'Ski day',
              items: [
                leg(1, to: 'Valley station', start: 480, end: 495),
                leg(2, to: 'Summit', start: 500, end: 520),
                leg(3, to: 'Village', start: 1400, end: 30, endDayOffset: 1),
              ],
              accent: Colors.teal,
              costsByItem: const {},
              groupCosts: [ticket()],
              localeName: 'en',
              onTapItem: (_) {},
              onTapCost: (_) {},
              onReorder: (_, _, _) {},
              held: null,
              isNow: isNow,
              collapsed: collapsed,
              onToggleCollapsed: onToggle,
            ),
          ),
        ),
      ),
    ),
  );

  group('the band', () {
    testWidgets('open, it lists its members and no summary', (tester) async {
      await pumpRun(tester, collapsed: false, onToggle: () {});
      await tester.pumpAndSettle();

      expect(find.textContaining('Summit'), findsOneWidget);
      expect(find.textContaining('3 entries'), findsNothing);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
    });

    testWidgets('folded, it says how many and when, and keeps its ticket', (
      tester,
    ) async {
      await pumpRun(tester, collapsed: true, onToggle: () {});
      await tester.pumpAndSettle();

      expect(find.textContaining('Summit'), findsNothing);
      expect(find.text('3 entries · 08:00 – 00:30 +1'), findsOneWidget);
      expect(find.textContaining('Ski pass'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('folded and under way, it still says so', (tester) async {
      await pumpRun(tester, collapsed: true, onToggle: () {}, isNow: true);
      await tester.pumpAndSettle();

      expect(find.byType(NowBadge), findsOneWidget);
    });

    testWidgets('a tap on the label folds it', (tester) async {
      var toggled = 0;
      await pumpRun(tester, collapsed: false, onToggle: () => toggled++);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ski day'));
      expect(toggled, 1);
    });

    testWidgets('without a way to fold, the label offers none', (tester) async {
      await pumpRun(tester, collapsed: false);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_less), findsNothing);
    });
  });

  group('the folded state travels with the run', () {
    Future<int> foldedRun({int? alternativeId}) async {
      final a = await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: day,
          kind: ItemKind.transport,
          sortOrder: const Value(0),
          alternativeId: Value(alternativeId),
        ),
      );
      final b = await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: day,
          kind: ItemKind.transport,
          sortOrder: const Value(1),
          alternativeId: Value(alternativeId),
        ),
      );
      final groupId = await db.groupDao.groupItems(a, b);
      await repo.setGroupCollapsed(groupId, true);
      return groupId;
    }

    Future<List<ItemGroup>> groups() => db.select(db.itemGroups).get();

    test('into a copy of the run', () async {
      final groupId = await foldedRun();

      await db.groupDao.copyGroup(groupId, day: day);

      expect((await groups()).map((g) => g.collapsed), [true, true]);
    });

    test('into a copy of the trip', () async {
      await foldedRun();

      final copyId = await db.tripPlanDao.duplicateTrip(
        tripId,
        title: 'Again',
        startDate: DateTime(2026, 3, 21),
      );

      final copied = (await groups()).where((g) => g.tripId == copyId);
      expect(copied.single.collapsed, isTrue);
    });

    test('into a copy of an option', () async {
      final seed = await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: day,
          kind: ItemKind.place,
        ),
      );
      final setId = await db.alternativeDao.createSetFromItem(seed);
      final option = await db.alternativeDao.addAlternative(setId);
      await foldedRun(alternativeId: option);

      await db.alternativeDao.duplicateAlternative(option);

      expect((await groups()).map((g) => g.collapsed), [true, true]);
    });

    test('and an unfolded run stays unfolded', () async {
      final groupId = await foldedRun();
      await repo.setGroupCollapsed(groupId, false);

      await db.groupDao.copyGroup(groupId, day: day);

      expect((await groups()).map((g) => g.collapsed), [false, false]);
    });
  });
}
