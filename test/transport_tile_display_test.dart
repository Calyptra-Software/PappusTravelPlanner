import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/itinerary/widgets/timeline_tile.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Pumps a single transport [TimelineTile] with the modes lookup overridden
/// (empty), so it renders without touching the database stream.
Future<void> pumpTile(WidgetTester tester, ItineraryItem item) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        transportModesByIdProvider.overrideWith(
          (ref) => const <int, TransportModeRow>{},
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
          body: Center(
            child: SizedBox(
              width: 400,
              child: TimelineTile(
                item: item,
                accent: Colors.teal,
                onTap: () {},
                costs: const [],
                localeName: 'en',
                onTapCost: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

ItineraryItem leg({
  String? title,
  String? notes,
  String? fromLocation,
  String? toLocation,
  String? sourceTripId,
  int? startMinutes,
  int? endMinutes,
}) => ItineraryItem(
  id: 1,
  tripId: 1,
  date: DateTime(2026, 7, 27),
  sortOrder: 0,
  kind: ItemKind.transport,
  endDayOffset: 0,
  chordDisplay: TrackDisplay.auto,
  title: title,
  notes: notes,
  fromLocation: fromLocation,
  toLocation: toLocation,
  sourceTripId: sourceTripId,
  startMinutes: startMinutes,
  endMinutes: endMinutes,
);

void main() {
  testWidgets('shows the train number and the notes (direction/platform)', (
    tester,
  ) async {
    await pumpTile(
      tester,
      leg(
        title: 'ICE 509',
        notes: 'to München Hbf · Pl. 20',
        fromLocation: 'Hamburg Hbf',
        toLocation: 'Berlin Hbf',
      ),
    );

    // Train number next to the mode label.
    expect(find.textContaining('ICE 509'), findsOneWidget);
    // Direction and platform ride along in the notes.
    expect(find.text('to München Hbf · Pl. 20'), findsOneWidget);
  });

  testWidgets('a plain manual leg shows no notes clutter', (tester) async {
    await pumpTile(tester, leg(fromLocation: 'Home', toLocation: 'Airport'));
    expect(find.textContaining('Pl.'), findsNothing);
    expect(find.textContaining('Home'), findsOneWidget);
  });

  testWidgets('the live-refresh button shows only on an imported leg', (
    tester,
  ) async {
    // A leg with a routing trip id (imported) gets the refresh button.
    await pumpTile(tester, leg(fromLocation: 'A', sourceTripId: 'trip-1'));
    expect(find.byIcon(Icons.sync), findsOneWidget);

    // A hand-entered / walk leg (no trip id) does not.
    await pumpTile(tester, leg(fromLocation: 'A'));
    expect(find.byIcon(Icons.sync), findsNothing);
  });

  testWidgets('a long title wraps, and leaves the times whole', (tester) async {
    const title =
        'Hintere Piste oberer Teil, Hintere Piste, Mittlere Piste, '
        'Herrenbächli - Hundschopf - Alpenblick, Klempen - Alpentobel';
    await pumpTile(
      tester,
      leg(
        title: title,
        fromLocation: 'Hörnligrat',
        toLocation: 'Innerarosa',
        startMinutes: 10 * 60 + 5,
        endMinutes: 10 * 60 + 19,
      ),
    );

    final tile = tester.getRect(find.byType(TimelineTile));
    final header = find.textContaining('Hintere Piste oberer Teil');
    final times = find.text('10:05 – 10:19', findRichText: true);
    expect(tester.getRect(header).right, lessThanOrEqualTo(tile.right));
    // On one line, inside the tile.
    expect(
      tester.getSize(times).height,
      lessThan(
        2 * tester.getSize(find.text('Hörnligrat  →  Innerarosa')).height,
      ),
    );
    expect(tester.getRect(times).right, lessThanOrEqualTo(tile.right));
    // At most two lines of title: the whole of it is a tap away.
    final paragraph = tester.renderObject<RenderParagraph>(header);
    expect(paragraph.didExceedMaxLines, isTrue);
  });

  testWidgets('a short title keeps the times beside it', (tester) async {
    await pumpTile(
      tester,
      leg(title: 'S1', startMinutes: 9 * 60, endMinutes: 10 * 60),
    );

    final header = tester.getRect(find.textContaining('S1'));
    final times = tester.getRect(
      find.text('09:00 – 10:00', findRichText: true),
    );
    expect(times.left, greaterThan(header.right));
    expect(times.center.dy, moreOrLessEquals(header.center.dy, epsilon: 2));
  });
}
