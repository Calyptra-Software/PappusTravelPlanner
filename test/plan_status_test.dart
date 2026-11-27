import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/route_plan.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/database/track_points.dart';
import 'package:travelplanner/features/itinerary/application/transport_mode_providers.dart';
import 'package:travelplanner/features/map/map_features.dart';
import 'package:travelplanner/features/route_planner/domain/pace.dart';
import 'package:travelplanner/features/route_planner/domain/route_progress.dart';
import 'package:travelplanner/features/route_planner/presentation/plan_status.dart';
import 'package:travelplanner/features/transport_search/presentation/journey_screen.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

import 'support/journey_screen_overrides.dart';

const _walk = TransportModeRow(id: 1, builtinKey: 'walk', sortOrder: 0);

/// A point [meters] north of 47° N, 11° E.
LatLng _north(double meters) => LatLng(47 + meters / 110574, 11);

final _day = DateTime(2026, 7, 27);

/// A walk the planner laid out, 2 km north from 9:00 to 10:00.
ItineraryItem _plannedWalk({int id = 1, int? groupId = 1, bool plan = true}) =>
    ItineraryItem(
      id: id,
      tripId: 7,
      groupId: groupId,
      date: _day,
      sortOrder: id,
      kind: ItemKind.transport,
      endDayOffset: 0,
      chordDisplay: TrackDisplay.auto,
      startMinutes: 9 * 60,
      endMinutes: 10 * 60,
      mode: _walk.id,
      fromLocation: 'Car park',
      toLocation: 'Hut',
      fromLat: _north(0).latitude,
      fromLon: 11,
      toLat: _north(2000).latitude,
      toLon: 11,
      routePlan: plan
          ? encodeRoutePlan(
              const RoutePlan(
                tour: 't1',
                profile: 'foot',
                waypoints: [
                  RoutePlanPoint(lat: 47, lon: 11),
                  RoutePlanPoint(lat: 47.018, lon: 11),
                ],
              ),
            )
          : null,
    );

PlannedStretch _stretch() => PlannedStretch(
  points: [_north(0), _north(1000), _north(2000)],
  effort: effortAlong(null, [_north(0), _north(1000), _north(2000)], null),
  start: DateTime(2026, 7, 27, 9),
  end: DateTime(2026, 7, 27, 10),
);

final _en = lookupAppLocalizations(const Locale('en'));

void main() {
  group('planStatusText', () {
    String? say(DateTime now, LatLng? at) =>
        planStatusText(_en, [_stretch()], now, at);

    test('says how far behind or ahead, and when that arrives', () {
      expect(
        say(DateTime(2026, 7, 27, 9, 30), _north(500)),
        '15 min behind the plan · arriving about 10:15',
      );
      expect(
        say(DateTime(2026, 7, 27, 9, 30), _north(1500)),
        '15 min ahead of the plan · arriving about 09:45',
      );
      expect(
        say(DateTime(2026, 7, 27, 9, 30), _north(1010)),
        'On plan · arriving about 10:00',
      );
    });

    test('off the line says so, while the route is under way', () {
      final away = LatLng(_north(1000).latitude, 11.01);

      expect(
        say(DateTime(2026, 7, 27, 9, 30), away),
        'Not on the planned route',
      );
      expect(say(DateTime(2026, 7, 27, 10, 30), away), isNull);
    });

    test('without a fix asks for one, while the route is under way', () {
      expect(
        say(DateTime(2026, 7, 27, 9, 30), null),
        "Switch on your location on the map to see whether you're on plan.",
      );
      expect(say(DateTime(2026, 7, 27, 10, 30), null), isNull);
    });

    test('says nothing before the start, or once arrived', () {
      expect(say(DateTime(2026, 7, 27, 8, 59), _north(0)), isNull);
      // Past the end, at the end: arrived.
      expect(say(DateTime(2026, 7, 27, 10, 20), _north(2000)), isNull);
      // Past the end and still on the way: still worth saying.
      expect(
        say(DateTime(2026, 7, 27, 10, 20), _north(1500)),
        startsWith('35 min behind the plan'),
      );
    });
  });

  group('plannedStretches', () {
    test('takes a planned leg with times and its drawn line', () {
      final line = [_north(0), _north(1000), _north(2000)];
      final stretches = plannedStretches(
        [_plannedWalk()],
        {
          1: [
            TrackLine(
              id: 1,
              points: line,
              source: TrackSource.routed,
              encodedElevations: encodeTrackElevations(const [0, 0, 300]),
            ),
          ],
        },
      );

      final stretch = stretches.single;
      expect(stretch.points, line);
      // The same instants, whichever zone they are written in.
      expect(stretch.start.isAtSameMomentAs(DateTime(2026, 7, 27, 9)), isTrue);
      expect(stretch.end.isAtSameMomentAs(DateTime(2026, 7, 27, 10)), isTrue);
      // The climb on the second kilometer weighs, as on foot it should.
      expect(
        stretch.effort[2] - stretch.effort[1],
        greaterThan(stretch.effort[1]),
      );
    });

    test('falls back to the chord, and leaves out what is not planned', () {
      final stretches = plannedStretches([
        _plannedWalk(),
        _plannedWalk(id: 2, plan: false),
      ], const {});

      expect(stretches.single.points, [_north(0), _north(2000)]);
    });
  });

  testWidgets('the journey of a planned route says where to see the plan', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transportModesByIdProvider.overrideWith((ref) => {_walk.id: _walk}),
          ...journeyScreenOverrides(
            tripId: 7,
            items: [_plannedWalk(groupId: null)],
            prefs: prefs,
            now: DateTime(2026, 7, 27, 9, 30),
            tracks: {
              1: [
                TrackLine(
                  id: 1,
                  points: [_north(0), _north(1000), _north(2000)],
                  source: TrackSource.routed,
                ),
              ],
            },
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: JourneyScreen(tripId: 7, itemId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await settleTiles(tester);

    expect(
      find.text(
        "Switch on your location on the map to see whether you're on plan.",
      ),
      findsOneWidget,
    );
    // Where the plan has the walker, on the line.
    expect(find.bySemanticsLabel('Where the plan has you now'), findsOneWidget);
    semantics.dispose();
  });
}
