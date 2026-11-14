import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/clock.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/itinerary/application/itinerary_providers.dart';
import 'package:travelplanner/features/map/map_features.dart';
import 'package:travelplanner/features/map/widgets/map_overlays.dart';
import 'package:travelplanner/features/trips/application/trip_providers.dart';

/// Everything `JourneyScreen` reads, as plain streams: drift's `.watch()` never
/// resolves under the fake-async clock, and `nowProvider` would leave a timer
/// running past the test. Callers add what their own test is about (the modes,
/// a search backend, a database to write to).
List<Override> journeyScreenOverrides({
  required int tripId,
  required List<ItineraryItem> items,
  required SharedPreferences prefs,
  Map<int, ItemGroup> groups = const {},
  TripKind kind = TripKind.trip,
  Trip? trip,
  DateTime? now,
  Map<int, List<TrackLine>> tracks = const {},
}) => [
  // The map's tiles carry the app's version in their User-Agent.
  appVersionProvider.overrideWithValue('0.0.0-test'),
  // The map's style and its locate button read the preferences.
  sharedPreferencesProvider.overrideWithValue(prefs),
  itineraryProvider(tripId).overrideWith((ref) => Stream.value(items)),
  tripProvider(tripId).overrideWith(
    (ref) => Stream.value(
      trip ??
          Trip(
            id: tripId,
            title: 'Trip',
            destination: '',
            colorValue: 0xFF112233,
            coverHidden: false,
            photosCollapsed: false,
            createdAt: DateTime(2026, 5, 1),
            kind: kind,
          ),
    ),
  ),
  groupsProvider(tripId).overrideWith((ref) => Stream.value(groups)),
  alternativeBranchesProvider(
    tripId,
  ).overrideWith((ref) => Stream.value(const {})),
  tripTracksProvider(tripId).overrideWith((ref) => Stream.value(tracks)),
  nowProvider.overrideWith(
    (ref) => Stream.value(now ?? DateTime(2026, 1, 1, 3)),
  ),
];

/// Lets the map's throttled tile loading finish, which otherwise leaves a timer
/// pending when the tree is disposed. It runs once more after firing (the
/// trailing call), hence twice.
Future<void> settleTiles(WidgetTester tester) async {
  await tester.pump(kTileUpdateThrottle);
  await tester.pump(kTileUpdateThrottle);
}
