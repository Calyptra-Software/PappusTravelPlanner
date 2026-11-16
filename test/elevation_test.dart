import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/track_points.dart';
import 'package:travelplanner/features/map/elevation.dart';

void main() {
  group('the height codec', () {
    test('reads back what it wrote, to a tenth of a meter', () {
      const heights = [1848.5, 1846.75, 1846.74, 1171.5, -3.2, 0.0];

      final read = decodeTrackElevations(encodeTrackElevations(heights));

      expect(read, hasLength(heights.length));
      for (final (index, height) in heights.indexed) {
        expect(read[index], closeTo(height, 0.05));
      }
    });

    test('rounding does not add up along the line', () {
      // 0.04 m a step: each rounds to nothing, a thousand of them do not.
      final heights = [for (var i = 0; i <= 1000; i++) i * 0.04];

      final read = decodeTrackElevations(encodeTrackElevations(heights));

      expect(read.last, closeTo(40, 0.05));
    });

    test('a small step costs one character', () {
      expect(encodeTrackElevations(const [0, 1, 2, 3]), hasLength(4));
    });

    test('no heights are an empty string', () {
      expect(encodeTrackElevations(const []), isEmpty);
      expect(decodeTrackElevations(''), isEmpty);
    });

    test('refuses a string that is not one of ours', () {
      expect(() => decodeTrackElevations('\u0001'), throwsFormatException);
    });

    test('heights are read only when there is one per point', () {
      final encoded = encodeTrackElevations(const [10, 20, 30]);

      expect(trackElevationsOrNull(encoded, 3), [10, 20, 30]);
      expect(trackElevationsOrNull(encoded, 4), isNull);
      expect(trackElevationsOrNull(null, 3), isNull);
      expect(trackElevationsOrNull('\u0001', 1), isNull);
    });
  });

  group('climbOf', () {
    test('a steady rise and fall are counted whole', () {
      final climb = climbOf(const [100, 150, 200, 150, 120]);

      expect(climb.ascent, 100);
      expect(climb.descent, 80);
    });

    test('ripples below the threshold are not climbed', () {
      final climb = climbOf(const [100, 104, 99, 105, 100, 103, 98]);

      expect(climb.ascent, 0);
      expect(climb.descent, 0);
    });

    test('a rise made of small steps still counts once it adds up', () {
      final climb = climbOf(const [100, 103, 106, 109, 112]);

      expect(climb.ascent, 9);
      expect(climb.descent, 0);
    });

    test('agrees with the router on the recorded mountain route', () {
      final json =
          jsonDecode(
                File(
                  'test/fixtures/brouter_hiking_mountain.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final coordinates =
          ((json['features'] as List).first as Map)['geometry']['coordinates']
              as List;
      final heights = [
        for (final c in coordinates) ((c as List)[2] as num).toDouble(),
      ];

      final climb = climbOf(heights);

      // The router's own figures for this route: 123 m up, 799 m down.
      expect(climb.ascent, closeTo(123, 5));
      expect(climb.descent, closeTo(799, 5));
    });

    test('no heights are no climb', () {
      expect(climbOf(const []), (ascent: 0.0, descent: 0.0));
      expect(climbOf(const [512]), (ascent: 0.0, descent: 0.0));
    });
  });

  group('elevationProfile', () {
    const points = [LatLng(47, 11), LatLng(47.01, 11), LatLng(47.02, 11)];

    test('puts each height at its distance from the start', () {
      final profile = elevationProfile(points, const [500, 600, 550]);

      expect(profile.map((p) => p.elevation), [500, 600, 550]);
      expect(profile.first.meters, 0);
      expect(profile[1].meters, closeTo(1112, 2));
      expect(profile.last.meters, closeTo(2224, 4));
    });

    test('is empty without a height for every point', () {
      expect(elevationProfile(points, null), isEmpty);
      expect(elevationProfile(points, const [500, 600]), isEmpty);
      expect(elevationProfile(const [LatLng(47, 11)], const [500]), isEmpty);
    });
  });

  group('layProfiles', () {
    test('lays profiles end to end', () {
      final laid = layProfiles([
        (
          profile: [
            (meters: 0, elevation: 500),
            (meters: 1000, elevation: 600),
          ],
          meters: 1000,
        ),
        (
          profile: [(meters: 0, elevation: 600), (meters: 500, elevation: 580)],
          meters: 500,
        ),
      ]);

      expect(laid.stretches, hasLength(2));
      expect(laid.stretches.last.map((p) => p.meters), [1000, 1500]);
      expect(laid.meters, 1500);
      expect(laid.range, (low: 500.0, high: 600.0));
    });

    test('a line without heights is a gap as long as the line', () {
      final laid = layProfiles([
        (
          profile: [
            (meters: 0, elevation: 500),
            (meters: 1000, elevation: 600),
          ],
          meters: 1000,
        ),
        (profile: const [], meters: 700),
        (
          profile: [(meters: 0, elevation: 400), (meters: 300, elevation: 420)],
          meters: 300,
        ),
      ]);

      expect(laid.stretches, hasLength(2));
      expect(laid.stretches.last.first.meters, 1700);
      expect(laid.meters, 2000);
    });

    test('nothing with heights is no profile', () {
      final laid = layProfiles([(profile: const [], meters: 700)]);

      expect(laid.isEmpty, isTrue);
      expect(laid.range, isNull);
      expect(LaidProfile.empty.isEmpty, isTrue);
    });
  });
}
