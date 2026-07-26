import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/features/transport_search/application/transport_search.dart';
import 'package:travelplanner/features/transport_search/application/transport_search_controller.dart';
import 'package:travelplanner/features/transport_search/application/transport_search_providers.dart';
import 'package:travelplanner/features/transport_search/data/journey_mapper.dart'
    show DirectionLabel, TrackLabel;
import 'package:travelplanner/features/transport_search/data/motis_client.dart'
    show TransportSearchException;
import 'package:travelplanner/features/transport_search/domain/journey.dart';
import 'package:travelplanner/features/transport_search/domain/journey_options.dart';
import 'package:travelplanner/features/transport_search/domain/transit_filter.dart';
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

const _place = TransportPlace(
  id: 'A',
  name: 'Hamburg Hbf',
  kind: PlaceKind.stop,
  area: 'Hamburg',
  timeZone: 'Europe/Berlin',
);

/// One journey departing at [hour] UTC and arriving two hours later. [live]
/// gives it real-time data — a 5-minute departure delay, arriving on time.
JourneyOption _option({
  required String line,
  required int hour,
  bool live = false,
}) => JourneyOption(
  departure: DateTime.utc(2026, 7, 27, hour),
  arrival: DateTime.utc(2026, 7, 27, hour + 2),
  duration: const Duration(hours: 2),
  transfers: 1,
  legs: [
    JourneyLeg(
      mode: TransitMode.highSpeedRail,
      from: LegPoint(
        name: 'Hamburg',
        scheduled: DateTime.utc(2026, 7, 27, hour),
        actual: live ? DateTime.utc(2026, 7, 27, hour, 5) : null,
        timeZone: 'Europe/Berlin',
      ),
      to: LegPoint(
        name: 'Berlin',
        scheduled: DateTime.utc(2026, 7, 27, hour + 2),
        actual: live ? DateTime.utc(2026, 7, 27, hour + 2) : null,
        timeZone: 'Europe/Berlin',
      ),
      realTime: live,
      line: line,
    ),
  ],
);

/// A backend serving one journey per time window, so paging is observable: the
/// searched window holds `ICE 1` and points at a window either side, each of
/// which holds one more.
class _FakeSearch implements TransportSearch {
  final calls = <({JourneySearchOptions options, String? pageCursor})>[];

  /// When set, only *paging* requests fail — the first window still answers, so
  /// a test can check that results already found survive a failed "later".
  bool failPaging = false;

  @override
  Future<JourneyResults> journeys({
    required String fromId,
    required String toId,
    required DateTime time,
    bool arriveBy = false,
    JourneySearchOptions options = const JourneySearchOptions(),
    String? pageCursor,
  }) async {
    calls.add((options: options, pageCursor: pageCursor));
    if (pageCursor != null && failPaging) {
      throw const TransportSearchException('offline');
    }
    return switch (pageCursor) {
      null => JourneyResults(
        options: [_option(line: 'ICE 1', hour: 8, live: true)],
        earlierCursor: 'E0',
        laterCursor: 'L0',
      ),
      'L0' => JourneyResults(
        options: [_option(line: 'ICE 2', hour: 10)],
        laterCursor: 'L1',
      ),
      'E0' => JourneyResults(
        options: [_option(line: 'ICE 0', hour: 6)],
        earlierCursor: 'E1',
      ),
      _ => const JourneyResults(options: []),
    };
  }

  @override
  Future<List<TransportPlace>> searchPlaces(String query) async => [_place];

  @override
  Future<List<TripStop>> tripStops(String tripId) => throw UnimplementedError();
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  const place = _place;

  late _FakeController fake;
  late _FakeSearch search;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    search = _FakeSearch();
  });

  Future<void> pump(WidgetTester tester) async {
    // A tall surface so the whole results list — both paging rows included —
    // is laid out; the default test window is shorter than the sheet.
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          geocodeProvider.overrideWith((ref, query) async => [place]),
          transportSearchProvider.overrideWithValue(search),
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

    // Run the search; the fake backend yields the searched window.
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

  /// Opens the search options sheet from the row that summarises it.
  Future<void> openOptions(WidgetTester tester) async {
    await tester.tap(find.widgetWithIcon(ListTile, Icons.tune));
    await tester.pumpAndSettle();
  }

  testWidgets('a narrowed transport filter reaches the search', (tester) async {
    await pump(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await pickInto(tester, 'From');
    await pickInto(tester, 'To');

    // Unrestricted to begin with — the row says so.
    expect(find.text('All means of transport'), findsOneWidget);

    // Open the options and drop flights.
    await openOptions(tester);
    await tester.tap(find.text('Flights'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The row now names what is left in, rather than a count.
    expect(find.textContaining('Long-distance trains'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(search.calls.last.options.modes, isNot(contains(TransitFilter.air)));
    expect(
      search.calls.last.options.modes,
      contains(TransitFilter.longDistanceRail),
    );
    // ...and it is remembered for the next search.
    expect(prefs.getInt('connection_transit_modes'), isNotNull);
  });

  testWidgets('narrowing the filter re-runs a search already on screen', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await pickInto(tester, 'From');
    await pickInto(tester, 'To');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(search.calls.last.options.modes, kAllTransitFilters);

    await openOptions(tester);
    await tester.tap(find.text('Flights'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Results found under the old rules are not left standing.
    expect(search.calls.last.options.modes, isNot(contains(TransitFilter.air)));
  });

  testWidgets('the transfer and interchange limits reach the search', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await pickInto(tester, 'From');
    await pickInto(tester, 'To');

    await openOptions(tester);
    // Drag the "shortest change" slider off zero, and rule out anything but a
    // single change.
    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('≤1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    final asked = search.calls.last.options;
    expect(asked.minTransferMinutes, greaterThan(0));
    expect(asked.maxTransfers, 1);
    // The row states the terms it is now searching under.
    expect(find.textContaining('max 1 change'), findsOneWidget);
    expect(
      prefs.getInt('connection_min_transfer_minutes'),
      asked.minTransferMinutes,
    );
    expect(prefs.getInt('connection_max_transfers'), 1);
  });

  testWidgets('a slower walking speed is remembered and summarised', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await pickInto(tester, 'From');
    await pickInto(tester, 'To');

    await openOptions(tester);
    // The walking slider is the second one; drag it left, towards slower.
    await tester.drag(find.byType(Slider).last, const Offset(-80, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    final asked = search.calls.last.options;
    expect(asked.walkingSpeedKmh, lessThan(kNormalWalkingSpeedKmh));
    expect(find.textContaining('km/h'), findsOneWidget);
    expect(
      prefs.getDouble('connection_walking_speed_kmh'),
      asked.walkingSpeedKmh,
    );
  });

  testWidgets('reset puts every option back, and is the only way to', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await openOptions(tester);
    // Nothing to reset yet.
    final before = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Reset'),
    );
    expect(before.onPressed, isNull);

    await tester.tap(find.text('Direct'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('All means of transport'), findsOneWidget);
  });

  /// Searches Hamburg -> Hamburg so the results (and their paging rows) are on
  /// screen.
  Future<void> searchFrom(WidgetTester tester) async {
    await pump(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await pickInto(tester, 'From');
    await pickInto(tester, 'To');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
  }

  testWidgets('"later" appends the next window, keeping what was found', (
    tester,
  ) async {
    await searchFrom(tester);
    expect(find.textContaining('ICE 1'), findsOneWidget);
    expect(find.textContaining('ICE 2'), findsNothing);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    // Both windows are on screen, and the cursor came from the first response.
    expect(find.textContaining('ICE 1'), findsOneWidget);
    expect(find.textContaining('ICE 2'), findsOneWidget);
    expect(search.calls.last.pageCursor, 'L0');
  });

  testWidgets('"earlier" prepends, and each end pages independently', (
    tester,
  ) async {
    await searchFrom(tester);

    await tester.tap(find.text('Earlier'));
    await tester.pumpAndSettle();
    expect(search.calls.last.pageCursor, 'E0');
    expect(find.textContaining('ICE 0'), findsOneWidget);
    expect(find.textContaining('ICE 1'), findsOneWidget);

    // The earlier window advanced its own cursor; "later" still points at the
    // far end of what is on screen.
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(search.calls.last.pageCursor, 'L0');
    expect(find.textContaining('ICE 2'), findsOneWidget);
  });

  testWidgets('a failed page keeps the results and says so', (tester) async {
    await searchFrom(tester);
    search.failPaging = true;

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't reach the connection service"), findsOneWidget);
    // The window already found is untouched — the button is still there to try
    // again, rather than an emptied screen.
    expect(find.textContaining('ICE 1'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
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
