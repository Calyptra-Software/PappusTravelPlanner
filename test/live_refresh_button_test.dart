import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/itinerary/widgets/live_refresh_button.dart';
import 'package:travelplanner/features/transport_search/application/transport_search.dart';
import 'package:travelplanner/features/transport_search/application/transport_search_providers.dart';
import 'package:travelplanner/features/transport_search/data/motis_client.dart';
import 'package:travelplanner/features/transport_search/domain/journey.dart';
import 'package:travelplanner/features/transport_search/domain/journey_options.dart';
import 'package:travelplanner/features/transport_search/domain/transport_place.dart';
import 'package:travelplanner/features/transport_search/domain/via_stop.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// A router whose every trip lookup fails with [failure].
class _FailingSearch implements TransportSearch {
  _FailingSearch(this.failure);

  final Exception failure;

  @override
  Future<List<TripStop>> tripStops(String tripId) async => throw failure;

  @override
  Future<List<StopDeparture>> departures({
    required double lat,
    required double lon,
    required DateTime from,
    required Duration window,
  }) async => const [];

  @override
  Future<List<TransportPlace>> searchPlaces(String query) =>
      throw UnimplementedError();
  @override
  Future<JourneyResults> journeys({
    required String fromId,
    required String toId,
    required DateTime time,
    bool arriveBy = false,
    JourneySearchOptions options = const JourneySearchOptions(),
    ViaStops via = ViaStops.none,
    String? pageCursor,
  }) => throw UnimplementedError();
}

/// An imported leg, with nothing to find it again by on a departure board.
final _leg = ItineraryItem(
  id: 1,
  tripId: 7,
  date: DateTime(2026, 11, 15),
  sortOrder: 0,
  kind: ItemKind.transport,
  endDayOffset: 0,
  chordDisplay: TrackDisplay.auto,
  title: 'ICE 585',
  startMinutes: 553,
  endMinutes: 568,
  fromLocation: 'Hamburg-Harburg',
  toLocation: 'Lüneburg',
  sourceTripId: 'expired',
);

Future<void> _tapRefresh(WidgetTester tester, TransportSearch search) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [transportSearchProvider.overrideWithValue(search)],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: LiveRefreshButton(item: _leg)),
      ),
    ),
  );
  await tester.tap(find.byIcon(Icons.sync));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a service gone from the timetable is said as such', (
    tester,
  ) async {
    await _tapRefresh(
      tester,
      _FailingSearch(
        const TransportSearchException(
          'MOTIS request failed (404)',
          statusCode: 404,
        ),
      ),
    );

    // News about the train, not about the network.
    expect(
      find.text('This service is no longer in the current timetable'),
      findsOneWidget,
    );
    expect(find.text("Couldn't fetch live times"), findsNothing);
  });

  testWidgets('any other failure is a failure to fetch', (tester) async {
    await _tapRefresh(
      tester,
      _FailingSearch(
        const TransportSearchException(
          'MOTIS request failed (503)',
          statusCode: 503,
        ),
      ),
    );

    expect(find.text("Couldn't fetch live times"), findsOneWidget);
  });
}
