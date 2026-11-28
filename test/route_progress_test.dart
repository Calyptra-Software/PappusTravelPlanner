import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/features/route_planner/domain/pace.dart';
import 'package:travelplanner/features/route_planner/domain/route_profile.dart';
import 'package:travelplanner/features/route_planner/domain/route_progress.dart';

/// A point [meters] north of 47° N, 11° E.
LatLng _north(double meters) => LatLng(47 + meters / 110574, 11);

final _start = DateTime(2026, 11, 27, 9);

/// A walk 2 km north in an hour, at an even pace.
PlannedStretch _walk({
  List<LatLng>? points,
  DateTime? start,
  Duration length = const Duration(hours: 1),
}) {
  final line = points ?? [_north(0), _north(1000), _north(2000)];
  final from = start ?? _start;
  return PlannedStretch(
    points: line,
    effort: effortAlong(null, line, null),
    start: from,
    end: from.add(length),
  );
}

Duration? _behind(PlanProgress? progress) => switch (progress) {
  OnRoute(:final behind) => behind,
  _ => null,
};

void main() {
  test('halfway at half time is on plan', () {
    final progress = progressAgainstPlan(
      [_walk()],
      _north(1000),
      _start.add(const Duration(minutes: 30)),
    );

    expect(_behind(progress)!.inSeconds.abs(), lessThan(5));
    expect(
      (progress! as OnRoute).arrival
          .difference(_start.add(const Duration(hours: 1)))
          .inSeconds
          .abs(),
      lessThan(5),
    );
  });

  test('a quarter of the way at half time is a quarter hour behind', () {
    final progress = progressAgainstPlan(
      [_walk()],
      _north(500),
      _start.add(const Duration(minutes: 30)),
    );

    expect(
      _behind(progress)!.inSeconds,
      closeTo(const Duration(minutes: 15).inSeconds, 5),
    );
    // So the end is reached as much later.
    expect(
      (progress! as OnRoute).arrival,
      _start.add(const Duration(hours: 1)).add(_behind(progress)!),
    );
  });

  test('ahead of the plan is behind by a negative time', () {
    final progress = progressAgainstPlan(
      [_walk()],
      _north(1500),
      _start.add(const Duration(minutes: 30)),
    );

    expect(_behind(progress)!.inMinutes, -15);
  });

  test('a position a little off the line is put on it', () {
    final beside = LatLng(_north(1000).latitude, 11.001); // About 76 m east.

    expect(
      _behind(
        progressAgainstPlan(
          [_walk()],
          beside,
          _start.add(const Duration(minutes: 30)),
        ),
      )!.inSeconds.abs(),
      lessThan(5),
    );
  });

  test('far from every line is off the route, a poor fix reaching further', () {
    final away = LatLng(_north(1000).latitude, 11.003); // About 228 m east.
    final now = _start.add(const Duration(minutes: 30));

    expect(progressAgainstPlan([_walk()], away, now), isA<OffRoute>());
    expect(
      progressAgainstPlan([_walk()], away, now, accuracyMeters: 100),
      isA<OnRoute>(),
    );
  });

  test('out and back on one path is told apart by the time', () {
    // 1 km out and the same 1 km back, an hour in all.
    final line = [_north(0), _north(1000), _north(0)];
    final stretch = _walk(points: line);

    // At 300 m from the start: on the way out a quarter hour in, back at
    // three quarters.
    final out = progressAgainstPlan(
      [stretch],
      _north(300),
      _start.add(const Duration(minutes: 10)),
    );
    final back = progressAgainstPlan(
      [stretch],
      _north(300),
      _start.add(const Duration(minutes: 50)),
    );

    expect(_behind(out)!.inSeconds, closeTo(60, 5)); // Planned at 9 min.
    expect(_behind(back)!.inSeconds, closeTo(-60, 5)); // Planned at 51 min.
  });

  test('a later leg is read on its own times', () {
    final second = _walk(
      points: [_north(2000), _north(3000)],
      start: _start.add(const Duration(hours: 1, minutes: 30)),
      length: const Duration(minutes: 30),
    );

    final progress = progressAgainstPlan(
      [_walk(), second],
      _north(2500),
      _start.add(const Duration(hours: 1, minutes: 50)),
    );

    // Planned at 1:45, the leg's halfway.
    expect(_behind(progress)!.inSeconds, closeTo(5 * 60, 5));
    expect(
      (progress! as OnRoute).arrival.difference(second.end).inSeconds,
      closeTo(5 * 60, 5),
    );
  });

  test('says nothing before the route starts, or without one', () {
    expect(
      progressAgainstPlan(
        [_walk()],
        _north(0),
        _start.subtract(const Duration(minutes: 1)),
      ),
      isNull,
    );
    expect(progressAgainstPlan(const [], _north(0), _start), isNull);
  });

  group('effortAlong', () {
    test('spreads a walk by its climb, a run by its own rule', () {
      final line = [_north(0), _north(1000), _north(2000)];
      // Flat, then 300 m up.
      const heights = [1000.0, 1000.0, 1300.0];

      final walk = effortAlong(RouteProfile.foot, line, heights);
      final run = effortAlong(RouteProfile.run, line, heights);

      // On foot a flat km is a quarter hour, a km with 300 m up an hour more.
      expect(walk[1], closeTo(0.25, 0.01));
      expect(walk[2] - walk[1], closeTo(1.25, 0.01));
      // Running, 1 km is 6 min; 1 km with 300 m up is 3.376 km on the flat.
      expect(run[1], closeTo(0.1, 0.001));
      expect(run[2] - run[1], closeTo(0.3376, 0.001));
    });

    test('is the distance without heights, or for another way of travel', () {
      final line = [_north(0), _north(1000), _north(3000)];

      for (final effort in [
        effortAlong(RouteProfile.foot, line, null),
        effortAlong(RouteProfile.bike, line, const [0, 100, 0]),
        effortAlong(null, line, null),
      ]) {
        expect(effort[2] / effort[1], closeTo(3, 0.01));
      }
    });
  });
}
