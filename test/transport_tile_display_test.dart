import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}) => ItineraryItem(
  id: 1,
  tripId: 1,
  date: DateTime(2026, 7, 27),
  sortOrder: 0,
  kind: ItemKind.transport,
  spansNextDay: false,
  title: title,
  notes: notes,
  fromLocation: fromLocation,
  toLocation: toLocation,
  sourceTripId: sourceTripId,
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
}
