import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/itinerary/transport_stats.dart';

/// Covers [computeTransportStats]: a trip's legs bucketed by mode, with a leg
/// count and a summed duration per mode on both the planned and actual axes.
void main() {
  final day = DateTime(2026, 7, 5);
  var nextId = 0;

  // A leg stores its mode as a row id now; the built-ins are seeded in enum
  // order, so a mode's id is its enum index + 1 (see `TransportModeDao`). Using
  // the enum here keeps the tests readable.
  int idOf(TransportMode mode) => mode.index + 1;

  ItineraryItem leg(
    TransportMode? mode, {
    DateTime? date,
    int? startMinutes,
    int? endMinutes,
    int? actualStartMinutes,
    int? actualEndMinutes,
  }) => ItineraryItem(
    id: ++nextId,
    tripId: 1,
    date: date ?? day,
    sortOrder: 0,
    kind: ItemKind.transport,
    spansNextDay: false,
    mode: mode == null ? null : idOf(mode),
    startMinutes: startMinutes,
    endMinutes: endMinutes,
    actualStartMinutes: actualStartMinutes,
    actualEndMinutes: actualEndMinutes,
  );

  ItineraryItem place() => ItineraryItem(
    id: ++nextId,
    tripId: 1,
    date: day,
    sortOrder: 0,
    kind: ItemKind.place,
    spansNextDay: false,
    title: 'Somewhere',
  );

  setUp(() => nextId = 0);

  test('empty when there are no legs', () {
    expect(computeTransportStats([]).isEmpty, isTrue);
    expect(computeTransportStats([place()]).isEmpty, isTrue);
  });

  test('buckets by mode with leg counts and summed planned durations', () {
    final stats = computeTransportStats([
      leg(TransportMode.train, startMinutes: 540, endMinutes: 660), // 120
      leg(TransportMode.train, startMinutes: 700, endMinutes: 730), // 30
      leg(TransportMode.walk, startMinutes: 480, endMinutes: 495), // 15
      place(),
    ]);

    expect(stats.byMode, hasLength(2));
    // Train has more legs, so it sorts first.
    final train = stats.byMode.first;
    expect(train.mode, idOf(TransportMode.train));
    expect(train.legs, 2);
    expect(train.plannedMinutes, 150);

    final walk = stats.byMode.last;
    expect(walk.mode, idOf(TransportMode.walk));
    expect(walk.legs, 1);
    expect(walk.plannedMinutes, 15);

    expect(stats.totalLegs, 3);
    expect(stats.totalPlannedMinutes, 165);
  });

  test('actual count and time are measured on their own axis', () {
    final stats = computeTransportStats([
      // Planned and logged: contributes to both counts and both durations.
      leg(
        TransportMode.train,
        startMinutes: 540,
        endMinutes: 600, // planned 60
        actualStartMinutes: 545,
        actualEndMinutes: 620, // actual 75
      ),
      // Planned but not yet logged: planned only.
      leg(
        TransportMode.train,
        startMinutes: 700,
        endMinutes: 730,
      ), // planned 30
    ]);

    final train = stats.byMode.single;
    expect(train.legs, 2);
    expect(train.plannedMinutes, 90);
    // Only one leg has actual times recorded.
    expect(train.actualCount, 1);
    expect(train.actualMinutes, 75);

    expect(stats.totalActualCount, 1);
    expect(stats.totalActualMinutes, 75);
  });

  test('a partial actual time counts the leg but adds no duration', () {
    final stats = computeTransportStats([
      leg(TransportMode.bus, actualStartMinutes: 600), // departed, not arrived
    ]);
    final bus = stats.byMode.single;
    expect(bus.legs, 1);
    expect(bus.actualCount, 1);
    expect(bus.actualMinutes, 0);
  });

  test('legs without a mode are ignored', () {
    final stats = computeTransportStats([
      leg(null, startMinutes: 0, endMinutes: 60),
      leg(TransportMode.bus, startMinutes: 0, endMinutes: 30),
    ]);
    expect(stats.byMode, hasLength(1));
    expect(stats.byMode.single.mode, idOf(TransportMode.bus));
    expect(stats.totalLegs, 1);
  });

  test('a half-open or untimed leg adds no time on its own', () {
    final stats = computeTransportStats([
      leg(TransportMode.car), // no times
      leg(TransportMode.car, startMinutes: 600), // only a start, unbalanced
      leg(TransportMode.car, startMinutes: 100, endMinutes: 145), // 45
    ]);
    final car = stats.byMode.single;
    expect(car.legs, 3);
    // Two starts but one end: unbalanced, so only the fully-timed leg counts.
    expect(car.plannedMinutes, 45);
  });

  test('a journey split around an unplanned stop still counts in full', () {
    // One 09:00–12:00 leg split into a start-only leg and an end-only leg, with
    // an untimed stopover place between them.
    final stats = computeTransportStats([
      leg(TransportMode.train, startMinutes: 540), // departs 09:00
      leg(TransportMode.train, endMinutes: 720), // arrives 12:00
    ]);
    final train = stats.byMode.single;
    expect(train.legs, 2);
    // Balanced across the trip: 12:00 − 09:00 = 180, the stop dropping out.
    expect(train.plannedMinutes, 180);
  });

  test('a leg running past midnight counts its real span', () {
    // Departs 22:00, arrives 06:00 the next morning: 8 hours.
    final stats = computeTransportStats([
      leg(TransportMode.ferry, startMinutes: 1320, endMinutes: 360),
    ]);
    final ferry = stats.byMode.single;
    expect(ferry.legs, 1);
    expect(ferry.plannedMinutes, 480);
  });

  test('a journey split across midnight balances across the trip', () {
    final nextDay = day.add(const Duration(days: 1));
    // Departs 23:00 one day, arrives 06:00 the next — split into two legs.
    final stats = computeTransportStats([
      leg(TransportMode.train, startMinutes: 1380), // 23:00 day 1
      leg(TransportMode.train, date: nextDay, endMinutes: 360), // 06:00 day 2
    ]);
    final train = stats.byMode.single;
    expect(train.plannedMinutes, 420); // 7 hours
  });

  test('ties on leg count break by planned time then enum order', () {
    final stats = computeTransportStats([
      leg(TransportMode.bus, startMinutes: 0, endMinutes: 20), // 20
      leg(TransportMode.train, startMinutes: 0, endMinutes: 60), // 60
    ]);
    // Equal counts (1 each); train has more planned time, so it comes first.
    expect(stats.byMode.map((m) => m.mode), [
      idOf(TransportMode.train),
      idOf(TransportMode.bus),
    ]);
  });

  group('mergeTransportStats', () {
    test('sums each mode across trips and re-sorts', () {
      final a = computeTransportStats([
        leg(TransportMode.train, startMinutes: 0, endMinutes: 60), // 1 leg, 60
        leg(TransportMode.walk, startMinutes: 0, endMinutes: 10), // 1 leg, 10
      ]);
      final b = computeTransportStats([
        leg(TransportMode.walk, startMinutes: 0, endMinutes: 20), // walk
        leg(TransportMode.walk, startMinutes: 0, endMinutes: 30), // walk
      ]);
      final merged = mergeTransportStats([a, b]);

      // Walk now leads on leg count (3 vs 1 train).
      expect(merged.byMode.map((m) => m.mode), [
        idOf(TransportMode.walk),
        idOf(TransportMode.train),
      ]);
      final walk = merged.byMode.first;
      expect(walk.legs, 3);
      expect(walk.plannedMinutes, 60); // 10 + 20 + 30
      expect(merged.totalLegs, 4);
    });

    test('is empty when no trip has any legs', () {
      expect(mergeTransportStats([]).isEmpty, isTrue);
      expect(
        mergeTransportStats([
          const TransportStats([]),
          computeTransportStats([]),
        ]).isEmpty,
        isTrue,
      );
    });
  });
}
