import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/trips/planned_journey.dart';

/// Which runs of legs in a plan can be *looked up again* — searched afresh for
/// the day they now sit on, so a routine's copied plan becomes a connection
/// that really runs and can be refreshed.
void main() {
  var nextId = 1;
  ItineraryItem leg({
    ItemKind kind = ItemKind.transport,
    int? groupId,
    DateTime? date,
    int sortOrder = 0,
    int? start,
    String? from,
    String? to,
    String? fromPlaceId,
    String? toPlaceId,
    double? fromLat,
    double? fromLon,
    double? toLat,
    double? toLon,
  }) => ItineraryItem(
    id: nextId++,
    tripId: 1,
    date: date ?? DateTime(2026, 8, 3),
    sortOrder: sortOrder,
    kind: kind,
    groupId: groupId,
    startMinutes: start,
    spansNextDay: false,
    fromLocation: from,
    toLocation: to,
    fromPlaceId: fromPlaceId,
    toPlaceId: toPlaceId,
    fromLat: fromLat,
    fromLon: fromLon,
    toLat: toLat,
    toLon: toLon,
  );

  setUp(() => nextId = 1);

  test('a grouped run is one journey, addressed by its outer ends', () {
    final journeys = plannedJourneys([
      leg(
        groupId: 7,
        sortOrder: 0,
        start: 462,
        from: 'Home',
        to: 'Change',
        fromPlaceId: 'stop:home',
      ),
      leg(
        groupId: 7,
        sortOrder: 1,
        start: 475,
        from: 'Change',
        to: 'Office',
        toPlaceId: 'stop:office',
      ),
    ]);

    expect(journeys, hasLength(1));
    final journey = journeys.single;
    expect(journey.groupId, 7);
    expect(journey.legs, hasLength(2));
    // The ends of the *run*, not of either leg: that is the query that produced
    // it, and the one that will find it again.
    expect(journey.fromPlaceId, 'stop:home');
    expect(journey.toPlaceId, 'stop:office');
    expect(journey.departMinutes, 462);
    expect(journey.fromLocation, 'Home');
    expect(journey.toLocation, 'Office');
  });

  test('a lone imported leg is a journey of its own', () {
    final journeys = plannedJourneys([
      leg(start: 462, fromPlaceId: 'stop:a', toPlaceId: 'stop:b'),
    ]);
    expect(journeys, hasLength(1));
    expect(journeys.single.groupId, isNull);
  });

  test('a hand-entered leg cannot be looked up', () {
    // No place ids: there is no query to re-issue, and guessing one from the
    // station's name would be a different journey wearing the same label.
    expect(
      plannedJourneys([leg(start: 462, from: 'Home', to: 'Office')]),
      isEmpty,
    );
  });

  test('a leg with no departure time cannot be looked up either', () {
    expect(
      plannedJourneys([leg(fromPlaceId: 'stop:a', toPlaceId: 'stop:b')]),
      isEmpty,
    );
  });

  test('one end addressed is not enough', () {
    expect(plannedJourneys([leg(start: 462, fromPlaceId: 'stop:a')]), isEmpty);
  });

  test('places are not journeys', () {
    expect(
      plannedJourneys([
        leg(kind: ItemKind.place, start: 540, fromPlaceId: 'x', toPlaceId: 'y'),
      ]),
      isEmpty,
    );
  });

  test('journeys come back in day order, then by departure', () {
    final journeys = plannedJourneys([
      leg(
        date: DateTime(2026, 8, 4),
        start: 500,
        fromPlaceId: 'a',
        toPlaceId: 'b',
      ),
      leg(
        date: DateTime(2026, 8, 3),
        start: 1060,
        fromPlaceId: 'c',
        toPlaceId: 'd',
      ),
      leg(
        date: DateTime(2026, 8, 3),
        start: 462,
        fromPlaceId: 'e',
        toPlaceId: 'f',
      ),
    ]);
    expect(journeys.map((j) => (j.date.day, j.departMinutes)), [
      (3, 462),
      (3, 1060),
      (4, 500),
    ]);
  });

  test('a run reads in its own order, whatever order it arrives in', () {
    final journeys = plannedJourneys([
      leg(
        groupId: 7,
        sortOrder: 1,
        start: 475,
        from: 'Change',
        to: 'Office',
        toPlaceId: 'stop:office',
      ),
      leg(
        groupId: 7,
        sortOrder: 0,
        start: 462,
        from: 'Home',
        to: 'Change',
        fromPlaceId: 'stop:home',
      ),
    ]);
    expect(journeys.single.fromLocation, 'Home');
    expect(journeys.single.toLocation, 'Office');
  });

  group('an end whose id has been lost', () {
    // Straight from a real database: a run whose leading leg was replaced or
    // removed after the import, taking the id the search was issued against
    // with it. The coordinates are still on the leg, and the router takes a
    // coordinate anywhere it takes a stop id.
    test('falls back to the coordinates the leg still carries', () {
      final journeys = plannedJourneys([
        leg(
          groupId: 1,
          sortOrder: 0,
          start: 542,
          from: 'Rahlstedt',
          to: 'Hamburg Hbf',
          fromLat: 53.60486,
          fromLon: 10.154396,
        ),
        leg(
          groupId: 1,
          sortOrder: 1,
          start: 568,
          from: 'Hamburg Hbf',
          to: 'Schlump',
          toPlaceId: 'de-DELFI_de:02000:84903:1:849008',
        ),
      ]);

      expect(journeys, hasLength(1));
      expect(journeys.single.fromPlaceId, '53.60486,10.154396');
      expect(journeys.single.toPlaceId, 'de-DELFI_de:02000:84903:1:849008');
      expect(journeys.single.canLookUp, isTrue);
    });

    test('a stop id is still preferred when there is one', () {
      // Routing from a station's id starts on the platform; routing from its
      // coordinates starts outside it and picks up a walk. The id wins.
      final journeys = plannedJourneys([
        leg(
          start: 542,
          fromPlaceId: 'stop:home',
          fromLat: 53.60486,
          fromLon: 10.154396,
          toPlaceId: 'stop:office',
        ),
      ]);
      expect(journeys.single.fromPlaceId, 'stop:home');
    });

    test('neither an id nor coordinates is still nothing to search', () {
      expect(
        plannedJourneys([leg(start: 542, from: 'Home', to: 'Office')]),
        isEmpty,
      );
    });

    test('half a coordinate is not a coordinate', () {
      expect(
        plannedJourneys([
          leg(start: 542, fromLat: 53.6, toPlaceId: 'stop:office'),
        ]),
        isEmpty,
      );
    });
  });
  group('as the search form holds it', () {
    test('each end carries the string it was searched by, and its name', () {
      final journey = plannedJourneys([
        leg(
          groupId: 3,
          sortOrder: 0,
          start: 452,
          from: 'Rahlstedt',
          to: 'Hamburg Hbf',
          fromPlaceId: 'stop:rahlstedt',
          fromLat: 53.60486,
          fromLon: 10.154396,
        ),
        leg(
          groupId: 3,
          sortOrder: 1,
          start: 488,
          from: 'Hauptbahnhof Nord',
          to: 'Schlump',
          toPlaceId: 'stop:schlump',
        ),
      ]).single;

      // The form shows the names; the query goes out on the ids — the very
      // strings this run was found by, not re-derived from the coordinates.
      expect(journey.fromPlace?.name, 'Rahlstedt');
      expect(journey.fromPlace?.queryId, 'stop:rahlstedt');
      expect(journey.toPlace?.name, 'Schlump');
      expect(journey.toPlace?.queryId, 'stop:schlump');
    });

    test('an end left with only coordinates is addressed by them', () {
      final journey = plannedJourneys([
        leg(
          start: 542,
          from: 'Home',
          fromLat: 53.60486,
          fromLon: 10.154396,
          toPlaceId: 'stop:office',
        ),
      ]).single;

      expect(journey.fromPlace?.queryId, '53.60486,10.154396');
      // Still named for the traveller, coordinates or not.
      expect(journey.fromPlace?.name, 'Home');
    });
  });
  group('the run the user is looking at', () {
    test('a hand-entered run is one, though it cannot be searched alone', () {
      final items = [leg(start: 452, from: 'Rahlstedt', to: 'Hamburg Hbf')];

      // Nothing to issue a query with, so the unattended flow passes it over…
      expect(plannedJourneys(items), isEmpty);
      // …while the form takes it: naming the ends is what the form is for.
      final journey = plannedJourneyOf(items);
      expect(journey, isNotNull);
      expect(journey!.fromLocation, 'Rahlstedt');
      expect(journey.fromPlace, isNull);
      expect(journey.canLookUp, isFalse);
    });

    test('two runs are not one journey', () {
      // The sheet asks about the items of one group or one lone leg; anything
      // else has no single answer, and guessing which would replace the wrong
      // legs.
      expect(
        plannedJourneyOf([
          leg(start: 452, groupId: 1),
          leg(start: 1080, groupId: 2),
        ]),
        isNull,
      );
    });

    test('a day of places is no journey', () {
      expect(plannedJourneyOf([leg(kind: ItemKind.place, start: 540)]), isNull);
    });
  });
  group('when the traveller is really standing there', () {
    /// A leg of one run, with the arrival that was actually recorded on it.
    ItineraryItem inRun({
      required int sortOrder,
      required int start,
      int? actualEnd,
      bool spansNextDay = false,
      DateTime? date,
    }) => ItineraryItem(
      id: nextId++,
      tripId: 1,
      date: date ?? DateTime(2026, 8, 3),
      sortOrder: sortOrder,
      kind: ItemKind.transport,
      groupId: 4,
      startMinutes: start,
      actualEndMinutes: actualEnd,
      spansNextDay: spansNextDay,
    );

    test('the leg before it arriving late is what the next leg asks from', () {
      final first = inRun(sortOrder: 0, start: 452, actualEnd: 484);
      final second = inRun(sortOrder: 1, start: 488);

      // 08:04, not the 08:08 the plan hoped for.
      expect(departureSeedMinutes([first, second], second), 484);
    });

    test('an early arrival counts the same way round', () {
      final first = inRun(sortOrder: 0, start: 452, actualEnd: 462);
      final second = inRun(sortOrder: 1, start: 488);

      // Standing there sooner means an earlier connection is catchable.
      expect(departureSeedMinutes([first, second], second), 462);
    });

    test('the first leg of a run has nothing before it', () {
      final first = inRun(sortOrder: 0, start: 452, actualEnd: 484);
      final second = inRun(sortOrder: 1, start: 488);
      expect(departureSeedMinutes([first, second], first), isNull);
    });

    test('nothing recorded, nothing to prefer over the plan', () {
      final first = inRun(sortOrder: 0, start: 452);
      final second = inRun(sortOrder: 1, start: 488);
      expect(departureSeedMinutes([first, second], second), isNull);
    });

    test('an overnight leg before it is not compared across midnight', () {
      // 23:58 running five late is 00:03 the *next* day; read as minutes on this
      // one it would seed a search for the small hours of the wrong day.
      final first = inRun(
        sortOrder: 0,
        start: 1430,
        actualEnd: 8,
        spansNextDay: true,
      );
      final second = inRun(sortOrder: 1, start: 30);
      expect(departureSeedMinutes([first, second], second), isNull);
    });

    test('a leg on another day is not the leg before it either', () {
      final first = inRun(
        sortOrder: 0,
        start: 452,
        actualEnd: 484,
        date: DateTime(2026, 8, 2),
      );
      final second = inRun(sortOrder: 1, start: 488);
      expect(departureSeedMinutes([first, second], second), isNull);
    });
  });
}
