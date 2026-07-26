import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/features/transport_search/domain/journey_options.dart';
import 'package:travelplanner/features/transport_search/domain/transit_filter.dart';

/// The transport filter a connection search is run with: how the user's
/// categories become MOTIS `transitModes` tokens, and why "everything" sends
/// nothing at all.
void main() {
  group('motisTransitModes', () {
    test('sends nothing when every category is allowed', () {
      expect(motisTransitModes(kAllTransitFilters), isEmpty);
    });

    test('expands a category into the service’s own mode names', () {
      expect(motisTransitModes({TransitFilter.longDistanceRail}), [
        'HIGHSPEED_RAIL',
        'LONG_DISTANCE',
        'NIGHT_RAIL',
      ]);
      expect(motisTransitModes({TransitFilter.bus}), ['BUS', 'COACH']);
    });

    test('keeps category order, whatever order the set was built in', () {
      expect(
        motisTransitModes({TransitFilter.ferry, TransitFilter.regionalRail}),
        ['REGIONAL_RAIL', 'SUBURBAN', 'FERRY'],
      );
    });

    test('"everything except flights" names all the rest', () {
      final modes = motisTransitModes(
        kAllTransitFilters.difference({TransitFilter.air}),
      );
      expect(modes, isNot(contains('AIRPLANE')));
      expect(modes, containsAll(['HIGHSPEED_RAIL', 'BUS', 'FERRY', 'TRAM']));
    });

    test('the categories partition the whole vocabulary — no mode is lost', () {
      final all = <String>{
        for (final filter in TransitFilter.values)
          ...motisTransitModes({filter}),
      };
      // Every category's tokens, together, are what an unrestricted search
      // would allow; each appears under exactly one category.
      final counted = [
        for (final filter in TransitFilter.values)
          ...motisTransitModes({filter}),
      ];
      expect(counted.length, all.length, reason: 'a mode is in two categories');
      expect(all, contains('OTHER'));
      expect(all, contains('AERIAL_LIFT'));
    });
  });

  group('JourneySearchOptions', () {
    test('compares by value, so an equal filter is one cache key', () {
      const a = JourneySearchOptions(
        modes: {TransitFilter.bus, TransitFilter.ferry},
      );
      final b = JourneySearchOptions(
        modes: {TransitFilter.ferry, TransitFilter.bus}, // built differently
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const JourneySearchOptions(modes: {TransitFilter.bus})));
    });

    test('defaults to unrestricted', () {
      expect(const JourneySearchOptions().isUnrestricted, isTrue);
      expect(
        const JourneySearchOptions(modes: {TransitFilter.bus}).isUnrestricted,
        isFalse,
      );
    });
  });
}
