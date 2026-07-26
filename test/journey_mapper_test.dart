import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/transport_search/data/journey_mapper.dart';
import 'package:travelplanner/features/transport_search/data/motis_parser.dart';
import 'package:travelplanner/features/transport_search/domain/journey.dart';
import 'package:travelplanner/features/transport_search/domain/transit_mode.dart';

// A resolver stub: walk -> 1, anything else -> 6. Keeps the mapper test
// independent of the real TransportModes table.
int? _stubResolve(TransitMode m) => m == TransitMode.walk ? 1 : 6;

JourneyOption _plan(String fixture) => parsePlanResponse(
  jsonDecode(File('test/fixtures/$fixture').readAsStringSync()),
).single;

LegPoint _point(String name, DateTime utc, String? tz) =>
    LegPoint(name: name, scheduled: utc, timeZone: tz);

JourneyOption _oneLeg(JourneyLeg leg) => JourneyOption(
  departure: leg.from.scheduled,
  arrival: leg.to.scheduled,
  duration: leg.to.scheduled.difference(leg.from.scheduled),
  transfers: 0,
  legs: [leg],
);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('journeyToLegs (overnight Hamburg -> Wien fixture)', () {
    test('projects each end into its own zone (Berlin, +2 in July)', () {
      final legs = journeyToLegs(
        _plan('motis_plan_overnight.json'),
        resolveMode: _stubResolve,
      );

      final first = legs.first; // ICE 607, Hamburg 16:34Z -> 18:33Z
      expect(first.date, DateTime(2026, 7, 27));
      expect(first.startMinutes, 18 * 60 + 34); // 16:34Z -> 18:34 Berlin
      expect(first.endMinutes, 20 * 60 + 33); // 18:33Z -> 20:33 Berlin
      expect(first.spansNextDay, isFalse);
      expect(first.title, 'ICE 607');
      expect(first.modeId, 6); // highSpeedRail via stub
    });

    test('the overnight leg is flagged, anchored to its departure day', () {
      final legs = journeyToLegs(
        _plan('motis_plan_overnight.json'),
        resolveMode: _stubResolve,
      );

      // Leg index 2 is the overnight coach: 19:45Z Berlin -> 04:20Z(+1) Vienna.
      final overnight = legs[2];
      expect(overnight.date, DateTime(2026, 7, 27)); // departure day
      expect(overnight.startMinutes, 21 * 60 + 45); // 19:45Z -> 21:45 Berlin
      expect(overnight.endMinutes, 6 * 60 + 20); // 04:20Z -> 06:20 Vienna
      expect(overnight.spansNextDay, isTrue);
    });

    test('every leg maps to a leg (walks included)', () {
      final legs = journeyToLegs(
        _plan('motis_plan_overnight.json'),
        resolveMode: _stubResolve,
      );
      expect(legs, hasLength(6));
      expect(legs[1].modeId, 1); // the walk, via stub
      expect(legs[1].title, isNull); // a walk has no line
    });
  });

  group('journeyToLegs (synthetic zones)', () {
    test('the two ends can sit at different UTC offsets', () {
      // London (BST, +1) -> Berlin (CEST, +2), same UTC hour apart.
      final leg = JourneyLeg(
        mode: TransitMode.highSpeedRail,
        from: _point('London', DateTime.utc(2026, 7, 27, 10), 'Europe/London'),
        to: _point('Berlin', DateTime.utc(2026, 7, 27, 12), 'Europe/Berlin'),
        realTime: false,
      );
      final mapped = journeyToLegs(
        _oneLeg(leg),
        resolveMode: _stubResolve,
      ).single;

      expect(mapped.startMinutes, 11 * 60); // 10:00Z -> 11:00 London
      expect(mapped.endMinutes, 14 * 60); // 12:00Z -> 14:00 Berlin
      expect(mapped.spansNextDay, isFalse);
    });

    test('captures real-time at import when the leg carries it', () {
      final leg = JourneyLeg(
        mode: TransitMode.highSpeedRail,
        from: LegPoint(
          name: 'A',
          scheduled: DateTime.utc(2026, 7, 27, 8),
          actual: DateTime.utc(2026, 7, 27, 8, 5), // +5 min
          timeZone: 'Europe/Berlin',
        ),
        to: LegPoint(
          name: 'B',
          scheduled: DateTime.utc(2026, 7, 27, 10),
          actual: DateTime.utc(2026, 7, 27, 10), // on time
          timeZone: 'Europe/Berlin',
        ),
        realTime: true,
      );
      final mapped = journeyToLegs(
        _oneLeg(leg),
        resolveMode: _stubResolve,
      ).single;
      expect(mapped.startMinutes, 10 * 60); // 08:00Z -> 10:00 Berlin
      expect(mapped.actualStartMinutes, 10 * 60 + 5); // +5
      expect(mapped.actualEndMinutes, 12 * 60); // on time
    });

    test('leaves actual times null for a purely scheduled leg', () {
      final leg = JourneyLeg(
        mode: TransitMode.bus,
        from: _point('A', DateTime.utc(2026, 7, 27, 8), 'Europe/Berlin'),
        to: _point('B', DateTime.utc(2026, 7, 27, 9), 'Europe/Berlin'),
        realTime: false,
      );
      final mapped = journeyToLegs(
        _oneLeg(leg),
        resolveMode: _stubResolve,
      ).single;
      expect(mapped.actualStartMinutes, isNull);
      expect(mapped.actualEndMinutes, isNull);
    });

    test('crossing local midnight sets spansNextDay and next-day minutes', () {
      final leg = JourneyLeg(
        mode: TransitMode.nightRail,
        from: _point('A', DateTime.utc(2026, 7, 27, 21, 30), 'Europe/Berlin'),
        to: _point('B', DateTime.utc(2026, 7, 27, 22, 30), 'Europe/Berlin'),
        realTime: false,
      );
      final mapped = journeyToLegs(
        _oneLeg(leg),
        resolveMode: _stubResolve,
      ).single;

      expect(mapped.date, DateTime(2026, 7, 27));
      expect(mapped.startMinutes, 23 * 60 + 30); // 23:30 Berlin
      expect(mapped.endMinutes, 30); // 00:30 next day
      expect(mapped.spansNextDay, isTrue);
    });

    test('composes notes from direction and platforms (neutral labels)', () {
      final leg = JourneyLeg(
        mode: TransitMode.highSpeedRail,
        from: LegPoint(
          name: 'A',
          scheduled: DateTime.utc(2026, 7, 27, 8),
          timeZone: 'Europe/Berlin',
          track: '5',
        ),
        to: LegPoint(
          name: 'B',
          scheduled: DateTime.utc(2026, 7, 27, 10),
          timeZone: 'Europe/Berlin',
          track: '20',
        ),
        realTime: false,
        line: 'ICE 1',
        headsign: 'München Hbf',
      );
      final mapped = journeyToLegs(
        _oneLeg(leg),
        resolveMode: _stubResolve,
      ).single;

      expect(mapped.title, 'ICE 1'); // train number stays the item title
      expect(mapped.notes, '→ München Hbf · Pl. 5 → Pl. 20');
    });

    test('drops the direction when it just repeats the arrival stop', () {
      final leg = JourneyLeg(
        mode: TransitMode.bus,
        from: LegPoint(
          name: 'A',
          scheduled: DateTime.utc(2026, 7, 27, 8),
          timeZone: 'Europe/Berlin',
        ),
        to: LegPoint(
          name: 'B',
          scheduled: DateTime.utc(2026, 7, 27, 9),
          timeZone: 'Europe/Berlin',
        ),
        realTime: false,
        headsign: 'B', // == arrival stop
      );
      final mapped = journeyToLegs(
        _oneLeg(leg),
        resolveMode: _stubResolve,
      ).single;
      expect(mapped.notes, isNull); // no direction, no platforms
    });

    test('an unknown timezone falls back to UTC rather than throwing', () {
      final leg = JourneyLeg(
        mode: TransitMode.bus,
        from: _point('A', DateTime.utc(2026, 7, 27, 10), 'Not/AZone'),
        to: _point('B', DateTime.utc(2026, 7, 27, 11), null),
        realTime: false,
      );
      final mapped = journeyToLegs(
        _oneLeg(leg),
        resolveMode: _stubResolve,
      ).single;

      expect(mapped.startMinutes, 10 * 60); // treated as UTC
      expect(mapped.endMinutes, 11 * 60);
    });
  });

  group('builtinTransportModeFor', () {
    test('granular rail collapses onto train', () {
      for (final m in [
        TransitMode.rail,
        TransitMode.highSpeedRail,
        TransitMode.longDistanceRail,
        TransitMode.nightRail,
        TransitMode.regionalRail,
        TransitMode.regionalFastRail,
        TransitMode.suburban,
      ]) {
        expect(builtinTransportModeFor(m), TransportMode.train, reason: '$m');
      }
    });

    test('road and water modes', () {
      expect(builtinTransportModeFor(TransitMode.coach), TransportMode.bus);
      expect(builtinTransportModeFor(TransitMode.bus), TransportMode.bus);
      expect(builtinTransportModeFor(TransitMode.tram), TransportMode.tram);
      expect(builtinTransportModeFor(TransitMode.subway), TransportMode.subway);
      expect(builtinTransportModeFor(TransitMode.ferry), TransportMode.ferry);
      expect(builtinTransportModeFor(TransitMode.walk), TransportMode.walk);
    });

    test('modes with no sensible built-in map to null, not other', () {
      expect(builtinTransportModeFor(TransitMode.funicular), isNull);
      expect(builtinTransportModeFor(TransitMode.gondola), isNull);
      expect(builtinTransportModeFor(TransitMode.aerialLift), isNull);
      expect(builtinTransportModeFor(TransitMode.other), isNull);
    });
  });
}
