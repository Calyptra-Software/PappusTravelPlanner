import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/checklist/application/checklist_providers.dart';
import 'package:travelplanner/features/checklist/presentation/trip_checklists_section.dart';
import 'package:travelplanner/features/trips/application/trip_providers.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// The checklist cards on the trip screen, driven through the interface rather
/// than through the DAO.
///
/// `checklist_move_test.dart` already stands on the writing; what is untested
/// is everything between a tap and that write — which of the five menu entries
/// does what, when deleting asks first, and the two states of the card that
/// depend on a list being empty.
///
/// The two streams the section watches are drift `.watch()`es, which do not
/// resolve under the fake-async clock and leave a timer behind on disposal
/// (`AGENTS.md`). They are replaced with controllers fed from the database by
/// hand, so the widget, the controller and the repository are all the real
/// ones and only the delivery is stubbed.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late int tripId;

  late StreamController<List<Checklist>> lists;
  final items = <int, StreamController<List<ChecklistItem>>>{};
  // The last value pushed into each, replayed to whoever subscribes next: a
  // card's items are first listened to on the build *after* its checklist
  // arrives, and a broadcast stream has nothing to give a late subscriber.
  var listSnapshot = const <Checklist>[];
  final itemSnapshot = <int, List<ChecklistItem>>{};

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    lists = StreamController<List<Checklist>>.broadcast();
    items.clear();
    listSnapshot = const [];
    itemSnapshot.clear();
    tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Rome',
        startDate: Value(DateTime(2026, 5, 1)),
        endDate: Value(DateTime(2026, 5, 3)),
      ),
    );
  });
  tearDown(() async {
    await lists.close();
    for (final c in items.values) {
      await c.close();
    }
    await db.close();
  });

  StreamController<List<ChecklistItem>> itemsOf(int id) => items.putIfAbsent(
    id,
    () => StreamController<List<ChecklistItem>>.broadcast(),
  );

  /// Read with plain queries, never with the DAO's `watch…` streams: those are
  /// the ones the fake clock never resolves, and awaiting one here would hang
  /// the test rather than fail it.
  Future<List<Checklist>> listsOf(int trip) =>
      (db.select(db.checklists)
            ..where((c) => c.tripId.equals(trip))
            ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
          .get();

  Future<List<ChecklistItem>> entriesOf(int checklistId) =>
      (db.select(db.checklistItems)
            ..where((i) => i.checklistId.equals(checklistId))
            ..orderBy([(i) => OrderingTerm(expression: i.sortOrder)]))
          .get();

  Future<List<Trip>> allTrips() => db.select(db.trips).get();

  /// Pushes what the database now holds into the stubbed streams — the frame
  /// the real drift stream would have delivered by itself.
  Future<void> refresh(WidgetTester tester) async {
    final current = await listsOf(tripId);
    listSnapshot = current;
    lists.add(current);
    for (final checklist in current) {
      final entries = await entriesOf(checklist.id);
      itemSnapshot[checklist.id] = entries;
      itemsOf(checklist.id).add(entries);
    }
    await tester.pumpAndSettle();
  }

  Future<int> seedList(String title, {List<String> entries = const []}) async {
    final id = await db.checklistDao.addChecklist(
      ChecklistsCompanion.insert(tripId: tripId, title: Value(title)),
    );
    for (final entry in entries) {
      await db.checklistDao.addItem(
        ChecklistItemsCompanion.insert(checklistId: id, label: entry),
      );
    }
    return id;
  }

  Future<void> pumpSection(WidgetTester tester, {List<Trip>? trips}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          checklistsProvider.overrideWith((ref, id) async* {
            yield listSnapshot;
            yield* lists.stream;
          }),
          checklistItemsProvider.overrideWith((ref, id) async* {
            yield itemSnapshot[id] ?? const <ChecklistItem>[];
            yield* itemsOf(id).stream;
          }),
          // Always overridden, even where no trip picker is opened: the
          // harness below watches it, and a real `watchTrips()` would leave
          // drift's cancellation timer pending past the end of the test.
          tripListProvider.overrideWith(
            (ref) => Stream.value(trips ?? const <Trip>[]),
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
              // `_toAnotherTrip` reads `tripListProvider` rather than watching
              // it, which only works because something above keeps it alive —
              // in the app, the overview screen the trip was opened from. The
              // harness stands in for it, so what is tested here is the same
              // arrangement that ships.
              child: Consumer(
                builder: (context, ref, _) {
                  ref.watch(tripListProvider);
                  return TripChecklistsSection(
                    tripId: tripId,
                    accent: Colors.teal,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await refresh(tester);
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Checklist actions'));
    await tester.pumpAndSettle();
  }

  group('the section', () {
    testWidgets('a trip with no lists is the button that makes one', (
      tester,
    ) async {
      await pumpSection(tester);

      expect(find.text('Add checklist'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('naming one creates it', (tester) async {
      await pumpSection(tester);

      await tester.tap(find.text('Add checklist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hand luggage');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final stored = await listsOf(tripId);
      expect(stored.single.title, 'Hand luggage');
    });

    testWidgets('backing out of the dialog creates nothing', (tester) async {
      await pumpSection(tester);

      await tester.tap(find.text('Add checklist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await listsOf(tripId), isEmpty);
    });

    testWidgets('a list left unnamed is shown under the default label', (
      tester,
    ) async {
      await seedList('');
      await pumpSection(tester);

      // Not an empty title bar: the card has to be nameable *after* it exists.
      expect(find.text('Checklist'), findsOneWidget);
    });
  });

  group('one card', () {
    testWidgets('counts what is ticked out of what is there', (tester) async {
      final id = await seedList('Packing', entries: ['Passport', 'Charger']);
      await pumpSection(tester);
      final passport = (await entriesOf(id)).first;

      expect(find.text('0/2'), findsOneWidget);

      await tester.tap(find.byType(Checkbox).first);
      await refresh(tester);

      expect(
        (await entriesOf(id)).firstWhere((i) => i.id == passport.id).done,
        isTrue,
      );
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('an empty list carries no count at all', (tester) async {
      await seedList('Packing');
      await pumpSection(tester);

      expect(find.text('0/0'), findsNothing);
    });

    testWidgets('typing an entry and pressing add appends it', (tester) async {
      final id = await seedList('Packing');
      await pumpSection(tester);

      await tester.enterText(find.byType(TextField), 'Passport');
      await tester.tap(find.byTooltip('Add'));
      await refresh(tester);

      expect((await entriesOf(id)).map((i) => i.label), ['Passport']);
      // The field is cleared so the next one can be typed straight away.
      expect(find.text('Passport'), findsOneWidget);
    });

    testWidgets('blank input adds nothing', (tester) async {
      final id = await seedList('Packing');
      await pumpSection(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byTooltip('Add'));
      await refresh(tester);

      expect(await entriesOf(id), isEmpty);
    });

    testWidgets('collapsing is remembered on the row, not in the widget', (
      tester,
    ) async {
      final id = await seedList('Packing', entries: ['Passport']);
      await pumpSection(tester);

      await tester.tap(find.text('Packing'));
      await refresh(tester);

      final stored = (await listsOf(tripId)).firstWhere((c) => c.id == id);
      expect(stored.collapsed, isTrue);
      // The count stays legible while folded — a collapsed section that says
      // nothing about what is inside it is a row with no reason to be tapped.
      expect(find.text('0/1'), findsOneWidget);
    });
  });

  group('its menu', () {
    testWidgets('renames the list', (tester) async {
      final id = await seedList('Packing');
      await pumpSection(tester);

      await openMenu(tester);
      await tester.tap(find.text('Rename checklist').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Hold luggage');
      await tester.tap(find.text('Save'));
      await refresh(tester);

      expect(
        (await listsOf(tripId)).firstWhere((c) => c.id == id).title,
        'Hold luggage',
      );
    });

    testWidgets('duplicates it into the same trip, named as a copy', (
      tester,
    ) async {
      await seedList('Packing', entries: ['Passport']);
      await pumpSection(tester);

      await openMenu(tester);
      await tester.tap(find.text('Duplicate').last);
      await refresh(tester);

      final stored = await listsOf(tripId);
      expect(stored.map((c) => c.title), ['Packing', 'Packing (copy)']);
    });

    testWidgets('deletes an empty list without asking', (tester) async {
      await seedList('Packing');
      await pumpSection(tester);

      await openMenu(tester);
      await tester.tap(find.text('Delete checklist').last);
      await refresh(tester);

      // Nothing is lost, so nothing is asked.
      expect(await listsOf(tripId), isEmpty);
    });

    testWidgets('asks before deleting one that has entries', (tester) async {
      await seedList('Packing', entries: ['Passport']);
      await pumpSection(tester);

      await openMenu(tester);
      await tester.tap(find.text('Delete checklist').last);
      await tester.pumpAndSettle();

      expect(find.text('Delete checklist?'), findsOneWidget);
      expect(find.textContaining('"Packing"'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await refresh(tester);
      expect(await listsOf(tripId), hasLength(1));
    });

    testWidgets('and goes through once the question is answered', (
      tester,
    ) async {
      await seedList('Packing', entries: ['Passport']);
      await pumpSection(tester);

      await openMenu(tester);
      await tester.tap(find.text('Delete checklist').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Delete'),
        ),
      );
      await refresh(tester);

      expect(await listsOf(tripId), isEmpty);
    });

    testWidgets('says so when there is no other trip to copy into', (
      tester,
    ) async {
      await seedList('Packing');
      await pumpSection(tester, trips: []);

      await openMenu(tester);
      await tester.tap(find.text('Copy to trip…').last);
      await tester.pumpAndSettle();

      // A picker over an empty list would be a dialog that can only be
      // dismissed.
      expect(
        find.text('There is no other trip to put it in yet.'),
        findsOneWidget,
      );
    });

    testWidgets('copies into a named trip, unticked, and says as much', (
      tester,
    ) async {
      final id = await seedList('Packing', entries: ['Passport']);
      final first = (await entriesOf(id)).single;
      await db.checklistDao.updateItem(first.copyWith(done: true));
      final other = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'Vienna'),
      );
      await pumpSection(tester, trips: await allTrips());

      await openMenu(tester);
      await tester.tap(find.text('Copy to trip…').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vienna'));
      await refresh(tester);

      final copied = await listsOf(other);
      expect(copied.single.title, 'Packing');
      // The whole reason the feature exists: last summer's list is this
      // summer's starting point, and only an empty one is reusable.
      expect((await entriesOf(copied.single.id)).single.done, isFalse);
      expect(find.textContaining('Ticks aren\'t copied'), findsOneWidget);
      // The original stays where it is.
      expect(await listsOf(tripId), hasLength(1));
    });

    testWidgets('moves into a named trip, ticks and all', (tester) async {
      final id = await seedList('Packing', entries: ['Passport']);
      final first = (await entriesOf(id)).single;
      await db.checklistDao.updateItem(first.copyWith(done: true));
      final other = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'Vienna'),
      );
      await pumpSection(tester, trips: await allTrips());

      await openMenu(tester);
      await tester.tap(find.text('Move to trip…').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vienna'));
      await refresh(tester);

      // It is the same list, relocated — so the ticks come with it.
      expect(await listsOf(tripId), isEmpty);
      final moved = await listsOf(other);
      expect((await entriesOf(moved.single.id)).single.done, isTrue);
      expect(find.textContaining('Moved to'), findsOneWidget);
    });

    testWidgets('the trip it is already in is not offered', (tester) async {
      await seedList('Packing');
      await db.tripDao.createTrip(TripsCompanion.insert(title: 'Vienna'));
      await pumpSection(tester, trips: await allTrips());

      await openMenu(tester);
      await tester.tap(find.text('Copy to trip…').last);
      await tester.pumpAndSettle();

      // Copying a list to where it already is has its own menu entry, and it
      // needs no dialog.
      expect(find.text('Vienna'), findsOneWidget);
      expect(find.text('Rome'), findsNothing);
    });
  });

  group('one entry', () {
    testWidgets('is renamed from its own edit', (tester) async {
      final id = await seedList('Packing', entries: ['Passport']);
      await pumpSection(tester);

      await tester.tap(find.text('Passport'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Passport & visa');
      await tester.tap(find.text('Save'));
      await refresh(tester);

      expect((await entriesOf(id)).single.label, 'Passport & visa');
    });

    testWidgets('is deleted from its own button', (tester) async {
      final id = await seedList('Packing', entries: ['Passport']);
      await pumpSection(tester);

      await tester.tap(find.byTooltip('Delete'));
      await refresh(tester);

      expect(await entriesOf(id), isEmpty);
    });
  });
}
