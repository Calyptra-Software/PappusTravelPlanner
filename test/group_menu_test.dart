import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/itinerary/widgets/timeline_tile.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Covers the menu on a run's label: what is done to the *run* is offered on
/// the run. Renaming it and dissolving it used to sit in the grouping section
/// of one member's edit form — a place that says nothing about the band above
/// it, and which member you had opened was pure accident. Deleting is covered
/// where it is written (`group_dao_test.dart`); what is asserted here is that
/// the five acts are reachable from the label and write what they claim.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late int tripId;
  late int groupId;

  final day = DateTime(2026, 7, 5);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
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

  Future<List<ItineraryItem>> items() =>
      (db.select(db.itineraryItems)
            ..where((i) => i.tripId.equals(tripId))
            ..orderBy([(i) => OrderingTerm(expression: i.sortOrder)]))
          .get();

  Future<ItemGroup> group() => (db.select(
    db.itemGroups,
  )..where((g) => g.id.equals(groupId))).getSingle();

  Future<void> pumpRun(WidgetTester tester, {String? label}) async {
    final first = await addItem('Museum', sortOrder: 0);
    final second = await addItem('Lunch', sortOrder: 1);
    groupId = await db.groupDao.groupItems(first, second);
    if (label != null) await db.groupDao.setGroupLabel(groupId, label);
    final run = await items();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
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
              width: 400,
              child: GroupRunTile(
                groupId: groupId,
                label: label,
                items: run,
                accent: Colors.teal,
                costsByItem: const {},
                groupCosts: const [],
                localeName: 'en',
                onTapItem: (_) {},
                onTapCost: (_) {},
                onReorder: (_, _, _) {},
                held: null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  testWidgets('the run is named from its own label', (tester) async {
    await pumpRun(tester, label: 'Train to Rome');
    await openMenu(tester);
    // The prompt opens on the name the band is showing, not on an empty field.
    await tester.tap(find.text('Rename group'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Train to Rome'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Night train');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect((await group()).label, 'Night train');
  });

  testWidgets('ungrouping frees the entries, beside the act that deletes them', (
    tester,
  ) async {
    await pumpRun(tester);
    await openMenu(tester);
    // Both halves of the same question are on one menu: the delete dialog tells
    // the reader to ungroup instead, so the way out has to be within reach of
    // the door it warns about.
    expect(find.text('Ungroup'), findsOneWidget);
    expect(find.text('Delete group'), findsOneWidget);

    await tester.tap(find.text('Ungroup'));
    await tester.pumpAndSettle();

    final freed = await items();
    expect(freed, hasLength(2));
    expect(freed.every((it) => it.groupId == null), isTrue);
  });

  testWidgets('the whole run is addressed from one menu', (tester) async {
    await pumpRun(tester, label: 'Train to Rome');
    await openMenu(tester);
    for (final action in const [
      'Rename group',
      'Move group to…',
      'Copy group to…',
      'Ungroup',
      'Delete group',
    ]) {
      expect(find.text(action), findsOneWidget, reason: action);
    }
  });
}
