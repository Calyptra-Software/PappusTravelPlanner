import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../../itinerary/live_items.dart';
import '../visited_countries.dart';

/// The world's country outlines, read from the bundle once.
///
/// Deliberately **not** `autoDispose`: it is 61 KB of asset and a few thousand
/// decoded points, the same for every trip and every launch, and re-reading it
/// each time the statistics screen is opened would be work done for nothing.
final countryOutlinesProvider = FutureProvider<List<CountryOutline>>((
  ref,
) async {
  return parseCountryOutlines(
    await rootBundle.loadString('assets/geo/countries.json'),
  );
});

/// Which countries a trip's entries stand in, or — with a null trip — every
/// trip's.
///
/// The all-trips reading is the **whole record**, not what the overview happens
/// to be filtered to: the map answers "where did I go", this answers "how much
/// have I seen", and an aggregate that moved when a tag chip was tapped would be
/// answering neither. That is the same side of the split `allTripsStatsProvider`
/// already sits on.
final visitedCountriesProvider = Provider.autoDispose.family<Set<String>, int?>(
  (ref, tripId) {
    final outlines = ref.watch(countryOutlinesProvider).value;
    if (outlines == null) return const {};

    final List<ItineraryItem> items;
    if (tripId == null) {
      items = ref.watch(positionedItemsProvider).value ?? const [];
    } else {
      // A single trip reads through the live rule, as everything about one trip
      // does: an option nobody chose is a road not taken, and it did not take
      // anybody to a country either. The cross-trip query applies the same rule
      // in SQL, so it needs no filtering here.
      final all = ref.watch(itineraryProvider(tripId)).value ?? const [];
      items = liveItems(all, ref.watch(chosenBranchIdsProvider(tripId)));
    }
    return visitedCountryCodes(outlines, visitedPoints(items));
  },
);
