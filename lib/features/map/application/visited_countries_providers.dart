import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../../itinerary/live_items.dart';
import '../visited_countries.dart';

/// The world's country outlines, read from the bundle once.
///
/// Deliberately **not** `autoDispose`: it is 240 KB of asset and some fifty
/// thousand
/// decoded points, the same for every trip and every launch, and re-reading it
/// each time the statistics screen is opened would be work done for nothing.
final countryOutlinesProvider = FutureProvider<List<CountryOutline>>((
  ref,
) async {
  return parseCountryOutlines(
    await rootBundle.loadString('assets/geo/countries.json'),
  );
});

/// The countries the user marked by hand.
final markedCountriesProvider = StreamProvider.autoDispose<Set<String>>(
  (ref) => ref.watch(repositoryProvider).watchMarkedCountries(),
);

/// Which *areas* a trip's entries stand in, or — with a null trip — every
/// trip's.
///
/// Areas rather than states: this is where somebody stood, and Greenland is not
/// Denmark to a map even though it is to a tally.
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
    return visitedAreaCodes(outlines, visitedPoints(items));
  },
);

/// Everywhere the user has been: what the trips say, plus what they said
/// themselves.
///
/// The two are merged into one set and the map is never told which is which. A
/// life has journeys in it that were never planned in this app, and drawing
/// them in a second shade would be the app quietly disagreeing with the user
/// about their own past. Where the distinction *does* matter is the list, where
/// a mark can be taken back and a derived visit cannot.
///
/// Marks are merged only for the **all-trips** reading. On one trip the question
/// is which countries that trip touched, and a mark says nothing about any
/// particular journey.
final allVisitedCountriesProvider = Provider.autoDispose
    .family<VisitedWorld, int?>((ref, tripId) {
      final outlines = ref.watch(countryOutlinesProvider).value ?? const [];
      final derived = ref.watch(visitedCountriesProvider(tripId));
      final marked = tripId == null
          ? (ref.watch(markedCountriesProvider).value ?? const <String>{})
          : const <String>{};
      return visitedWorld(outlines, derived, marked);
    });
