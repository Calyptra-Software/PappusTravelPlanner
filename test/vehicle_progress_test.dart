import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/stopovers.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/transport_search/vehicle_progress.dart';

/// An ICE from Hamburg (08:00) to Hannover (09:20) on 15 November 2026, calling
/// at Lüneburg, with the rest of its run from Kiel to München around it. The
/// stops' zone is London's rather than Berlin's, so a time read in the device's
/// zone (Berlin, on CI) instead of the stop's cannot pass by accident: 08:00 in
/// London is 08:00Z.
ItineraryItem _leg({
  int? actualStart,
  int? actualEnd,
  List<Stopover>? through,
  RunStops? run = _run,
}) => ItineraryItem(
  id: 1,
  tripId: 7,
  date: DateTime(2026, 11, 15),
  sortOrder: 0,
  kind: ItemKind.transport,
  endDayOffset: 0,
  chordDisplay: TrackDisplay.auto,
  fromLocation: 'Hamburg Hbf',
  toLocation: 'Hannover Hbf',
  fromLat: 53.553,
  fromLon: 10.007,
  toLat: 52.377,
  toLon: 9.741,
  startMinutes: 8 * 60,
  endMinutes: 9 * 60 + 20,
  actualStartMinutes: actualStart,
  actualEndMinutes: actualEnd,
  stopovers: encodeStopovers(
    through ??
        const [
          Stopover(
            name: 'Lüneburg',
            minutes: 8 * 60 + 30,
            dwellMinutes: 2,
            lat: 53.25,
            lon: 10.42,
            timeZone: _zone,
          ),
        ],
  ),
  runStops: run == null ? null : encodeRunStops(run),
);

const _zone = 'Europe/London';

const _run = RunStops(
  before: [
    Stopover(
      name: 'Kiel Hbf',
      minutes: 6 * 60 + 50,
      lat: 54.31,
      lon: 10.13,
      timeZone: _zone,
    ),
    Stopover(
      name: 'Neumünster',
      minutes: 7 * 60 + 20,
      dwellMinutes: 2,
      lat: 54.07,
      lon: 9.98,
      timeZone: _zone,
    ),
  ],
  after: [
    Stopover(
      name: 'Göttingen',
      minutes: 10 * 60,
      dwellMinutes: 2,
      lat: 51.54,
      lon: 9.93,
      timeZone: _zone,
    ),
    Stopover(
      name: 'München Hbf',
      minutes: 13 * 60,
      lat: 48.14,
      lon: 11.56,
      timeZone: _zone,
    ),
  ],
);

/// 15 November 2026 at [hour]:[minute] UTC, which is London's time then.
DateTime _at(int hour, int minute) => DateTime.utc(2026, 11, 15, hour, minute);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('legCalls', () {
    test('lists the run in order, each stop in its own part', () {
      final calls = legCalls(_leg());

      expect(calls.map((c) => c.name), [
        'Kiel Hbf',
        'Neumünster',
        'Hamburg Hbf',
        'Lüneburg',
        'Hannover Hbf',
        'Göttingen',
        'München Hbf',
      ]);
      expect(calls.map((c) => c.part), [
        CallPart.before,
        CallPart.before,
        CallPart.board,
        CallPart.through,
        CallPart.alight,
        CallPart.after,
        CallPart.after,
      ]);
    });

    test('times each stop in its zone, and the ends in their neighbors\'', () {
      final calls = legCalls(_leg());

      // The leg's ends store no zone and take the stops'.
      expect(calls[2].departure, _at(8, 0));
      expect(calls[4].arrival, _at(9, 20));
      // A stop arrives its dwell before it leaves.
      expect(calls[3].arrival, _at(8, 28));
      expect(calls[3].departure, _at(8, 30));
      // The start of the run only leaves, the end only arrives.
      expect(calls.first.arrival, isNull);
      expect(calls.first.departure, _at(6, 50));
      expect(calls.last.arrival, _at(13, 0));
      expect(calls.last.departure, isNull);
    });

    test('moves a stop by its delay, and the ends by their actual times', () {
      final calls = legCalls(
        _leg(
          actualStart: 8 * 60 + 4,
          actualEnd: 9 * 60 + 26,
          through: const [
            Stopover(
              name: 'Lüneburg',
              minutes: 8 * 60 + 30,
              dwellMinutes: 2,
              delayMinutes: 5,
              timeZone: _zone,
            ),
          ],
        ),
      );

      expect(calls[2].departure, _at(8, 4));
      expect(calls[3].arrival, _at(8, 33));
      expect(calls[3].departure, _at(8, 35));
      expect(calls[4].arrival, _at(9, 26));
    });

    test('dates a stop called at the day before boarding', () {
      final calls = legCalls(
        _leg(
          run: const RunStops(
            before: [
              Stopover(
                name: 'Basel SBB',
                minutes: 23 * 60 + 50,
                dayOffset: -1,
                timeZone: _zone,
              ),
            ],
          ),
        ),
      );

      expect(calls.first.departure, DateTime.utc(2026, 11, 14, 23, 50));
    });

    test('has nothing to place on a leg without times', () {
      final untimed = _leg().copyWith(
        startMinutes: const Value(null),
        endMinutes: const Value(null),
      );
      expect(legCalls(untimed), isEmpty);
    });
  });

  test('a zone this build does not know is read as the device\'s', () {
    final calls = legCalls(
      _leg(
        run: null,
        through: const [
          Stopover(name: 'Lüneburg', minutes: 510, timeZone: 'Mars/Olympus'),
        ],
      ),
    );
    expect(calls.first.departure, DateTime(2026, 11, 15, 8).toUtc());
  });

  test('a position reads as what it is', () {
    expect(const AtCall(1), const AtCall(1));
    expect(const AtCall(1).hashCode, const AtCall(1).hashCode);
    expect(const AtCall(1).toString(), 'AtCall(1)');
    expect(
      const BetweenCalls(1, 2, 0.5).hashCode,
      const BetweenCalls(1, 2, 0.5).hashCode,
    );
    expect(const BetweenCalls(1, 2, 0.5).toString(), 'BetweenCalls(1, 2, 0.5)');
  });

  group('progressAt', () {
    late final calls = legCalls(_leg());

    test('is nowhere before the run starts or after it ends', () {
      expect(progressAt(calls, _at(6, 49)), isNull);
      expect(progressAt(calls, _at(13, 0)), isNull);
    });

    test('stands at a stop while it waits there', () {
      expect(progressAt(calls, _at(7, 19)), const AtCall(1));
      expect(progressAt(calls, _at(8, 29)), const AtCall(3));
    });

    test('moves between two stops in proportion to the time', () {
      // Hamburg 08:00 to Lüneburg 08:28: half way at 08:14.
      expect(progressAt(calls, _at(8, 14)), const BetweenCalls(2, 3, 0.5));
    });

    test('counts only the stops it is asked about', () {
      // Lüneburg folded away: the leg runs from 08:00 to 09:20 in one stretch.
      final progress = progressAt(calls, _at(8, 40), include: (i) => i != 3);
      expect(progress, const BetweenCalls(2, 4, 0.5));
    });

    test('ends with the leg when its run beyond is not stored', () {
      final leg = legCalls(_leg(run: null));
      expect(progressAt(leg, _at(7, 59)), isNull);
      expect(progressAt(leg, _at(9, 19)), isA<BetweenCalls>());
      expect(progressAt(leg, _at(9, 20)), isNull);
    });

    test('passes a skipped stop without standing there', () {
      final leg = legCalls(
        _leg(
          run: null,
          through: const [
            Stopover(
              name: 'Lüneburg',
              minutes: 8 * 60 + 30,
              dwellMinutes: 2,
              cancelled: true,
              timeZone: _zone,
            ),
          ],
        ),
      );
      expect(progressAt(leg, _at(8, 29)), isA<BetweenCalls>());
      expect((progressAt(leg, _at(8, 40)) as BetweenCalls).from, 0);
    });

    test('waits rather than going back where the times run backwards', () {
      // Lüneburg's delay is known, Hannover's actual arrival is not: the
      // stop leaves at 09:25, after the planned arrival at 09:20.
      final leg = legCalls(
        _leg(
          run: null,
          through: const [
            Stopover(
              name: 'Lüneburg',
              minutes: 8 * 60 + 30,
              dwellMinutes: 2,
              delayMinutes: 55,
              timeZone: _zone,
            ),
          ],
        ),
      );
      expect(progressAt(leg, _at(9, 24)), const AtCall(1));
      expect(progressAt(leg, _at(9, 25)), isNull);
    });
  });

  group('progressOnLeg', () {
    late final calls = legCalls(_leg());

    test('the leg\'s stretch, and nothing before or after it', () {
      expect(progressOnLeg(calls, const AtCall(2)), isTrue);
      expect(progressOnLeg(calls, const BetweenCalls(3, 4, 0.5)), isTrue);
      expect(progressOnLeg(calls, const BetweenCalls(1, 2, 0.5)), isFalse);
      expect(progressOnLeg(calls, const AtCall(5)), isFalse);
    });
  });

  group('stopsUntilBoarding', () {
    late final calls = legCalls(_leg());

    test('counts the calls left up to the boarding one', () {
      expect(stopsUntilBoarding(calls, const BetweenCalls(0, 1, 0.5)), 2);
      expect(stopsUntilBoarding(calls, const AtCall(1)), 1);
      expect(stopsUntilBoarding(calls, const BetweenCalls(1, 2, 0.9)), 1);
    });

    test('says nothing once the vehicle is there or past it', () {
      expect(stopsUntilBoarding(calls, const AtCall(2)), isNull);
      expect(stopsUntilBoarding(calls, const BetweenCalls(2, 3, 0.1)), isNull);
    });
  });

  group('VehicleRoute', () {
    // A route due south from Hamburg with a bend before Lüneburg.
    const hamburg = LatLng(53.553, 10.007);
    const bend = LatLng(53.4, 10.007);
    const lueneburg = LatLng(53.25, 10.42);
    const hannover = LatLng(52.377, 9.741);
    late final calls = legCalls(_leg(run: null));

    test('places a waiting vehicle on its stop', () {
      final route = VehicleRoute(calls, const [hamburg, bend, lueneburg]);
      expect(route.pointOf(const AtCall(1)), lueneburg);
    });

    test('puts a moving one along the line, by distance', () {
      final route = VehicleRoute(calls, const [
        hamburg,
        bend,
        lueneburg,
        hannover,
      ]);
      final first = route.pointOf(const BetweenCalls(0, 1, 0.01))!;
      // Early on the way it is on the first straight, due south of Hamburg.
      expect(first.longitude, closeTo(hamburg.longitude, 1e-9));
      expect(first.latitude, lessThan(hamburg.latitude));
      final late = route.pointOf(const BetweenCalls(0, 1, 0.99))!;
      // Late on the way it is past the bend, heading east to Lüneburg.
      expect(late.longitude, greaterThan(bend.longitude));
    });

    test('says which calls it has a place for', () {
      final run = legCalls(_leg());
      final route = VehicleRoute(run, const [
        hamburg,
        lueneburg,
        hannover,
      ], covers: (call) => call.part.onLeg);
      expect(
        [for (var i = 0; i < run.length; i++) route.places(i)],
        [false, false, true, true, true, false, false],
      );
    });

    test('places nothing on a stretch the route does not reach', () {
      final run = legCalls(_leg());
      final route = VehicleRoute(run, const [
        hamburg,
        lueneburg,
        hannover,
      ], covers: (call) => call.part.onLeg);
      expect(route.pointOf(const BetweenCalls(1, 2, 0.5)), isNull);
      expect(route.pointOf(const BetweenCalls(2, 3, 0.5)), isNotNull);
    });
  });
}
