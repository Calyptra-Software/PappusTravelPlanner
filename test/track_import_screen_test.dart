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
    spansNextDay: false,
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
    spansNextDay: false,
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
}
