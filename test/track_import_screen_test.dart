import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/map/presentation/track_import_screen.dart';
import 'package:travelplanner/features/map/widgets/map_overlays.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// The screen that divides one recording among its entries.
void main() {
  ItineraryItem leg(int id, String title) => ItineraryItem(
    id: id,
    tripId: 1,
    date: DateTime(2026, 5, 1),
    sortOrder: id,
    kind: ItemKind.transport,
    title: title,
    endDayOffset: 0,
    chordDisplay: TrackDisplay.auto,
  );

  ItineraryItem placed(
    int id,
    String title, {
    required double fromLat,
    required double toLat,
  }) => ItineraryItem(
    id: id,
    tripId: 1,
    date: DateTime(2026, 5, 1),
    sortOrder: id,
    kind: ItemKind.transport,
    title: title,
    endDayOffset: 0,
    chordDisplay: TrackDisplay.auto,
    fromLat: fromLat,
    fromLon: 9.9,
    toLat: toLat,
    toLon: 9.9,
  );

  final line = [for (var i = 0; i < 40; i++) LatLng(53.5 + i * 0.001, 9.9)];

  Future<void> pump(
    WidgetTester tester, {
    List<ItineraryItem>? selection,
    List<List<DateTime>?> times = const [],
    bool readTimes = true,
    Duration? offset,
  }) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appVersionProvider.overrideWithValue('0.0.0-test')],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: TrackImportScreen(
            lines: [line],
            times: times,
            readTimes: readTimes,
            offset: offset,
            name: 'Walk',
            selection: selection ?? [leg(1, 'A → B'), leg(2, 'B → C')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps the map [dy] pixels below its centre, where the line runs. The wait
  /// is the double-tap timeout, which a single tap has to outlast to count.
  Future<void> tapMap(WidgetTester tester, double dy) async {
    await tester.tapAt(
      tester.getCenter(find.byType(FlutterMap)) + Offset(0, dy),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  List<LatLng> handovers(WidgetTester tester) => [
    for (final marker
        in tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers)
      marker.point,
  ];

  bool confirmable(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed != null;

  Future<void> drain(WidgetTester tester) async {
    await tester.pump(kTileUpdateThrottle);
    await tester.pump(kTileUpdateThrottle);
  }

  testWidgets('nothing is written until the handover has been pointed at', (
    tester,
  ) async {
    await pump(tester);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull, reason: 'estimating is not offered');
    expect(find.textContaining('A → B'), findsWidgets);

    await drain(tester);
  });

  testWidgets('every entry in the run is named, in its own colour', (
    tester,
  ) async {
    // The division is the whole point of the screen, so the legend has to say
    // which stretch is whose.
    await pump(tester);

    expect(find.text('A → B'), findsWidgets);
    expect(find.text('B → C'), findsWidgets);

    await drain(tester);
  });

  testWidgets('it says what it will do, since it changes entries', (
    tester,
  ) async {
    // Not only the map: an import writes coordinates onto the rows.
    await pump(tester);

    expect(find.textContaining('2 entries'), findsOneWidget);
    // Both legs are bare, so all four ends plus nothing else.
    expect(find.textContaining('coordinates set'), findsOneWidget);

    await drain(tester);
  });

  testWidgets('a run whose entries are already placed asks nothing', (
    tester,
  ) async {
    // The handover comes from the legs' own coordinates, so there is nothing
    // left to point at and the import can be confirmed straight away.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appVersionProvider.overrideWithValue('0.0.0-test')],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: TrackImportScreen(
            lines: [line],
            name: 'Walk',
            selection: [
              placed(1, 'A → B', fromLat: 53.5, toLat: 53.52),
              placed(2, 'B → C', fromLat: 53.52, toLat: 53.539),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    // Nothing to write: every end was already the user's own statement.
    expect(find.textContaining('no coordinates set'), findsOneWidget);

    await drain(tester);
  });

  testWidgets('a single leg needs no handover at all', (tester) async {
    // Its two ends come from the recording, so the screen is a preview.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appVersionProvider.overrideWithValue('0.0.0-test')],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: TrackImportScreen(
            lines: [line],
            name: null,
            selection: [leg(1, 'A → B')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(find.textContaining('2 coordinates set'), findsOneWidget);

    await drain(tester);
  });

  testWidgets('a placed handover can be moved before the next is placed', (
    tester,
  ) async {
    // The selection moves on after a tap, but going back is one tap on the
    // chip — the next open handover no longer takes every tap.
    await pump(
      tester,
      selection: [leg(1, 'A → B'), leg(2, 'B → C'), leg(3, 'C → D')],
    );
    expect(find.text('Handover 1'), findsOneWidget);
    expect(find.text('Handover 2'), findsOneWidget);

    await tapMap(tester, 60);
    expect(handovers(tester), hasLength(1));
    final first = handovers(tester).single;
    expect(find.textContaining('Tap where “B → C”'), findsOneWidget);

    await tester.tap(find.text('Handover 1'));
    await tester.pump();
    expect(find.textContaining('Tap to move where “A → B”'), findsOneWidget);

    await tapMap(tester, 120);
    final moved = handovers(tester).single;
    expect(moved, isNot(first), reason: 'the first handover moved');
    expect(confirmable(tester), isFalse, reason: 'the second is still open');
    // And the selection has gone on to the one still open.
    expect(find.textContaining('Tap where “B → C”'), findsOneWidget);

    await drain(tester);
  });

  testWidgets('once all are placed, a tap refines the one just placed', (
    tester,
  ) async {
    // One rule throughout: the selected handover moves, never the nearest.
    await pump(tester);

    await tapMap(tester, 0);
    expect(confirmable(tester), isTrue);
    final placedAt = handovers(tester).single;

    await tapMap(tester, 80);
    expect(handovers(tester).single, isNot(placedAt));
    expect(find.textContaining('Tap to move where “A → B”'), findsOneWidget);

    await drain(tester);
  });

  testWidgets('a handover read off an entry can be moved along the line', (
    tester,
  ) async {
    // Both handovers come from the legs' own coordinates, which lie beside
    // the recording rather than on it. Moving the first used to look the
    // second up by coordinate, find nothing (-1), and snap every tap to the
    // recording's first point — after which no tap moved it at all.
    LatLng offLine(double lat) => LatLng(lat, 9.9003);
    ItineraryItem beside(int id, String title, double from, double to) =>
        ItineraryItem(
          id: id,
          tripId: 1,
          date: DateTime(2026, 5, 1),
          sortOrder: id,
          kind: ItemKind.transport,
          title: title,
          endDayOffset: 0,
          chordDisplay: TrackDisplay.auto,
          fromLat: offLine(from).latitude,
          fromLon: offLine(from).longitude,
          toLat: offLine(to).latitude,
          toLon: offLine(to).longitude,
        );
    await pump(
      tester,
      selection: [
        beside(1, 'A → B', 53.5, 53.530),
        beside(2, 'B → C', 53.530, 53.535),
        beside(3, 'C → D', 53.535, 53.539),
      ],
    );
    expect(confirmable(tester), isTrue, reason: 'nothing is open');
    // Drawn where the line is divided, not beside it.
    expect(handovers(tester).first, line[30]);

    await tester.tap(find.text('Handover 1'));
    await tester.pump();
    await tapMap(tester, 60);
    final moved = handovers(tester).first;
    expect(line, contains(moved));
    expect(moved, isNot(line.first));
    expect(moved.latitude, lessThan(53.53));
    expect(handovers(tester)[1], line[35], reason: 'the other one stays');

    await tapMap(tester, 20);
    expect(handovers(tester).first, isNot(moved), reason: 'and moves again');

    await drain(tester);
  });

  group('times from the recording', () {
    // A minute per point, from noon UTC on the legs' own day — in any zone
    // from UTC−11 to UTC+11 the device's wall clock stays on 1 May.
    List<DateTime> minutes(DateTime from) => [
      for (var i = 0; i < line.length; i++) from.add(Duration(minutes: i)),
    ];
    final onTheDay = minutes(DateTime.utc(2026, 5, 1, 12));

    testWidgets('a leg is offered its departure and its arrival', (
      tester,
    ) async {
      await pump(tester, selection: [leg(1, 'A → B')], times: [onTheDay]);

      expect(find.text('2 actual times from the recording'), findsOneWidget);

      await tester.tap(find.text('2 actual times from the recording'));
      await tester.pumpAndSettle();
      expect(find.text('Actual times from the recording'), findsOneWidget);
      expect(find.text('A → B: departure'), findsOneWidget);
      expect(find.text('A → B: arrival'), findsOneWidget);

      // Unticking one is remembered once the sheet is gone.
      await tester.tap(find.text('A → B: departure'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(500, 20));
      await tester.pumpAndSettle();
      expect(find.text('1 actual time from the recording'), findsOneWidget);

      await drain(tester);
    });

    testWidgets('nothing is offered before every handover is placed', (
      tester,
    ) async {
      // A leg's times are read at its cuts, and one of them is not there yet.
      await pump(tester, times: [onTheDay]);
      expect(find.textContaining('from the recording'), findsNothing);

      await tapMap(tester, 0);
      expect(find.text('4 actual times from the recording'), findsOneWidget);

      await drain(tester);
    });

    testWidgets('a place at a handover is offered its start and end', (
      tester,
    ) async {
      final cafe = ItineraryItem(
        id: 9,
        tripId: 1,
        date: DateTime(2026, 5, 1),
        sortOrder: 2,
        kind: ItemKind.place,
        title: 'Café',
        endDayOffset: 0,
        chordDisplay: TrackDisplay.auto,
      );
      await pump(
        tester,
        selection: [leg(1, 'A → B'), cafe, leg(2, 'B → C')],
        times: [onTheDay],
      );
      await tapMap(tester, 0);
      expect(find.text('6 actual times from the recording'), findsOneWidget);

      await tester.tap(find.text('6 actual times from the recording'));
      await tester.pumpAndSettle();
      // In the item form's words for a place, not a leg's.
      expect(find.text('Café: start'), findsOneWidget);
      expect(find.text('Café: end'), findsOneWidget);

      await tester.tapAt(const Offset(500, 20));
      await tester.pumpAndSettle();
      await drain(tester);
    });

    testWidgets('a routine is offered none', (tester) async {
      await pump(
        tester,
        selection: [leg(1, 'A → B')],
        times: [onTheDay],
        readTimes: false,
      );
      expect(find.textContaining('from the recording'), findsNothing);

      await drain(tester);
    });

    testWidgets('a recording from another day is said to be one', (
      tester,
    ) async {
      await pump(
        tester,
        selection: [leg(1, 'A → B')],
        times: [minutes(DateTime.utc(2026, 6, 14, 12))],
      );
      expect(find.textContaining('Recorded on June 14, 2026'), findsOneWidget);
      // A warning, not a refusal.
      expect(confirmable(tester), isTrue);

      await drain(tester);
    });

    testWidgets('an offset handed in is the one the times are read in', (
      tester,
    ) async {
      // What this app's recorder knows and a file does not. UTC+05:45 is no
      // test machine's zone, so it can only be on screen if it was used.
      await pump(
        tester,
        selection: [leg(1, 'A → B')],
        times: [onTheDay],
        offset: const Duration(hours: 5, minutes: 45),
      );
      await tester.tap(find.text('2 actual times from the recording'));
      await tester.pumpAndSettle();
      expect(find.text('UTC+05:45'), findsOneWidget);
      expect(find.textContaining('17:45'), findsWidgets);

      await tester.tapAt(const Offset(500, 20));
      await tester.pumpAndSettle();
      await drain(tester);
    });

    testWidgets('a recording without times says nothing about them', (
      tester,
    ) async {
      await pump(tester, selection: [leg(1, 'A → B')]);
      expect(find.textContaining('from the recording'), findsNothing);
      expect(find.textContaining('Recorded on'), findsNothing);

      await drain(tester);
    });
  });

  test('an offset is named the way the picker lists it', () {
    expect(formatUtcOffset(0), 'UTC');
    expect(formatUtcOffset(120), 'UTC+02:00');
    expect(formatUtcOffset(-210), 'UTC\u221203:30');
  });
}
