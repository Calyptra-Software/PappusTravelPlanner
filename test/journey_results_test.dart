import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/features/transport_search/domain/journey.dart';
import 'package:travelplanner/features/transport_search/domain/transit_mode.dart';

/// Joining loaded time windows together: what merging does to the options, the
/// cursors, and the direct (no-transit) connections that belong to no window.
JourneyOption _option(
  int hour, {
  TransitMode mode = TransitMode.highSpeedRail,
}) {
  final departure = DateTime.utc(2026, 7, 28, hour);
  final arrival = departure.add(const Duration(hours: 1));
  return JourneyOption(
    departure: departure,
    arrival: arrival,
    duration: const Duration(hours: 1),
    transfers: 0,
    legs: [
      JourneyLeg(
        mode: mode,
        from: LegPoint(name: 'A', scheduled: departure),
        to: LegPoint(name: 'B', scheduled: arrival),
        realTime: false,
        line: 'ICE $hour',
      ),
    ],
  );
}

void main() {
  final base = JourneyResults(
    options: [_option(9), _option(10)],
    direct: [_option(9, mode: TransitMode.walk)],
    earlierCursor: 'E0',
    laterCursor: 'L0',
  );

  test('a later window is appended and advances only its own cursor', () {
    final merged = base.merge(
      JourneyResults(options: [_option(11)], laterCursor: 'L1'),
      earlier: false,
    );

    expect(merged.options.map((o) => o.departure.hour), [9, 10, 11]);
    expect(merged.laterCursor, 'L1');
    expect(merged.earlierCursor, 'E0'); // still the edge of what is on screen
  });

  test('an earlier window goes in front', () {
    final merged = base.merge(
      JourneyResults(options: [_option(8)], earlierCursor: 'E1'),
      earlier: true,
    );

    expect(merged.options.map((o) => o.departure.hour), [8, 9, 10]);
    expect(merged.earlierCursor, 'E1');
    expect(merged.laterCursor, 'L0');
  });

  test('an option already on screen is not added twice', () {
    final merged = base.merge(
      JourneyResults(options: [_option(10), _option(11)]),
      earlier: false,
    );

    expect(merged.options.map((o) => o.departure.hour), [9, 10, 11]);
  });

  test('walking the whole way survives paging without being duplicated', () {
    // The service returns direct connections for the first query only, so a
    // paging response carries none — and must not clear the ones already found.
    final merged = base
        .merge(JourneyResults(options: [_option(11)]), earlier: false)
        .merge(JourneyResults(options: [_option(8)]), earlier: true);

    expect(merged.direct, hasLength(1));
    expect(merged.direct.single.legs.single.mode, TransitMode.walk);
  });

  test('a direct connection is picked up if only a later page carries one', () {
    const empty = JourneyResults(options: []);
    final merged = empty.merge(
      JourneyResults(options: const [], direct: [_option(9)]),
      earlier: false,
    );

    expect(merged.direct, hasLength(1));
  });
}
