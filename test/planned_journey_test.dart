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
}
