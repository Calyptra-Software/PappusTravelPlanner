import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/features/transport_search/domain/journey.dart';
import 'package:travelplanner/features/transport_search/domain/journey_ends.dart';
import 'package:travelplanner/features/transport_search/domain/transit_mode.dart';

/// An end the router answered as a real stop: named, zoned, with a `stopId`.
LegPoint _stop(String name, DateTime utc, {String zone = 'Europe/Berlin'}) =>
    LegPoint(name: name, scheduled: utc, stopId: 'de-$name', timeZone: zone);

/// An end the query addressed by coordinate: the placeholder name, no `stopId`,
/// and no timezone at all — exactly what Transitous returns for one.
LegPoint _coordinate(String placeholder, DateTime utc) =>
    LegPoint(name: placeholder, scheduled: utc);

JourneyLeg _leg(
  LegPoint from,
  LegPoint to, {
  TransitMode mode = TransitMode.walk,
}) => JourneyLeg(mode: mode, from: from, to: to, realTime: false);

JourneyOption _option(List<JourneyLeg> legs) => JourneyOption(
  departure: legs.first.from.scheduled,
  arrival: legs.last.to.scheduled,
  duration: legs.last.to.scheduled.difference(legs.first.from.scheduled),
  transfers: legs.length - 1,
  legs: legs,
);

void main() {
  final t0 = DateTime.utc(2026, 8, 19, 7, 30);
  final t1 = DateTime.utc(2026, 8, 19, 7, 38);
  final t2 = DateTime.utc(2026, 8, 19, 7, 50);

  group('names', () {
    test('an end with no stop takes the name the search was issued with', () {
      final option = resolvedOptionEnds(
        _option([_leg(_coordinate('START', t0), _coordinate('END', t1))]),
        fromName: 'Schlump',
        toName: 'Geomatikum',
      );

      expect(option.legs.single.from.name, 'Schlump');
      expect(option.legs.single.to.name, 'Geomatikum');
    });

    test('an end that is a stop keeps the stop\'s own name', () {
      // The station knows better than the query: "Hamburg Hbf" against whatever
      // the user typed to find it.
      final option = resolvedOptionEnds(
        _option([_leg(_stop('Hamburg Hbf', t0), _coordinate('END', t1))]),
        fromName: 'Hamburg',
        toName: 'Geomatikum',
      );

      expect(option.legs.single.from.name, 'Hamburg Hbf');
      expect(option.legs.single.to.name, 'Geomatikum');
    });

    test('only the run\'s outer ends are renamed', () {
      // The stations in between are changes the router named itself, and the
      // search has no name to offer for them in any case.
      final option = resolvedOptionEnds(
        _option([
          _leg(_coordinate('START', t0), _stop('Hamburg Hbf', t1)),
          _leg(_stop('Hamburg Hbf', t1), _coordinate('END', t2)),
        ]),
        fromName: 'Rahlstedt',
        toName: 'Geomatikum',
      );

      expect(option.legs.first.from.name, 'Rahlstedt');
      expect(option.legs.first.to.name, 'Hamburg Hbf');
      expect(option.legs.last.from.name, 'Hamburg Hbf');
      expect(option.legs.last.to.name, 'Geomatikum');
    });

    test('with no name to offer the placeholder is left as it came', () {
      final option = resolvedOptionEnds(
        _option([_leg(_coordinate('START', t0), _coordinate('END', t1))]),
      );

      expect(option.legs.single.from.name, 'START');
    });
  });

  group('zones', () {
    test('an unzoned end takes the zone of the stop next to it', () {
      // The door-to-door shape: walk from a coordinate to the station, train on.
      final option = resolvedOptionEnds(
        _option([
          _leg(_coordinate('START', t0), _stop('Hamburg Hbf', t1)),
          _leg(
            _stop('Hamburg Hbf', t1),
            _coordinate('END', t2),
            mode: TransitMode.regionalRail,
          ),
        ]),
      );

      expect(option.legs.first.from.timeZone, 'Europe/Berlin');
      expect(option.legs.last.to.timeZone, 'Europe/Berlin');
    });

    test('the nearest zone wins, so a journey abroad ends in its own', () {
      final option = resolvedOptionEnds(
        _option([
          _leg(_coordinate('START', t0), _stop('Hamburg', t1)),
          _leg(
            _stop('Hamburg', t1),
            _stop('London', t2, zone: 'Europe/London'),
            mode: TransitMode.highSpeedRail,
          ),
          _leg(
            _stop('London', t2, zone: 'Europe/London'),
            _coordinate('END', t2),
          ),
        ]),
      );

      expect(option.legs.first.from.timeZone, 'Europe/Berlin');
      expect(option.legs.last.to.timeZone, 'Europe/London');
    });

    test('a zone the router did give is never overwritten', () {
      final option = resolvedOptionEnds(
        _option([
          _leg(
            _stop('Hamburg', t0),
            _stop('London', t1, zone: 'Europe/London'),
            mode: TransitMode.highSpeedRail,
          ),
        ]),
      );

      expect(option.legs.single.from.timeZone, 'Europe/Berlin');
      expect(option.legs.single.to.timeZone, 'Europe/London');
    });

    test('a walk between two coordinates has no zone to borrow', () {
      // Nothing in the answer is zoned, so both ends stay null and `localParts`
      // reads them in the device's own zone — never as UTC.
      final option = resolvedOptionEnds(
        _option([_leg(_coordinate('START', t0), _coordinate('END', t1))]),
        fromName: 'Schlump',
        toName: 'Geomatikum',
      );

      expect(option.legs.single.from.timeZone, isNull);
      expect(option.legs.single.to.timeZone, isNull);
    });
  });

  test('resolvedEnds covers the direct options too', () {
    // A short hop comes back *only* as a direct walk — the case this whole
    // repair exists for — so results resolved option-by-option would miss it.
    final walk = _option([
      _leg(_coordinate('START', t0), _coordinate('END', t1)),
    ]);
    final results = resolvedEnds(
      JourneyResults(options: const [], direct: [walk], laterCursor: 'c'),
      fromName: 'Schlump',
      toName: 'Geomatikum',
    );

    expect(results.direct.single.legs.single.from.name, 'Schlump');
    expect(results.laterCursor, 'c'); // the cursors ride through untouched
  });
}
