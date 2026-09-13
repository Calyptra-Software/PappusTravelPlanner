import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../../itinerary/live_items.dart';
import '../../trips/application/stats_trips_provider.dart';
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
/// The all-trips reading is the trips the statistics count ([statsTripsProvider]):
/// the statistics' own filter, never what the overview happens to be filtered
/// to — the map answers "where did I go", this answers "how much have I seen",
/// and an aggregate that moved when a tag chip was tapped on another screen
/// would be answering neither. That is the same side of the split
/// `allTripsStatsProvider` sits on. Routines are not among them — a template is
/// traveled by the trips stamped out of it, not by itself.
final visitedCountriesProvider = Provider.autoDispose.family<Set<String>, int?>(
  (ref, tripId) {
    final outlines = ref.watch(countryOutlinesProvider).value;
    if (outlines == null) return const {};

    final List<ItineraryItem> items;
    if (tripId == null) {
      // One unfiltered stream, narrowed here: a family keyed by the set of
      // trip ids would compare by identity and rebuild on every frame.
      final counted = {
        for (final trip in ref.watch(statsTripsProvider)) trip.id,
      };
      items = [
        for (final item in ref.watch(positionedItemsProvider).value ?? const [])
          if (counted.contains(item.tripId)) item,
      ];
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

/// Whether the countries may be marked by hand: on the all-trips reading, and
/// only while it is of **every** trip.
///
/// A mark is a statement about a life, not about a journey, which is why a
/// single trip's tab never offers one. A filtered set of trips is the same
/// question asked of several journeys — "where did the holidays take me" — so
/// the marks are left out of it and cannot be made there either: a country
/// ticked from a view that does not count ticks would vanish as it was ticked.
final canMarkCountriesProvider = Provider.autoDispose.family<bool, int?>((
  ref,
  tripId,
) {
  return tripId == null && !ref.watch(statsTripQueryProvider).hasActiveFilters;
});

/// Everywhere the user has been: what the trips say, plus what they said
/// themselves.
///
/// The two are merged into one set and the map is never told which is which. A
/// life has journeys in it that were never planned in this app, and drawing
/// them in a second shade would be the app quietly disagreeing with the user
/// about their own past. Where the distinction *does* matter is the list, where
/// a mark can be taken back and a derived visit cannot.
///
/// Marks are merged only where they can be made ([canMarkCountriesProvider]):
/// the all-trips reading, unfiltered. On one trip, or on a filtered few, the
/// question is which countries those journeys touched, and a mark says nothing
/// about any particular journey.
final allVisitedCountriesProvider = Provider.autoDispose
    .family<VisitedWorld, int?>((ref, tripId) {
      final outlines = ref.watch(countryOutlinesProvider).value ?? const [];
      final derived = ref.watch(visitedCountriesProvider(tripId));
      final marked = ref.watch(canMarkCountriesProvider(tripId))
          ? (ref.watch(markedCountriesProvider).value ?? const <String>{})
          : const <String>{};
      return visitedWorld(outlines, derived, marked);
    });
