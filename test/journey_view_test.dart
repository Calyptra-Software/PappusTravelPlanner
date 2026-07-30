import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/transport_search/data/journey_mapper.dart';
import 'package:travelplanner/features/transport_search/data/journey_view_items.dart';
import 'package:travelplanner/features/transport_search/domain/journey.dart';
import 'package:travelplanner/features/transport_search/domain/transit_mode.dart';
import 'package:travelplanner/features/transport_search/journey_preview.dart';
import 'package:travelplanner/features/transport_search/journey_view.dart';

/// The two ways into one reading: a journey as the router describes it, and the
/// same journey after it has been imported, stored and read back out of the
/// database — with the search out of reach.
///
/// The point of the shared [JourneyView] is that those two agree, so most of
/// what is asserted here is asserted of both at once.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  late AppDatabase db;
  late TripRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
  });
  tearDown(() => db.close());

  /// Minutes past 06:00 UTC on 27 July 2026 — 08:00 in Berlin, where every stop
  /// below is.
  DateTime at(int minutes) =>
      DateTime.utc(2026, 7, 27, 6).add(Duration(minutes: minutes));

  LegPoint point(String name, int minutes, {String? track, int? late}) =>
      LegPoint(
        name: name,
        scheduled: at(minutes),
        actual: late == null ? null : at(minutes + late),
        timeZone: 'Europe/Berlin',
        track: track,
      );

  LegStop stop(
    String name,
    int minutes, {
    int? late,
    bool cancelled = false,
  }) => LegStop(
    name: name,
    scheduledDeparture: at(minutes),
    // A skipped stop is reported with its planned time repeated as the live one
    // — the shape that made the app call it punctual.
    actualDeparture: cancelled
        ? at(minutes)
        : (late == null ? null : at(minutes + late)),
    timeZone: 'Europe/Berlin',
    cancelled: cancelled,
  );

  /// Hamburg → Basel: an ICE calling at three places on the way, an 8-minute
  /// walk across Frankfurt Hbf, then a second ICE.
  JourneyOption journey({int? delay}) {
    final legs = [
      JourneyLeg(
        mode: TransitMode.highSpeedRail,
        line: 'ICE 507',
        headsign: 'München Hbf',
        tripId: 'trip-507',
        from: point('Hamburg Hbf', 0, track: '14'),
        to: point('Frankfurt(Main) Hbf', 110, track: '7', late: delay),
        realTime: delay != null,
        stops: [
          stop('Hannover Hbf', 40, late: delay == null ? null : 12),
          stop('Göttingen', 65),
          stop('Kassel-Wilhelmshöhe', 85),
        ],
      ),
      JourneyLeg(
        mode: TransitMode.walk,
        from: point('Frankfurt(Main) Hbf', 112),
        to: point('Frankfurt(Main) Hbf', 120),
        realTime: false,
      ),
      JourneyLeg(
        mode: TransitMode.highSpeedRail,
        line: 'ICE 71',
        tripId: 'trip-71',
        from: point('Frankfurt(Main) Hbf', 133, track: '3'),
        to: point('Basel SBB', 300),
        realTime: false,
      ),
    ];
    return JourneyOption(
      departure: legs.first.from.scheduled,
      arrival: legs.last.to.scheduled,
      duration: const Duration(minutes: 300),
      transfers: 1,
      legs: legs,
    );
  }

  /// Imports [option] into a fresh trip and reads the journey back off the
  /// database, exactly as the trip's own journey sheet does.
  Future<JourneyView> importAndReadBack(JourneyOption option) async {
    final tripId = await db.tripDao.createTrip(
      TripsCompanion.insert(title: 'T'),
    );
    final modes = await db.transportModeDao.watchModes().first;
    final legs = journeyToLegs(option, resolveMode: modeResolver(modes));
    await repo.insertJourney(tripId, [
      for (final leg in legs) mappedLegToCompanion(tripId, leg),
    ]);
    final items = await db.itineraryDao.watchItemsForTrip(tripId).first;
    return journeyViewFromItems(items, {for (final m in modes) m.id: m});
  }

  test(
    'the walk between two trains is the change, before and after import',
    () async {
      final routed = journeyPreview(journeyViewFromOption(journey()));
      final stored = journeyPreview(await importAndReadBack(journey()));

      for (final rows in [routed, stored]) {
        expect(rows.map((r) => r.runtimeType).toList(), [
          LegRow,
          ChangeRow,
          LegRow,
        ]);
        expect((rows.first as LegRow).leg.line, 'ICE 507');
        expect((rows.last as LegRow).leg.line, 'ICE 71');
        final change = rows[1] as ChangeRow;
        expect(change.place, 'Frankfurt(Main) Hbf');
        expect(change.toPlace, isNull);
        expect(change.minutes, 23);
        expect(change.ownSteamMinutes, 8);
      }
    },
  );

  test(
    'a delay carried in at import shortens the change just the same',
    () async {
      final routed = journeyPreview(journeyViewFromOption(journey(delay: 18)));
      final stored = journeyPreview(
        await importAndReadBack(journey(delay: 18)),
      );

      for (final rows in [routed, stored]) {
        expect((rows[1] as ChangeRow).minutes, 23);
        expect((rows[1] as ChangeRow).actualMinutes, 5);
      }
    },
  );

  test('the stops survive the round trip, with their local times', () async {
    final routed = journeyViewFromOption(journey()).legs.first;
    final stored = (await importAndReadBack(journey())).legs.first;

    for (final leg in [routed, stored]) {
      expect(leg.stops.map((s) => s.name), [
        'Hannover Hbf',
        'Göttingen',
        'Kassel-Wilhelmshöhe',
      ]);
      // 06:40 UTC is 08:40 in Berlin.
      expect(leg.stops.map((s) => s.minutes), [520, 545, 565]);
      expect(leg.stops.every((s) => s.dayOffset == 0), isTrue);
    }
    // The walk between the trains never had any.
    expect(stored.stops, isNotEmpty);
    expect((await importAndReadBack(journey())).legs[1].stops, isEmpty);
  });

  test('a delay already known at import is captured per stop', () async {
    final routed = journeyViewFromOption(journey(delay: 18)).legs.first;
    final stored = (await importAndReadBack(journey(delay: 18))).legs.first;

    for (final leg in [routed, stored]) {
      // Hannover is running 12 late; the two stops after it are the plan alone,
      // and stay silent rather than claiming to be on time.
      expect(leg.stops.map((s) => s.delay), [12, null, null]);
      expect(leg.stops.first.minutes, 520);
    }
  });

  test('a stop the service skips imports as skipped, not on time', () async {
    final option = JourneyOption(
      departure: at(0),
      arrival: at(110),
      duration: const Duration(minutes: 110),
      transfers: 0,
      legs: [
        JourneyLeg(
          mode: TransitMode.highSpeedRail,
          line: 'ICE 507',
          tripId: 'trip-507',
          from: point('Hamburg Hbf', 0, late: 21),
          to: point('Hannover Hbf', 110, late: 45),
          realTime: true,
          stops: [
            stop('Hamburg-Harburg', 15, late: 17),
            stop('Lüneburg', 40, cancelled: true),
            stop('Uelzen', 60, cancelled: true),
          ],
        ),
      ],
    );

    final routed = journeyViewFromOption(option).legs.single;
    final stored = (await importAndReadBack(option)).legs.single;

    for (final leg in [routed, stored]) {
      expect(leg.stops.map((s) => s.cancelled), [false, true, true]);
      // The stop it does call at keeps its delay; the two it drops claim
      // nothing — the repeated planned time is not a promise of punctuality.
      expect(leg.stops.map((s) => s.delay), [17, null, null]);
    }
  });

  test(
    'a stored leg knows which row it is, and what to refresh against',
    () async {
      final stored = await importAndReadBack(journey());

      expect(stored.legs.first.itemId, isNotNull);
      expect(stored.legs.first.sourceTripId, 'trip-507');
      // The walk transfer is nobody's scheduled service: nothing to refresh.
      expect(stored.legs[1].sourceTripId, isNull);
      expect(stored.legs[1].ownSteam, isTrue);
      expect(stored.legs.first.ownSteam, isFalse);
    },
  );

  test(
    'an overnight leg runs forwards, and so does the change after it',
    () async {
      // 22:30 Berlin to 07:15 the next morning, then a 30-minute change.
      final night = JourneyOption(
        departure: at(870),
        arrival: at(1425),
        duration: const Duration(minutes: 555),
        transfers: 1,
        legs: [
          JourneyLeg(
            mode: TransitMode.nightRail,
            line: 'NJ 401',
            from: point('Hamburg Hbf', 870),
            to: point('Zürich HB', 1395),
            realTime: false,
            stops: [stop('Basel SBB', 1320)],
          ),
          JourneyLeg(
            mode: TransitMode.regionalRail,
            line: 'S 12',
            from: point('Zürich HB', 1425),
            to: point('Zug', 1455),
            realTime: false,
          ),
        ],
      );

      final stored = await importAndReadBack(night);
      final rows = journeyPreview(stored);

      final overnight = stored.legs.first;
      expect(overnight.to.date, DateTime(2026, 7, 28));
      expect(overnight.duration, const Duration(minutes: 525));
      // 06:00 Berlin on the following day — the small hours belong to it, not to
      // the day the train left on.
      expect(overnight.stops.single.minutes, 360);
      expect(overnight.stops.single.dayOffset, 1);
      expect((rows[1] as ChangeRow).minutes, 30);
      expect(stored.duration, const Duration(minutes: 585));
    },
  );

  test(
    'a leg nobody timed leaves the change unmeasured rather than wrong',
    () async {
      final tripId = await db.tripDao.createTrip(
        TripsCompanion.insert(title: 'T'),
      );
      final modes = await db.transportModeDao.watchModes().first;
      final train = modes.firstWhere((m) => m.builtinKey == 'train');
      // A hand-entered pair: a taxi with no times at all, then a timed train.
      await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: DateTime(2026, 7, 27),
          kind: ItemKind.transport,
          sortOrder: const Value(0),
          title: const Value('Taxi'),
          fromLocation: const Value('Hotel'),
          toLocation: const Value('Hamburg Hbf'),
        ),
      );
      await db.itineraryDao.addItem(
        ItineraryItemsCompanion.insert(
          tripId: tripId,
          date: DateTime(2026, 7, 27),
          kind: ItemKind.transport,
          sortOrder: const Value(1),
          title: const Value('ICE 1'),
          mode: Value(train.id),
          startMinutes: const Value(600),
          endMinutes: const Value(700),
          fromLocation: const Value('Hamburg Hbf'),
          toLocation: const Value('Berlin Hbf'),
        ),
      );
      final items = await db.itineraryDao.watchItemsForTrip(tripId).first;

      final rows = journeyPreview(
        journeyViewFromItems(items, {for (final m in modes) m.id: m}),
      );

      // Both are services (a taxi with no mode is not "own steam"), so there is a
      // change between them — it just cannot be given a length.
      final change = rows[1] as ChangeRow;
      expect(change.place, 'Hamburg Hbf');
      expect(change.minutes, isNull);
      expect(change.actualMinutes, isNull);
    },
  );
}
