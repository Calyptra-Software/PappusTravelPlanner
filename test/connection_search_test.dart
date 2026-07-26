import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:travelplanner/features/transport_search/application/transport_search_controller.dart';
import 'package:travelplanner/features/transport_search/application/transport_search_providers.dart';
import 'package:travelplanner/features/transport_search/data/journey_mapper.dart'
    show DirectionLabel, TrackLabel;
import 'package:travelplanner/features/transport_search/domain/journey.dart';
import 'package:travelplanner/features/transport_search/domain/transit_mode.dart';
import 'package:travelplanner/features/transport_search/domain/transport_place.dart';
import 'package:travelplanner/features/transport_search/presentation/connection_search_sheet.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Records import calls without touching the database.
class _FakeController extends TransportSearchController {
  _FakeController(super.ref);
  int imports = 0;

  @override
  Future<List<int>> importJourney(
    int tripId,
    JourneyOption journey, {
    bool group = true,
    TrackLabel? trackLabel,
    DirectionLabel? directionLabel,
  }) async {
    imports++;
    return const [];
  }
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  const place = TransportPlace(
    id: 'A',
    name: 'Hamburg Hbf',
    kind: PlaceKind.stop,
    area: 'Hamburg',
    timeZone: 'Europe/Berlin',
  );

  final option = JourneyOption(
    departure: DateTime.utc(2026, 7, 27, 8),
    arrival: DateTime.utc(2026, 7, 27, 10),
    duration: const Duration(hours: 2),
    transfers: 1,
    legs: [
      JourneyLeg(
        mode: TransitMode.highSpeedRail,
        from: LegPoint(
          name: 'Hamburg',
          scheduled: DateTime.utc(2026, 7, 27, 8),
          actual: DateTime.utc(2026, 7, 27, 8, 5), // +5 min, live
          timeZone: 'Europe/Berlin',
        ),
        to: LegPoint(
          name: 'Berlin',
          scheduled: DateTime.utc(2026, 7, 27, 10),
          actual: DateTime.utc(2026, 7, 27, 10), // on time
          timeZone: 'Europe/Berlin',
        ),
        realTime: true,
        line: 'ICE 1',
      ),
    ],
  );

  late _FakeController fake;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          geocodeProvider.overrideWith((ref, query) async => [place]),
          journeysProvider.overrideWith((ref, query) async => [option]),
          transportSearchControllerProvider.overrideWith(
            (ref) => fake = _FakeController(ref),
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
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showConnectionSearchSheet(
                  context,
                  tripId: 1,
                  day: DateTime(2026, 7, 27),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pickInto(WidgetTester tester, String fieldLabel) async {
    await tester.tap(find.text(fieldLabel));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ham');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hamburg Hbf').last);
    await tester.pumpAndSettle();
  }

  testWidgets('searches and imports a chosen journey', (tester) async {
    await pump(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Pick From and To via the place picker (geocode is overridden).
    await pickInto(tester, 'From');
    await pickInto(tester, 'To');

    // Run the search; the overridden journeysProvider yields one option.
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    // Local Berlin time (08:00Z -> 10:00) with the live delta from real-time.
    expect(find.textContaining('10:00 AM'), findsOneWidget);
    expect(find.textContaining('(+5)'), findsOneWidget);
    expect(find.textContaining('ICE 1'), findsOneWidget);

    // Import it.
    await tester.tap(find.textContaining('ICE 1'));
    await tester.pumpAndSettle();

    expect(fake.imports, 1);
    expect(find.text('Connection added'), findsOneWidget);
  });

  testWidgets('search is disabled until both endpoints are set', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final searchButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Search'),
    );
    expect(searchButton.onPressed, isNull); // disabled

    await pickInto(tester, 'From');
    await pickInto(tester, 'To');

    final enabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Search'),
    );
    expect(enabled.onPressed, isNotNull);
  });
}
