import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/stopovers.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/itinerary/widgets/timeline_tile.dart';
import 'package:travelplanner/features/transport_search/presentation/journey_details_sheet.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Reading back a journey the trip already holds. Drift's `.watch()` streams do
/// not resolve under the fake-async clock, so the trip's items arrive as a plain
/// stream — the same arrangement the other widget tests use.
const _train = TransportModeRow(id: 6, builtinKey: 'train', sortOrder: 5);
const _walk = TransportModeRow(id: 1, builtinKey: 'walk', sortOrder: 0);

ItineraryItem _leg({
  required int id,
  String? title,
  required String from,
  required String to,
  required int start,
  required int end,
  int? mode = 6,
  int? groupId = 1,
  String? notes,
  String? stopovers,
  String? sourceTripId,
}) => ItineraryItem(
  id: id,
  tripId: 7,
  groupId: groupId,
  date: DateTime(2026, 7, 27),
  sortOrder: id,
  kind: ItemKind.transport,
  spansNextDay: false,
  title: title,
  startMinutes: start,
  endMinutes: end,
  mode: mode,
  notes: notes,
  fromLocation: from,
  toLocation: to,
  stopovers: stopovers,
  sourceTripId: sourceTripId,
);

/// Hamburg → Basel as the import wrote it: an ICE calling at three places, a
/// walk across Frankfurt, then a second ICE — all in one group.
final _journey = [
  _leg(
    id: 1,
    title: 'ICE 507',
    from: 'Hamburg Hbf',
    to: 'Frankfurt(Main) Hbf',
    start: 480,
    end: 590,
    notes: 'to München Hbf · Pl. 14 → Pl. 7',
    sourceTripId: 'trip-507',
    stopovers: encodeStopovers(const [
      Stopover(name: 'Hannover Hbf', minutes: 520, delayMinutes: 5),
      Stopover(name: 'Göttingen', minutes: 545),
      Stopover(name: 'Kassel-Wilhelmshöhe', minutes: 565, cancelled: true),
    ]),
  ),
  // The walking transfer, as the import wrote it: no line to name, the walk
  // mode, and nothing to refresh.
  _leg(
    id: 2,
    from: 'Frankfurt(Main) Hbf',
    to: 'Frankfurt(Main) Hbf',
    start: 592,
    end: 600,
    mode: 1,
  ),
  // A service the feed listed no intermediate stops for — imported all the same.
  _leg(
    id: 3,
    title: 'ICE 71',
    from: 'Frankfurt(Main) Hbf',
    to: 'Basel SBB',
    start: 613,
    end: 780,
    sourceTripId: 'trip-71',
  ),
];

Future<void> _pumpSheet(WidgetTester tester, List<ItineraryItem> items) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        itineraryProvider(7).overrideWith((ref) => Stream.value(items)),
        transportModesByIdProvider.overrideWith(
          (ref) => {_train.id: _train, _walk.id: _walk},
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
        home: const Scaffold(
          body: JourneyDetailsSheet(tripId: 7, groupId: 1, title: 'To Basel'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('reads the stored journey as legs and changes', (tester) async {
    await _pumpSheet(tester, _journey);

    expect(find.text('To Basel'), findsOneWidget);
    expect(find.textContaining('ICE 507'), findsOneWidget);
    expect(find.textContaining('ICE 71'), findsOneWidget);
    // The walk between the two trains is the change, not a leg of its own.
    expect(find.text('23 min change in Frankfurt(Main) Hbf'), findsOneWidget);
    expect(find.text('8 min'), findsOneWidget);
    // 08:00 – 13:00, in the header and on the legs themselves.
    expect(find.textContaining('8:00 AM'), findsNWidgets(2));
    expect(find.textContaining('1:00 PM'), findsNWidgets(2));
    // What the import wrote into the leg is where the platforms survive.
    expect(find.textContaining('Pl. 14 → Pl. 7'), findsOneWidget);
  });

  testWidgets('the stops are folded away until asked for', (tester) async {
    await _pumpSheet(tester, _journey);

    expect(find.text('3 stops'), findsOneWidget);
    expect(find.text('Hannover Hbf'), findsNothing);

    await tester.tap(find.text('3 stops'));
    await tester.pumpAndSettle();

    expect(find.text('Hannover Hbf'), findsOneWidget);
    expect(find.text('Kassel-Wilhelmshöhe'), findsOneWidget);
    // Each stop says when the train leaves it — 08:40 for Hannover, running 5
    // late, the miss printed beside the plan as everywhere else.
    expect(find.textContaining('8:40 AM'), findsOneWidget);
    expect(find.textContaining('(+5)'), findsOneWidget);
    // A stop nothing is known about says nothing: 09:05 with no figure.
    expect(find.textContaining('9:05 AM'), findsOneWidget);
  });

  testWidgets('a stop the train skips is struck out, and said on the fold', (
    tester,
  ) async {
    await _pumpSheet(tester, _journey);

    // Folded away is where a cancellation would hide, so the count says it.
    expect(find.text('1 stop canceled'), findsOneWidget);

    await tester.tap(find.text('3 stops'));
    await tester.pumpAndSettle();

    expect(find.text('Canceled'), findsOneWidget);
    final name = tester.widget<Text>(find.text('Kassel-Wilhelmshöhe'));
    expect(name.style?.decoration, TextDecoration.lineThrough);
    // 09:25 with no figure beside it: the feed repeats the plan for a stop it
    // is dropping, and printing that as "(+0)" is what this must never do.
    expect(find.textContaining('9:25 AM'), findsOneWidget);
    expect(find.textContaining('(+0)'), findsNothing);
  });

  testWidgets('a leg with no stops recorded offers no toggle', (tester) async {
    await _pumpSheet(tester, [_journey.last]);

    expect(find.textContaining('stops'), findsNothing);
    expect(find.textContaining('ICE 71'), findsOneWidget);
  });

  testWidgets('only an imported leg offers to refresh its live times', (
    tester,
  ) async {
    await _pumpSheet(tester, _journey);

    // One per service; the walk transfer has no trip to ask about.
    expect(find.byIcon(Icons.sync), findsNWidgets(2));
  });

  group('where the button is offered', () {
    test('a grouped run of legs is a journey; a run of places is not', () {
      expect(groupHasJourney(_journey, 1), isTrue);
      expect(
        groupHasJourney([
          ItineraryItem(
            id: 9,
            tripId: 7,
            groupId: 1,
            date: DateTime(2026, 7, 27),
            sortOrder: 0,
            kind: ItemKind.place,
            spansNextDay: false,
            title: 'Museum',
          ),
        ], 1),
        isFalse,
      );
      // A group other than the one asked about is not this journey.
      expect(groupHasJourney(_journey, 2), isFalse);
    });

    test('every leg of an ungrouped journey keeps its way in', () {
      // What ungrouping an imported connection leaves behind: two services and
      // the walk between them, all loose. Each service opens its own journey —
      // including one the feed listed no intermediate stops for, which is how
      // the first leg of a real import lost its button.
      final loose = [
        for (final item in _journey) item.copyWith(groupId: const Value(null)),
      ];
      expect(hasStandaloneJourney(loose[0]), isTrue); // stops and a trip id
      expect(hasStandaloneJourney(loose[2]), isTrue); // a trip id, no stops
      // The walk transfer is nobody's service: a journey of one walk is nothing.
      expect(hasStandaloneJourney(loose[1]), isFalse);
      // Grouped: its run's header carries the button instead.
      expect(hasStandaloneJourney(_journey.first), isFalse);
      // Hand-entered: the tile already shows everything it knows.
      expect(
        hasStandaloneJourney(
          _leg(
            id: 5,
            title: 'Bus',
            from: 'A',
            to: 'B',
            start: 60,
            end: 120,
            groupId: null,
          ),
        ),
        isFalse,
      );
    });
  });

  testWidgets('a group run carries the way into its journey on its label', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transportModesByIdProvider.overrideWith((ref) => {_train.id: _train}),
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
              width: 400,
              child: GroupRunTile(
                groupId: 1,
                label: null,
                items: _journey,
                accent: Colors.teal,
                costsByItem: const {},
                groupCosts: const [],
                localeName: 'en',
                onTapItem: (_) {},
                onTapCost: (_) {},
                onReorder: (_, _, _) {},
                held: null,
                onShowJourney: () => opened++,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.route));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });
}
