import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/features/route_planner/application/route_pace_provider.dart';
import 'package:travelplanner/features/route_planner/application/tour_planner_controller.dart';
import 'package:travelplanner/features/route_planner/data/saved_tour.dart';
import 'package:travelplanner/features/route_planner/domain/pace.dart';
import 'package:travelplanner/features/route_planner/domain/route_profile.dart';
import 'package:travelplanner/features/route_planner/domain/routed_path.dart';
import 'package:travelplanner/features/route_planner/domain/tour.dart';

import 'support/terrain_overrides.dart';

const _foot = RoutedMode(RouteProfile.foot);

void main() {
  late SharedPreferences prefs;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        noTerrainHeights,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'a pace set is remembered across launches, the average forgotten',
    () async {
      await container()
          .read(rememberedPacesProvider.notifier)
          .remember('foot', Pace.brisk);

      expect(container().read(rememberedPacesProvider), {'foot': Pace.brisk});
      expect(prefs.getString('route_pace_foot'), '1.2');

      await container()
          .read(rememberedPacesProvider.notifier)
          .remember('foot', Pace.average);

      expect(container().read(rememberedPacesProvider), isEmpty);
      expect(prefs.getKeys(), isEmpty);
    },
  );

  test('a stored value that is no pace in range is none', () async {
    await prefs.setString('route_pace_foot', 'sprint');
    await prefs.setString('route_pace_bike', '7');
    await prefs.setString('ski_overpass_server', 'https://example.org');

    expect(container().read(rememberedPacesProvider), isEmpty);
  });

  test(
    'a new tour starts at the paces last set, a saved one at its own',
    () async {
      await prefs.setString('route_pace_foot', '1.2');
      await prefs.setString('route_pace_bike', '0.85');
      final c = container();
      final tour = Tour(
        waypoints: const [
          TourWaypoint(LatLng(47, 11)),
          TourWaypoint(LatLng(47.1, 11)),
        ],
        modes: const [_foot],
      );
      final saved = SavedTour(
        tourId: 't1',
        itemIds: const [],
        groupId: null,
        tour: tour,
        // Its line, so that opening it asks no router.
        paths: {
          runKey(tour, tourRuns(tour).single)!: const RoutedPath(
            points: [LatLng(47, 11), LatLng(47.1, 11)],
            lengthMeters: 11000,
          ),
        },
        paces: const {'foot': Pace.average},
      );
      c.listen(tourPlannerProvider(null), (_, _) {});
      c.listen(tourPlannerProvider(saved), (_, _) {});

      expect(c.read(tourPlannerProvider(null)).paceOf(_foot), Pace.brisk);
      final opened = c.read(tourPlannerProvider(saved));
      expect(opened.paceOf(_foot), Pace.average);
      // A way of travel the tour does not have starts as a new tour would.
      expect(opened.paceOf(const RoutedMode(RouteProfile.bike)), Pace.easy);
    },
  );
}
