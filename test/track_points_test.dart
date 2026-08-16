import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/track_points.dart';

/// The packing that lets a track live in a column.
void main() {
  test('a track survives the round trip to within its precision', () {
    final track = [
      const LatLng(53.55110, 9.99370),
      const LatLng(53.55131, 9.99402),
      const LatLng(53.55009, 9.99511),
      const LatLng(-33.86880, 151.20930),
    ];

    final decoded = decodeTrackPoints(encodeTrackPoints(track));

    expect(decoded, hasLength(track.length));
    for (var i = 0; i < track.length; i++) {
      expect(decoded[i].latitude, closeTo(track[i].latitude, 1 / 100000));
      expect(decoded[i].longitude, closeTo(track[i].longitude, 1 / 100000));
    }
  });

  test('it is the format every mapping tool already reads', () {
    // The worked example from Google's own description of the encoding, so a
    // change here that quietly invents a private dialect is caught.
    const known = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
    final points = decodeTrackPoints(known);
    expect(points, hasLength(3));
    expect(points[0].latitude, closeTo(38.5, 1e-5));
    expect(points[0].longitude, closeTo(-120.2, 1e-5));
    expect(points[2].latitude, closeTo(43.252, 1e-5));
    expect(points[2].longitude, closeTo(-126.453, 1e-5));
    expect(encodeTrackPoints(points), known);
  });

  test('an empty track packs to nothing and back', () {
    expect(encodeTrackPoints(const []), '');
    expect(decodeTrackPoints(''), isEmpty);
  });

  test(
    'rounding is measured against what was written, so a line cannot drift',
    () {
      // Each step is half a unit of precision — the case where rounding the
      // *original* rather than the stored value would accumulate.
      final creeping = [
        for (var i = 0; i < 400; i++) LatLng(53.5 + i * 0.000005, 9.9),
      ];
      final decoded = decodeTrackPoints(encodeTrackPoints(creeping));
      expect(
        decoded.last.latitude,
        closeTo(creeping.last.latitude, 1 / 100000),
      );
    },
  );

  group('a string from outside is not trusted', () {
    test('a truncated point is rejected, not half-read', () {
      // A run of continuation characters with nothing to finish it.
      expect(() => decodeTrackPoints('_p~iF~ps|U_ul'), throwsFormatException);
    });

    test('a character below the encoding is rejected', () {
      // Everything the encoding writes is at or above '?' (63). A '!' is not
      // ours, and read as a negative digit it would shift a coordinate about.
      expect(() => decodeTrackPoints('!!'), throwsFormatException);
      expect(() => decodeTrackPoints('_p~iF~ps|U!!'), throwsFormatException);
    });

    test('a coordinate off the world is rejected', () {
      // Reachable only from a corrupt or foreign string: the encoder cannot
      // produce it from a `LatLng`.
      expect(
        () => decodeTrackPoints('_______@_______@'),
        throwsFormatException,
      );
    });
  });

  test('a string is meaningless without the precision it was written at', () {
    // The routing service answers at 1e-6; our column stores 1e-5. The same
    // characters then mean a tenth of the distance — which is not a small
    // error, it is a line off the coast that still looks like data.
    const routed = '_p~iF~ps|U';
    final ours = decodeTrackPoints(routed);
    final theirs = decodeTrackPoints(routed, precision: kRoutedShapePrecision);

    expect(ours.single.latitude, closeTo(38.5, 1e-5));
    expect(theirs.single.latitude, closeTo(3.85, 1e-5));
    expect(theirs.single.latitude * 10, closeTo(ours.single.latitude, 1e-4));
  });
}
