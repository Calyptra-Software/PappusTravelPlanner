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

    test('every field counts towards equality — it is the cache key', () {
      const base = JourneySearchOptions();
      expect(base, const JourneySearchOptions());
      expect(base, isNot(const JourneySearchOptions(minTransferMinutes: 10)));
      expect(base, isNot(const JourneySearchOptions(walkingSpeedKmh: 3)));
      expect(base, isNot(const JourneySearchOptions(maxTransfers: 0)));
      expect(base, isNot(const JourneySearchOptions(wheelchair: true)));
      expect(base, isNot(const JourneySearchOptions(byBike: true)));
      expect(base, isNot(const JourneySearchOptions(cyclingSpeedKmh: 22)));
      expect(
        const JourneySearchOptions(byBike: true, bikeOnBoard: true),
        isNot(const JourneySearchOptions(byBike: true)),
      );
      expect(
        const JourneySearchOptions(minTransferMinutes: 10).hashCode,
        const JourneySearchOptions(minTransferMinutes: 10).hashCode,
      );
    });

    test('defaults ask for nothing beyond the service’s own', () {
      expect(const JourneySearchOptions().isDefault, isTrue);
      expect(
        const JourneySearchOptions(modes: {TransitFilter.bus}).isDefault,
        isFalse,
      );
      expect(
        const JourneySearchOptions(minTransferMinutes: 5).isDefault,
        isFalse,
      );
      expect(const JourneySearchOptions(walkingSpeedKmh: 3).isDefault, isFalse);
      expect(const JourneySearchOptions(wheelchair: true).isDefault, isFalse);
      expect(const JourneySearchOptions(byBike: true).isDefault, isFalse);
      expect(
        const JourneySearchOptions(cyclingSpeedKmh: 22).isDefault,
        isFalse,
      );
      // "Direct only" is a restriction, and 0 must not read as "unset".
      expect(const JourneySearchOptions(maxTransfers: 0).isDefault, isFalse);
    });

    test('putting the bike away takes it off the train too', () {
      const withBike = JourneySearchOptions(byBike: true, bikeOnBoard: true);

      // "Comes along" is a claim about a bike you have; dropping the bike must
      // not leave a filter behind that quietly finds nothing.
      expect(withBike.copyWith(byBike: false).bikeOnBoard, isFalse);
      expect(withBike.copyWith(byBike: true).bikeOnBoard, isTrue);
    });

    test('a budget of "automatic" is a value, not a missing one', () {
      const budgeted = JourneySearchOptions(
        maxPreTransitMinutes: 10,
        maxDirectMinutes: 45,
      );

      expect(budgeted.isDefault, isFalse);
      expect(budgeted, isNot(const JourneySearchOptions()));
      // A null argument means "leave it alone" — going back to automatic has
      // to be asked for.
      expect(budgeted.copyWith().maxPreTransitMinutes, 10);
      expect(
        budgeted.copyWith(clearBudgets: true).maxPreTransitMinutes,
        isNull,
      );
      expect(budgeted.copyWith(clearBudgets: true).maxDirectMinutes, isNull);
    });

    test('copyWith can clear the transfer limit, not just change it', () {
      const limited = JourneySearchOptions(maxTransfers: 1);
      expect(limited.copyWith(maxTransfers: 0).maxTransfers, 0);
      expect(limited.copyWith(clearMaxTransfers: true).maxTransfers, isNull);
      // Without the flag, a null argument means "leave it alone".
      expect(limited.copyWith().maxTransfers, 1);
    });
  });
}
