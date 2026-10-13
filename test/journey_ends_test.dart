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

  group('a walk to nowhere at a coordinate end', () {
    // Farmsen's platform, and the query issued from exactly that point — what
    // searching one leg of an imported run again sends.
    const lat = 53.607147;
    const lon = 10.117572;
    LegPoint at(String name, DateTime utc, {String? stopId, double? dLat}) =>
        LegPoint(
          name: name,
          scheduled: utc,
          stopId: stopId,
          lat: lat + (dLat ?? 0),
          lon: lon,
          timeZone: stopId == null ? null : 'Europe/Berlin',
        );
    final t3 = DateTime.utc(2026, 8, 19, 7, 51);

    test('is dropped at either end, and the times follow the legs left', () {
      final start = DateTime.utc(2026, 8, 19, 7, 29);
      final train = _leg(
        at('Farmsen', t0, stopId: 'farmsen'),
        LegPoint(
          name: 'Jungfernstieg',
          scheduled: t2,
          stopId: 'jungfernstieg',
          lat: 53.552425,
          lon: 9.993695,
          timeZone: 'Europe/Berlin',
        ),
        mode: TransitMode.subway,
      );
      final option = resolvedOptionEnds(
        _option([
          _leg(at('START', start), at('Farmsen', t0, stopId: 'farmsen')),
          train,
          _leg(
            LegPoint(
              name: 'Jungfernstieg',
              scheduled: t2,
              stopId: 'jungfernstieg',
              lat: 53.552425,
              lon: 9.993695,
            ),
            LegPoint(name: 'END', scheduled: t3, lat: 53.552425, lon: 9.993695),
          ),
        ]),
        fromName: 'Farmsen',
        toName: 'Jungfernstieg',
      );

      expect(option.legs, hasLength(1));
      expect(option.legs.single.mode, TransitMode.subway);
      expect(option.departure, t0);
      expect(option.arrival, t2);
      expect(option.duration, t2.difference(t0));
      // The stop names its own end; nothing is left to rename.
      expect(option.legs.single.from.name, 'Farmsen');
    });

    test('a walk that goes somewhere stays', () {
      // About 30 m north: a first mile, however short, is still a way to go.
      final option = resolvedOptionEnds(
        _option([
          _leg(at('START', t0, dLat: 0.0003), at('Farmsen', t1, stopId: 'f')),
          _leg(
            at('Farmsen', t1, stopId: 'f'),
            _stop('Jungfernstieg', t2),
            mode: TransitMode.subway,
          ),
        ]),
        fromName: 'Home',
      );
      expect(option.legs, hasLength(2));
      expect(option.legs.first.from.name, 'Home');
    });

    test('a change between two stops on one spot is still a change', () {
      // Only a coordinate end goes nowhere; both ends of this one are stops.
      final option = resolvedOptionEnds(
        _option([
          _leg(
            at('Farmsen', t0, stopId: 'bus'),
            at('Farmsen', t1, stopId: 'u'),
          ),
          _leg(
            at('Farmsen', t1, stopId: 'u'),
            _stop('Jungfernstieg', t2),
            mode: TransitMode.subway,
          ),
        ]),
      );
      expect(option.legs, hasLength(2));
    });

    test('a journey of nothing but that walk is left whole', () {
      final option = resolvedOptionEnds(
        _option([_leg(at('START', t0), at('END', t1))]),
      );
      expect(option.legs, hasLength(1));
    });
  });
}
