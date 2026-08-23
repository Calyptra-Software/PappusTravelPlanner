import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/trips/trip_kind.dart';

/// What a trip's kind decides, without a database.
///
/// There is deliberately very little of it. A trip's *scale* is not a kind — a
/// walk is a trip whose start and end are the same day, and the dates say so
/// already — so what is left is the one thing dates cannot say: whether a plan
/// is meant to be used again. The arithmetic below is where that costs
/// something, because a routine has no dates and its days are therefore read as
/// **ranks**.
void main() {
  Trip trip({TripKind kind = TripKind.trip, DateTime? start, DateTime? end}) =>
      Trip(
        id: 1,
        title: 'Rome',
        destination: '',
        kind: kind,
        startDate: start,
        endDate: end,
        colorValue: 0xFF00695C,
        coverHidden: false,
        photosCollapsed: false,
        createdAt: DateTime(2026, 1, 1),
      );

  ItineraryItem item(DateTime date) => ItineraryItem(
    id: 1,
    tripId: 1,
    date: date,
    kind: ItemKind.place,
    sortOrder: 0,
    spansNextDay: false,
  );

  AlternativeSet decision(DateTime date) =>
      AlternativeSet(id: 1, tripId: 1, date: date, sortOrder: 0);

  group('reading a kind off a link', () {
    test('names the kind it spells', () {
      expect(tripKindFromName('routine'), TripKind.routine);
      expect(tripKindFromName('trip'), TripKind.trip);
    });

    test('a stale or hand-typed link opens the ordinary form', () {
      // Falling back rather than failing: the link is somebody's shortcut, and
      // a broken one should still get them to a form.
      expect(tripKindFromName(null), TripKind.trip);
      expect(tripKindFromName(''), TripKind.trip);
      expect(tripKindFromName('holiday'), TripKind.trip);
      expect(tripKindFromName('ROUTINE'), TripKind.trip);
    });
  });

  group('where day one of a plan is', () {
    test('a routine starts at the anchor, never at today', () {
      // Anything else and the plan would scatter across whichever days its
      // entries happened to be written on.
      expect(planAnchorDay(trip(kind: TripKind.routine)), kRoutineAnchorDay);
    });

    test('a dated trip starts on its own first day', () {
      expect(
        planAnchorDay(trip(start: DateTime(2026, 5, 1, 18, 30))),
        DateTime(2026, 5, 1),
      );
    });

    test('an undated trip has none, which is not the same as today', () {
      // An absent range is a deliberate "not decided yet".
      expect(planAnchorDay(trip()), isNull);
    });
  });

  group('the days a routine occupies', () {
    test('are the days its entries sit on, in order and without repeats', () {
      final days = routineDaysOf([
        item(DateTime(1970, 1, 3, 9)),
        item(DateTime(1970, 1, 1, 8)),
        item(DateTime(1970, 1, 1, 17)),
      ], const []);

      expect(days, [DateTime(1970, 1, 1), DateTime(1970, 1, 3)]);
    });

    test('count decisions as well as entries', () {
      final days = routineDaysOf(
        [item(DateTime(1970, 1, 1))],
        [decision(DateTime(1970, 1, 2))],
      );

      expect(days, hasLength(2));
    });

    test('a day with nothing on it is not a day of the plan', () {
      // Gaps close up, which is exactly what the timeline already draws.
      expect(
        routineDayCountOf([
          item(DateTime(1970, 1, 1)),
          item(DateTime(1970, 1, 5)),
        ], const []),
        2,
      );
    });

    test('an empty routine is still a plan for one day', () {
      expect(routineDayCountOf(const [], const []), 1);
    });
  });

  group('stamping a routine onto real dates', () {
    test('day one maps to the start date', () {
      expect(
        routineDayOn(DateTime(2026, 5, 1), kRoutineAnchorDay),
        DateTime(2026, 5, 1),
      );
    });

    test('a later plan day lands the same distance in', () {
      expect(routineDayOffset(DateTime(1970, 1, 3)), 2);
      expect(
        routineDayOn(DateTime(2026, 5, 1), DateTime(1970, 1, 3)),
        DateTime(2026, 5, 3),
      );
    });

    test('the time of day on the anchor never buys an extra day', () {
      expect(routineDayOffset(DateTime(1970, 1, 1, 23, 59)), 0);
    });

    test('a daylight-saving change does not pull day two onto day one', () {
      // Germany springs forward on the last Sunday of March, so the local day
      // is 23 hours long — enough for `Duration`-based arithmetic to lose one.
      expect(
        routineDayOn(DateTime(2026, 3, 28), DateTime(1970, 1, 2)),
        DateTime(2026, 3, 29),
      );
      // And 25 hours the other way, in October.
      expect(
        routineDayOn(DateTime(2026, 10, 24), DateTime(1970, 1, 2)),
        DateTime(2026, 10, 25),
      );
    });

    test('a start date carrying a time is normalized first', () {
      expect(
        routineDayOn(DateTime(2026, 5, 1, 22, 15), DateTime(1970, 1, 2)),
        DateTime(2026, 5, 2),
      );
    });
  });
}
