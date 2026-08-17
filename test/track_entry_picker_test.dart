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
}
