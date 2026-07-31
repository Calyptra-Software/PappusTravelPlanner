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
import 'package:travelplanner/features/transport_search/domain/via_stop.dart';
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

/// Two more stops, so vias can be told apart from the ends and from each other.
const _viaPlace = TransportPlace(
  id: 'V1',
  name: 'Hannover Hbf',
  kind: PlaceKind.stop,
  area: 'Hannover',
  timeZone: 'Europe/Berlin',
);
const _viaPlace2 = TransportPlace(
  id: 'V2',
  name: 'Nürnberg Hbf',
  kind: PlaceKind.stop,
  area: 'Nürnberg',
  timeZone: 'Europe/Berlin',
);

/// What the geocoder answers with for anything that is *not* a stop — the
/// routing service takes no coordinates for a via, so this must never be
/// offered as one.
const _address = TransportPlace(
  id: 'way/[142944431]',
  name: 'Rathausmarkt 1',
  kind: PlaceKind.address,
  area: 'Hamburg',
  lat: 53.55,
  lon: 9.99,
);

/// One journey departing at [hour] UTC and running for [duration]. [live] gives
/// it real-time data — a 5-minute departure delay, arriving on time.
JourneyOption _option({
  required String? line,
  required int hour,
  bool live = false,
  TransitMode mode = TransitMode.highSpeedRail,
  Duration duration = const Duration(hours: 2),
}) {
  final departure = DateTime.utc(2026, 7, 27, hour);
  final arrival = departure.add(duration);
  return JourneyOption(
    departure: departure,
    arrival: arrival,
    duration: duration,
    transfers: 1,
    legs: [
      JourneyLeg(
        mode: mode,
        from: LegPoint(
          name: 'Hamburg',
          scheduled: departure,
          actual: live ? departure.add(const Duration(minutes: 5)) : null,
          timeZone: 'Europe/Berlin',
        ),
        to: LegPoint(
          name: 'Berlin',
          scheduled: arrival,
          actual: live ? arrival : null,
          timeZone: 'Europe/Berlin',
        ),
        realTime: live,
        line: line,
      ),
    ],
  );
}

/// A backend serving one journey per time window, so paging is observable: the
/// searched window holds `ICE 1` and points at a window either side, each of
/// which holds one more.
class _FakeSearch implements TransportSearch {
  final calls =
      <({JourneySearchOptions options, ViaStops via, String? pageCursor})>[];

  /// When set, only *paging* requests fail — the first window still answers, so
  /// a test can check that results already found survive a failed "later".
  bool failPaging = false;

  /// When set, the service answers the way it does for a walker who outruns
  /// the timetable: transit slower than the fastest direct connection is cut
  /// off, so there are **no** itineraries and the answer is the walk.
  bool outrunsTransit = false;

  /// When set, nothing is found at all — what requiring bike carriage does on
  /// the many networks that publish nothing about it.
  bool findsNothing = false;

  @override
  Future<JourneyResults> journeys({
    required String fromId,
    required String toId,
    required DateTime time,
    bool arriveBy = false,
    JourneySearchOptions options = const JourneySearchOptions(),
    ViaStops via = ViaStops.none,
    String? pageCursor,
  }) async {
    calls.add((options: options, via: via, pageCursor: pageCursor));
    if (pageCursor != null && failPaging) {
      throw const TransportSearchException('offline');
    }
    if (findsNothing) return const JourneyResults(options: []);
    if (outrunsTransit) {
      return JourneyResults(
        options: const [],
        direct: [
          _option(
            line: null,
            hour: 9,
            mode: TransitMode.walk,
            duration: const Duration(minutes: 12),
          ),
        ],
      );
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

  late _FakeController fake;
  late _FakeSearch search;
  late SharedPreferences prefs;

  /// What the place picker is offered, so a test can put a non-stop in front of
  /// it. Read through the geocode override below, which every picker shares.
  late List<TransportPlace> suggestions;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    search = _FakeSearch();
    suggestions = const [_place];
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
          geocodeProvider.overrideWith((ref, query) async => suggestions),
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

  Future<void> pickInto(
    WidgetTester tester,
    String fieldLabel, {
    String pick = 'Hamburg Hbf',
  }) async {
    await tester.tap(find.text(fieldLabel));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ham');
    await tester.pumpAndSettle();
    await tester.tap(find.text(pick).last);
    await tester.pumpAndSettle();
  }

  /// Adds a via stop through the button that offers one. Unlike From and To
  /// there is no field to tap: the row appears only once it holds a station.
  Future<void> addVia(WidgetTester tester, String pick) async {
    await tester.tap(find.text('Add via stop'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ham');
    await tester.pumpAndSettle();
    await tester.tap(find.text(pick).last);
    await tester.pumpAndSettle();
  }

  /// Sets the [index]-th via stop's minimum stay to the entry reading [label].
  Future<void> setStay(WidgetTester tester, int index, String label) async {
    await tester.tap(find.byType(DropdownButton<int>).at(index));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
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

    // Tapping only opens the preview — nothing is added yet. (The controller
    // is not even built at this point, so its call count cannot be asked; that
    // nothing was imported is exactly what the missing confirmation says.)
    await tester.tap(find.textContaining('ICE 1'));
    await tester.pumpAndSettle();
    expect(find.text('Connection added'), findsNothing);
    expect(find.text('Add to day'), findsOneWidget);

    // The button in the preview is what commits it.
    await tester.tap(find.text('Add to day'));
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
    // The walking slider is the second one. A drag starts at the widget's
    // centre — i.e. the middle of the *range* — so this pulls well past the
    // left edge rather than by a distance that would mean different speeds if
    // the range ever changes.
    await tester.drag(find.byType(Slider).last, const Offset(-400, 0));
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

  testWidgets('taking a bike reaches the search, and reads back on the row', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await pickInto(tester, 'From');
    await pickInto(tester, 'To');

    await openOptions(tester);
    // The cycling controls only exist once there is a bike to ride.
    expect(find.text('Cycling speed'), findsNothing);
    expect(find.text('Bike comes along'), findsNothing);
    await tester.tap(find.text('Travelling by bike'));
    await tester.pumpAndSettle();
    expect(find.text('Cycling speed'), findsOneWidget);

    await tester.tap(find.text('Bike comes along'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    final asked = search.calls.last.options;
    expect(asked.byBike, isTrue);
    expect(asked.bikeOnBoard, isTrue);
    expect(find.textContaining('Bike comes along'), findsOneWidget);
    expect(prefs.getBool('connection_by_bike'), isTrue);
    expect(prefs.getBool('connection_bike_on_board'), isTrue);
  });

  testWidgets('a walking budget can be pinned, and goes back to automatic', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await pickInto(tester, 'From');
    await pickInto(tester, 'To');

    await openOptions(tester);
    // Every budget starts automatic.
    expect(find.text('Auto'), findsNWidgets(3));
    await tester.tap(find.text('To the first stop'));
    await tester.pumpAndSettle();
    // Open that row's menu and choose 10 minutes.
    await tester.tap(find.byType(DropdownButton<int?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 min').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(search.calls.last.options.maxPreTransitMinutes, 10);
    // The others stay automatic rather than being pinned to a number.
    expect(search.calls.last.options.maxPostTransitMinutes, isNull);
    expect(prefs.getInt('connection_max_pre_transit_minutes'), 10);
    expect(find.textContaining('≤10 min to stop'), findsOneWidget);

    // Back to automatic: the stored value is removed, not set to something.
    await openOptions(tester);
    await tester.tap(find.byType(DropdownButton<int?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auto').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(prefs.getInt('connection_max_pre_transit_minutes'), isNull);
  });

  testWidgets('requiring bike carriage says why nothing was found', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await pickInto(tester, 'From');
    await pickInto(tester, 'To');

    await openOptions(tester);
    await tester.tap(find.text('Travelling by bike'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bike comes along'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    search.findsNothing = true;
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    // Most feeds say nothing about bike carriage, so this filter finds nothing
    // through no fault of the route — "no connections found" would send the
    // user hunting for a better time instead of the switch they just flipped.
    expect(find.text('No connections that take bikes'), findsOneWidget);
    expect(find.text('No connections found'), findsNothing);
  });

  testWidgets('outrunning the timetable shows the walk, not "no connections"', (
    tester,
  ) async {
    search.outrunsTransit = true;
    await searchFrom(tester);

    // The router cut off every transit option as slower than simply walking, so
    // the answer is the walk — saying "no connections found" beside it would be
    // both discouraging and untrue.
    expect(find.text('Without public transport'), findsOneWidget);
    expect(find.text('12m'), findsOneWidget);
    expect(find.text('No connections found'), findsNothing);
    // It belongs to no time window, so paging is not offered for it.
    expect(find.text('Earlier'), findsNothing);
    expect(find.text('Later'), findsNothing);
  });

  testWidgets('a direct connection can be added to the day like any other', (
    tester,
  ) async {
    search.outrunsTransit = true;
    await searchFrom(tester);

    await tester.tap(find.text('12m'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to day'));
    await tester.pumpAndSettle();

    expect(fake.imports, 1);
    expect(find.text('Connection added'), findsOneWidget);
  });

  testWidgets('an ordinary search asks nothing about via stops', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await pickInto(tester, 'From');
    await pickInto(tester, 'To');

    // Straight from A to B is the ordinary journey, so the form holds no via
    // field at all — only the offer of one.
    expect(find.text('Via stop'), findsNothing);
    expect(find.text('Stay at least'), findsNothing);
    expect(find.text('Add via stop'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(search.calls.last.via.isEmpty, isTrue);
  });

  testWidgets('a via stop and its minimum stay reach the search', (
    tester,
  ) async {
    suggestions = const [_place, _viaPlace];
    await pump(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await pickInto(tester, 'From');
    await pickInto(tester, 'To');
    await addVia(tester, 'Hannover Hbf');

    // The row exists only now, and it came with its stay.
    expect(find.text('Hannover Hbf'), findsOneWidget);
    expect(find.text('Stay at least'), findsOneWidget);
    await setStay(tester, 0, '2 h');

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(
      search.calls.last.via,
      const ViaStops([ViaStop(id: 'V1', minimumStayMinutes: 120)]),
    );
  });

  testWidgets('a via stop asked for with no minimum stay says so', (
    tester,
  ) async {
    suggestions = const [_place, _viaPlace];
    await pump(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await pickInto(tester, 'From');
    await pickInto(tester, 'To');
    await addVia(tester, 'Hannover Hbf');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    // Zero is a real answer — it lets the traveller stay on the same vehicle
    // through the via — so the stop still travels, with no floor on it.
    expect(search.calls.last.via, const ViaStops([ViaStop(id: 'V1')]));
  });

  testWidgets('two via stops travel in the order they were added', (
    tester,
  ) async {
    suggestions = const [_place, _viaPlace, _viaPlace2];
    await pump(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await pickInto(tester, 'From');
    await pickInto(tester, 'To');
    await addVia(tester, 'Hannover Hbf');
    await addVia(tester, 'Nürnberg Hbf');

    // Two is the service's limit, so nothing offers a third.
    expect(find.text('Add via stop'), findsNothing);
    expect(find.text('Stay at least'), findsNWidgets(2));

    // A stay on the second stop only; the first keeps its "no minimum".
    await setStay(tester, 1, '2 h');

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(
      search.calls.last.via,
      const ViaStops([
        ViaStop(id: 'V1'),
        ViaStop(id: 'V2', minimumStayMinutes: 120),
      ]),
    );
  });

  testWidgets('removing a via stop takes its stay with it', (tester) async {
    suggestions = const [_place, _viaPlace, _viaPlace2];
    await pump(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await pickInto(tester, 'From');
    await pickInto(tester, 'To');
    await addVia(tester, 'Hannover Hbf');
    await addVia(tester, 'Nürnberg Hbf');
    await setStay(tester, 0, '2 h');

    // Remove the first; the second stays, and so does *its* stay.
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.text('Hannover Hbf'), findsNothing);
    expect(find.text('Nürnberg Hbf'), findsOneWidget);
    expect(find.text('Add via stop'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(search.calls.last.via, const ViaStops([ViaStop(id: 'V2')]));

    // The next via starts from no minimum rather than inheriting the "2 h"
    // that was set for a stop no longer on the form.
    await addVia(tester, 'Hannover Hbf');
    expect(find.text('No minimum'), findsNWidgets(2));
  });

  testWidgets('only a station may be a via stop', (tester) async {
    suggestions = const [_place, _address];
    await pump(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add via stop'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ham');
    await tester.pumpAndSettle();

    // The service takes a stop id here and no coordinates at all, so an address
    // offered in this list could only be picked and then fail. Said in words,
    // too — a list that silently drops what was typed into it is a puzzle.
    expect(find.text('Rathausmarkt 1'), findsNothing);
    expect(find.text('Hamburg Hbf'), findsOneWidget);
    expect(find.text('Only stations can be a via stop.'), findsOneWidget);
    await tester.tap(find.text('Hamburg Hbf'));
    await tester.pumpAndSettle();

    // The ends are unaffected: an address is a perfectly good origin, routed
    // by coordinate.
    await tester.tap(find.text('From'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Rat');
    await tester.pumpAndSettle();
    expect(find.text('Rathausmarkt 1'), findsOneWidget);
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
