import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/features/map/track_split.dart';

/// Dividing one recording among the entries it covered.
void main() {
  /// A straight run east along the equator, one point every 0.001°, so a
  /// boundary's index and the ground it stands on are the same arithmetic.
  List<LatLng> line(int count) => [
    for (var i = 0; i < count; i++) LatLng(0, i * 0.001),
  ];

  test('nothing to divide is one piece', () {
    final points = line(5);
    expect(splitTrack(points, const []), [points]);
  });

  test('a boundary makes two pieces that share their handover point', () {
    // Shared, so the line has no gap where one entry ends and the next begins.
    final pieces = splitTrack(line(9), [const LatLng(0, 0.004)]);

    expect(pieces, hasLength(2));
    expect(pieces[0].last, pieces[1].first);
    expect(pieces[0].last.longitude, closeTo(0.004, 1e-9));
  });

  test('the pieces put back together are the line that came in', () {
    final points = line(11);
    final pieces = splitTrack(points, [
      const LatLng(0, 0.003),
      const LatLng(0, 0.007),
    ]);

    final rejoined = [
      pieces.first.first,
      for (final piece in pieces) ...piece.skip(1),
    ];
    expect(rejoined, points);
  });

  test(
    'every entry gets points, even on a line barely longer than the plan',
    () {
      // The property that matters: an entry left empty would draw the straight
      // line between its ends the moment somebody gave it coordinates.
      final pieces = splitTrack(line(4), [
        const LatLng(0, 0.001),
        const LatLng(0, 0.002),
      ]);

      expect(pieces, hasLength(3));
      expect(pieces.every((p) => p.length >= 2), isTrue);
    },
  );

  group('a there-and-back route', () {
    // Out along the equator and back over the same ground: every coordinate
    // except the turning point is passed twice.
    final there = [for (var i = 0; i <= 10; i++) LatLng(0, i * 0.001)];
    final back = [for (var i = 9; i >= 0; i--) LatLng(0, i * 0.001)];
    final loop = [...there, ...back];

    test('handovers are found in order, not at the nearest pass', () {
      // Both boundaries name the same place. Read as "nearest point" they would
      // land on the same index and the middle piece would be empty; read as
      // "nearest point after the last one" they are the outward and the return.
      final pieces = splitTrack(loop, [
        const LatLng(0, 0.005),
        const LatLng(0, 0.005),
      ]);

      expect(pieces, hasLength(3));
      expect(pieces.every((p) => p.length >= 2), isTrue);
      // The middle piece is the far half of the walk: out to the turn and back.
      expect(
        pieces[1].map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
        closeTo(0.010, 1e-9),
      );
    });
  });

  group('snapping a tap onto the line', () {
    test('a tap beside the line lands on it', () {
      final points = line(5);
      final snapped = snapToTrack(points, const LatLng(0.0004, 0.00203));
      expect(snapped, points[2]);
    });

    test('it never lands before the handover already placed', () {
      // The same rule the cutting uses, so what the user points at and what the
      // split does cannot disagree.
      final points = line(5);
      final snapped = snapToTrack(points, const LatLng(0, 0), after: 3);
      expect(snapped, points[3]);
    });

    test('a line too short to divide answers nothing', () {
      expect(snapToTrack(const [LatLng(0, 0)], const LatLng(0, 0)), isNull);
    });
  });

  group('a recording that stopped and started again', () {
    test('the hole survives the split', () {
      // Two segments, and one handover inside the second: the entry that spans
      // the pause keeps two lines rather than one drawn across it.
      final first = [for (var i = 0; i < 5; i++) LatLng(0, i * 0.001)];
      final second = [for (var i = 0; i < 5; i++) LatLng(0, 0.010 + i * 0.001)];
      final stretches = splitTracks([first, second], [const LatLng(0, 0.012)]);

      expect(stretches, hasLength(2));
      // The first entry covers all of segment one and the start of segment two.
      expect(stretches[0], hasLength(2));
      expect(stretches[0].first, first);
      // Nothing bridges the gap.
      expect(
        stretches[0][1].first.longitude,
        closeTo(0.010, 1e-9),
        reason: 'the second piece restarts at the second segment',
      );
      expect(stretches[1], hasLength(1));
    });

    test('with nothing to divide, the segments are handed over untouched', () {
      final a = [for (var i = 0; i < 3; i++) LatLng(0, i * 0.001)];
      final b = [for (var i = 0; i < 3; i++) LatLng(0, 0.01 + i * 0.001)];
      expect(splitTracks([a, b], const []), [
        [a, b],
      ]);
    });
  });

  test('a handover moved back stays after the one before it', () {
    // A stretch cannot run backwards, so the bound is what a re-placed handover
    // is clamped by rather than something the user has to remember.
    final points = line(9);
    final snapped = snapToTrack(
      points,
      const LatLng(0, 0),
      after: 5,
      before: 7,
    );
    expect(snapped, points[5]);
  });

  test('and before the one after it', () {
    final points = line(9);
    final snapped = snapToTrack(
      points,
      const LatLng(0, 0.008),
      after: 1,
      before: 3,
    );
    expect(snapped, points[3]);
  });
}
