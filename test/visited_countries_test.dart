import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/map/visited_countries.dart';

/// Reading the bundled country outlines, and asking which of them a trip
/// touched.
///
/// The bundled asset is used rather than a fixture: it is the thing that ships,
/// and a hand-made square would prove only that the arithmetic is arithmetic.
void main() {
  late List<CountryOutline> countries;

  setUpAll(() {
    countries = parseCountryOutlines(
      File('assets/geo/countries.json').readAsStringSync(),
    );
  });

  test('the whole world is there, and reads back', () {
    expect(countries.length, greaterThan(150));
    expect(countries.every((c) => c.polygons.isNotEmpty), isTrue);
    expect(
      countries.every((c) => c.polygons.every((p) => p.first.length >= 4)),
      isTrue,
    );
  });

  test('a country carries a name in each language the app speaks', () {
    final germany = countries.firstWhere((c) => c.code == 'DE');
    expect(germany.name('en'), 'Germany');
    expect(germany.name('de'), 'Deutschland');
    // Anything else falls back to English rather than to nothing.
    expect(germany.name('fr'), 'Germany');
  });

  group('where a point falls', () {
    String? countryOf(LatLng point) {
      final found = visitedCountryCodes(countries, [point]);
      return found.isEmpty ? null : found.single;
    }

    test('cities land in their own countries', () {
      expect(countryOf(const LatLng(53.5511, 9.9937)), 'DE'); // Hamburg
      expect(countryOf(const LatLng(48.8566, 2.3522)), 'FR'); // Paris
      expect(countryOf(const LatLng(-33.8688, 151.2093)), 'AU'); // Sydney
      expect(countryOf(const LatLng(35.6762, 139.6503)), 'JP'); // Tokyo
    });

    test('an enclave is not its neighbour', () {
      // Maseru, in Lesotho, which is a hole in South Africa. Keeping only outer
      // rings would answer ZA here.
      expect(countryOf(const LatLng(-29.31, 27.48)), 'LS');
    });

    test('the open ocean is nowhere, and stays nowhere', () {
      // Not the nearest country: a wrong country is a claim, a missing one is
      // only a gap.
      expect(countryOf(const LatLng(30.0, -40.0)), isNull);
    });

    test('a country reached across the antimeridian is still itself', () {
      // Chukotka, east of 180°, which the source carries as its own landmass.
      expect(countryOf(const LatLng(66.0, -174.0)), 'RU');
    });
  });

  group('which positions count', () {
    ItineraryItem place(double? lat) => ItineraryItem(
      id: 1,
      tripId: 1,
      date: DateTime(2026, 5, 1),
      sortOrder: 0,
      kind: ItemKind.place,
      spansNextDay: false,
      lat: lat,
      lon: lat == null ? null : 9.9937,
    );

    ItineraryItem leg({double? fromLat, double? toLat}) => ItineraryItem(
      id: 2,
      tripId: 1,
      date: DateTime(2026, 5, 1),
      sortOrder: 1,
      kind: ItemKind.transport,
      spansNextDay: false,
      fromLat: fromLat,
      fromLon: fromLat == null ? null : 9.9937,
      toLat: toLat,
      toLon: toLat == null ? null : 12.4964,
    );

    test('a place counts once, a leg at both its ends', () {
      expect(visitedPoints([place(53.5511)]), hasLength(1));
      expect(visitedPoints([leg(fromLat: 53.5, toLat: 41.9)]), hasLength(2));
    });

    test('an entry with no position contributes nothing', () {
      expect(visitedPoints([place(null), leg()]), isEmpty);
    });

    test('half a leg still counts for the half that is placed', () {
      expect(visitedPoints([leg(fromLat: 53.5)]), hasLength(1));
    });

    test('the ground between two ends is not claimed', () {
      // Hamburg to Rome passes over Austria without anybody setting foot in it.
      final points = visitedPoints([leg(fromLat: 53.5511, toLat: 41.9028)]);
      final visited = visitedCountryCodes(countries, points);
      expect(visited, contains('DE'));
      expect(visited, isNot(contains('AT')));
    });
  });

  group('the small countries', () {
    test('are in the set at all, which the coarser outlines were not', () {
      // A 1:110m set leaves every one of these out, so they could be neither
      // drawn nor ticked. This is why the app ships the finer one.
      for (final code in ['MC', 'VA', 'SM', 'LI', 'AD', 'MT', 'SG', 'MV']) {
        expect(
          countries.any((c) => c.code == code),
          isTrue,
          reason: '$code is missing from the set',
        );
      }
    });

    test('are found from a real position, once they are a few km across', () {
      // The simplification's tolerance is scaled to each ring, so a long
      // coastline is thinned while a small country keeps the points it has.
      expect(visitedCountryCodes(countries, [const LatLng(43.9424, 12.4578)]), {
        'SM',
      });
      expect(visitedCountryCodes(countries, [const LatLng(47.1410, 9.5209)]), {
        'LI',
      });
      expect(visitedCountryCodes(countries, [const LatLng(42.5063, 1.5218)]), {
        'AD',
      });
      expect(visitedCountryCodes(countries, [const LatLng(1.3521, 103.8198)]), {
        'SG',
      });
    });

    test('below that, the outline is off the ground it stands for', () {
      // Monaco and the Vatican are about a kilometre across, and the source
      // generalises by more than that: a real position in St Peter's Square
      // falls inside Italy's outline, and one in Monaco falls in the sea. This
      // is recorded rather than worked around — a tolerance wide enough to
      // catch them would be wide enough to mis-attribute every border town, and
      // the honest route for these is the tick box, which is exactly what it is
      // there for.
      expect(visitedCountryCodes(countries, [const LatLng(41.9022, 12.4539)]), {
        'IT',
      });
      expect(
        visitedCountryCodes(countries, [const LatLng(43.7393, 7.4276)]),
        isEmpty,
      );
    });
  });

  group('the tally per region', () {
    test('every country is counted under exactly one region', () {
      final tallies = regionTallies(countries, const {});
      expect(tallies.fold<int>(0, (sum, t) => sum + t.total), countries.length);
      expect(tallies.map((t) => t.region).toSet().length, tallies.length);
    });

    test('the regions read in a fixed order, not in the order of travel', () {
      // A list that reorders itself as you travel is one you have to re-read
      // every time.
      final before = regionTallies(countries, const {}).map((t) => t.region);
      final after = regionTallies(countries, {
        'DE',
        'FR',
        'JP',
      }).map((t) => t.region);
      expect(after, before);
    });

    test('visiting one moves that region and the world, and nothing else', () {
      final tallies = regionTallies(countries, {'DE'});
      final europe = tallies.firstWhere((t) => t.region == 'Europe');
      expect(europe.visited, 1);
      expect(europe.total, greaterThan(40));
      expect(
        tallies.where((t) => t.region != 'Europe').every((t) => t.visited == 0),
        isTrue,
      );
    });

    test(
      'the percentage is rounded for reading, and safe on an empty region',
      () {
        const tally = RegionTally(region: 'Europe', visited: 12, total: 50);
        expect(tally.percent, 24);
        expect(const RegionTally(region: 'X', visited: 0, total: 0).percent, 0);
      },
    );
  });

  test('a dependency is drawn and named, and says it governs nothing', () {
    // Greenland is on the map because a map with holes in it is a worse map,
    // and somebody who has been there should be able to say so.
    final greenland = countries.firstWhere((c) => c.code == 'GL');
    expect(greenland.sovereign, isFalse);
    expect(greenland.region, 'North America');
    expect(countries.firstWhere((c) => c.code == 'DE').sovereign, isTrue);
  });
}
