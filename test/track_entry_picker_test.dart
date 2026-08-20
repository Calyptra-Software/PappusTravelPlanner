import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/map/widgets/track_entry_picker.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Which entries a recording covers.
///
/// The rule under test is that the selection is a **run**: the sheet keeps two
/// ends and everything between them, so no gesture can punch a hole in the
/// middle. A gap there would be a stretch of the line handed to nobody — or an
/// entry given ground it never covered.
void main() {
  ItineraryItem leg(int id, String title, {int day = 1}) => ItineraryItem(
    id: id,
    tripId: 1,
    date: DateTime(2026, 5, day),
    sortOrder: id,
    kind: ItemKind.transport,
    title: title,
    spansNextDay: false,
  );

  ItineraryItem place(int id, String title, {int day = 1}) => ItineraryItem(
    id: id,
    tripId: 1,
    date: DateTime(2026, 5, day),
    sortOrder: id,
    kind: ItemKind.place,
    title: title,
    spansNextDay: false,
  );

  /// A day of walk, café, walk, station, train.
  final items = [
    leg(1, 'A → B'),
    place(2, 'B'),
    leg(3, 'B → C'),
    place(4, 'C'),
    leg(5, 'C → D', day: 2),
  ];

  late List<ItineraryItem>? chosen;

  Future<void> open(
    WidgetTester tester, {
    List<int> preselected = const [],
    List<ItineraryItem>? entries,
    Map<int, AlternativeSet> sets = const {},
    Map<int, List<Alternative>> branchesBySet = const {},
  }) async {
    chosen = null;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                chosen = await showTrackEntryPicker(
                  context,
                  items: entries ?? items,
                  sets: sets,
                  branchesBySet: branchesBySet,
                  preselected: preselected,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// The tick state of each row, in the order they are listed.
  List<bool> ticks(WidgetTester tester) => [
    for (final t in tester.widgetList<CheckboxListTile>(
      find.byType(CheckboxListTile),
    ))
      t.value ?? false,
  ];

  Future<void> tapRow(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('it opens on nothing, and says what it wants', (tester) async {
    await open(tester);

    expect(ticks(tester), everyElement(isFalse));
    expect(find.text('Which entries does it cover?'), findsOneWidget);
    // Only a leg can carry a line, so a selection of places alone is refused.
    expect(find.text('Pick at least one transport leg'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('the entry it was opened from is already ticked', (tester) async {
    // The door decides the starting selection: a leg's form ticks that leg.
    await open(tester, preselected: [3]);

    expect(ticks(tester), [false, false, true, false, false]);
  });

  testWidgets('tapping beyond the run extends it, filling the gap', (
    tester,
  ) async {
    // The whole reason the selection is two indices rather than a set of ticks.
    await open(tester, preselected: [1]);

    await tapRow(tester, 'C');

    expect(ticks(tester), [true, true, true, true, false]);
  });

  testWidgets('tapping an end pulls the run back', (tester) async {
    await open(tester, preselected: [1, 2, 3]);

    await tapRow(tester, 'B → C');

    expect(ticks(tester), [true, true, false, false, false]);
  });

  testWidgets('tapping the only entry clears the selection', (tester) async {
    await open(tester, preselected: [1]);

    await tapRow(tester, 'A → B');

    expect(ticks(tester), everyElement(isFalse));
  });

  testWidgets('tapping inside the run moves the nearer end to it', (
    tester,
  ) async {
    // A tap always means "this is now an end", never "punch a hole here".
    await open(tester, preselected: [1, 2, 3, 4, 5]);

    await tapRow(tester, 'B');

    expect(ticks(tester), [false, true, true, true, true]);
  });

  testWidgets('a run spanning midnight is expressible', (tester) async {
    // A recording is usually one outing but is not required to be, so the days
    // are headers rather than a filter.
    await open(tester, preselected: [1]);
    expect(find.textContaining('May'), findsNWidgets(2));

    await tapRow(tester, 'C → D');

    expect(ticks(tester), everyElement(isTrue));
  });

  testWidgets('confirming hands back the run, in order', (tester) async {
    await open(tester, preselected: [3]);

    await tapRow(tester, 'C');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(chosen?.map((i) => i.id), [3, 4]);
  });

  testWidgets('a run of places alone cannot be confirmed', (tester) async {
    // There would be nothing to give the line to.
    await open(tester, entries: [place(1, 'B'), place(2, 'C')]);

    await tapRow(tester, 'B');

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('an entry with no title is named by where it runs', (
    tester,
  ) async {
    await open(
      tester,
      entries: [
        ItineraryItem(
          id: 7,
          tripId: 1,
          date: DateTime(2026, 5, 1),
          sortOrder: 0,
          kind: ItemKind.transport,
          spansNextDay: false,
          fromLocation: 'Rahlstedt',
          toLocation: 'Hbf',
        ),
      ],
    );

    expect(find.text('Rahlstedt → Hbf'), findsOneWidget);
  });

  // --- decisions ---

  AlternativeSet set(int id, int sortOrder, {String? label, int day = 1}) =>
      AlternativeSet(
        id: id,
        tripId: 1,
        date: DateTime(2026, 5, day),
        sortOrder: sortOrder,
        label: label,
      );

  Alternative branch(int id, int setId, int sortOrder, {bool chosen = false}) =>
      Alternative(id: id, setId: setId, sortOrder: sortOrder, chosen: chosen);

  ItineraryItem inOption(
    int id,
    String title,
    int branchId, {
    int sortOrder = 0,
    ItemKind kind = ItemKind.transport,
  }) => ItineraryItem(
    id: id,
    tripId: 1,
    date: DateTime(2026, 5, 1),
    sortOrder: sortOrder,
    kind: kind,
    title: title,
    alternativeId: branchId,
    spansNextDay: false,
  );

  /// A day that forks: a loose walk, then a choice between the ferry and the
  /// bus, then a loose walk home. Both options hold a leg named for the way it
  /// goes — which is exactly the pair that used to be printed side by side with
  /// nothing saying they exclude each other.
  ///
  /// The decision takes slot 2, between the two loose legs; the options' own
  /// entries start at slot 0, since a branch item's sortOrder counts inside its
  /// branch. Read flat, the ferry would therefore come first.
  final forked = [
    leg(1, 'Home → Pier'),
    inOption(20, 'Ferry', 101),
    inOption(21, 'Bus', 102),
    leg(3, 'Pier → Home'),
  ];
  final forkedSets = {1: set(1, 2, label: 'Crossing')};
  final forkedBranches = {
    1: [branch(101, 1, 0, chosen: true), branch(102, 1, 1)],
  };

  testWidgets('only the chosen option is on the path', (tester) async {
    // The competing option is not hidden information — it is a road the
    // recording cannot have taken while it took this one.
    await open(
      tester,
      entries: forked,
      sets: forkedSets,
      branchesBySet: forkedBranches,
    );

    expect(find.text('Ferry'), findsOneWidget);
    expect(find.text('Bus'), findsNothing);
    expect(find.text('Crossing'), findsOneWidget);
    expect(find.text('Option A'), findsOneWidget);
  });

  testWidgets('the path reads in timeline order, not in row order', (
    tester,
  ) async {
    // A branch item's sortOrder orders it *within its branch*, so read flat it
    // would jump ahead of the loose entries it comes after — and the line would
    // then be cut in the wrong places.
    await open(
      tester,
      entries: forked,
      sets: forkedSets,
      branchesBySet: forkedBranches,
      preselected: [1, 20, 3],
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(chosen?.map((i) => i.id), [1, 20, 3]);
  });

  testWidgets('switching the option swaps what the run runs through', (
    tester,
  ) async {
    await open(
      tester,
      entries: forked,
      sets: forkedSets,
      branchesBySet: forkedBranches,
      preselected: [1, 20, 3],
    );

    await tester.tap(find.text('Option A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Option B').last);
    await tester.pumpAndSettle();

    // The ends were never inside the decision, so the run survives with the
    // other option's leg in the middle of it.
    expect(find.text('Bus'), findsOneWidget);
    expect(ticks(tester), everyElement(isTrue));
    expect(find.text('Not the option the trip follows'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(chosen?.map((i) => i.id), [1, 21, 3]);
  });

  testWidgets('switching away from an end of the run clears it', (
    tester,
  ) async {
    // There is no honest place to put an end whose entry has left the path.
    await open(
      tester,
      entries: forked,
      sets: forkedSets,
      branchesBySet: forkedBranches,
      preselected: [20],
    );
    expect(ticks(tester), [false, true, false]);

    await tester.tap(find.text('Option A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Option B').last);
    await tester.pumpAndSettle();

    expect(ticks(tester), everyElement(isFalse));
  });

  testWidgets('it opens on the option the import was started from', (
    tester,
  ) async {
    // A leg reached through its own option's form must be on the list, chosen
    // option or not — otherwise the picker opens without the very entry it was
    // opened for.
    await open(
      tester,
      entries: forked,
      sets: forkedSets,
      branchesBySet: forkedBranches,
      preselected: [21],
    );

    expect(find.text('Bus'), findsOneWidget);
    expect(find.text('Ferry'), findsNothing);
    expect(ticks(tester), [false, true, false]);
    expect(find.text('Not the option the trip follows'), findsOneWidget);
  });

  testWidgets('a plan with no fork says nothing about options', (tester) async {
    await open(tester);

    expect(find.textContaining('Where the plan forks'), findsNothing);
  });
}
