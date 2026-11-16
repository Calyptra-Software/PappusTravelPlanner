import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/route_plan.dart';

void main() {
  const leg = RoutePlan(
    tour: 't1',
    profile: 'foot',
    waypoints: [
      RoutePlanPoint(lat: 47, lon: 11, name: 'Car park'),
      RoutePlanPoint(lat: 47.05, lon: 11.01),
      RoutePlanPoint(lat: 47.1, lon: 11.02, name: 'Summit', isPlace: true),
    ],
    seconds: 6204,
    meters: 6396,
  );

  test('a leg reads back as it was written', () {
    final read = decodeRoutePlan(encodeRoutePlan(leg))!;

    expect(read.tour, 't1');
    expect(read.profile, 'foot');
    expect(read.straight, isFalse);
    expect(read.isLeg, isTrue);
    expect(read.seconds, 6204);
    expect(read.meters, 6396);
    expect(read.waypoints.map((p) => (p.lat, p.lon, p.name, p.isPlace)), [
      (47.0, 11.0, 'Car park', false),
      (47.05, 11.01, null, false),
      (47.1, 11.02, 'Summit', true),
    ]);
  });

  test('a straight leg keeps the mode it was given', () {
    final read = decodeRoutePlan(
      encodeRoutePlan(
        const RoutePlan(
          tour: 't1',
          straight: true,
          straightMode: 'ski',
          waypoints: [
            RoutePlanPoint(lat: 47.1, lon: 11),
            RoutePlanPoint(lat: 47, lon: 11),
          ],
        ),
      ),
    )!;

    expect(read.straight, isTrue);
    expect(read.straightMode, 'ski');
    expect(read.profile, isNull);
    expect(read.seconds, isNull);
  });

  test('a place keeps only its tour', () {
    final encoded = encodeRoutePlan(const RoutePlan(tour: 't1'));

    expect(encoded, '{"tour":"t1"}');
    final read = decodeRoutePlan(encoded)!;
    expect(read.isLeg, isFalse);
    expect(read.waypoints, isEmpty);
  });

  test('anything that is not a plan reads as none', () {
    expect(decodeRoutePlan(null), isNull);
    expect(decodeRoutePlan(''), isNull);
    expect(decodeRoutePlan('nope'), isNull);
    expect(decodeRoutePlan('[1,2]'), isNull);
    expect(decodeRoutePlan('{"profile":"foot"}'), isNull);
    expect(
      decodeRoutePlan('{"tour":"t","points":[{"lat":47}]}'),
      isNull,
      reason: 'a waypoint without a longitude',
    );
    expect(
      decodeRoutePlan('{"tour":"t","points":[{"lat":470,"lon":11}]}'),
      isNull,
      reason: 'a waypoint outside the world',
    );
  });

  test('reversing turns the waypoints and nothing else', () {
    final back = decodeRoutePlan(reversedRoutePlan(encodeRoutePlan(leg)))!;

    expect(back.waypoints.map((p) => p.name), ['Summit', null, 'Car park']);
    expect(back.waypoints.first.isPlace, isTrue);
    expect(back.profile, 'foot');
    expect(back.tour, 't1');
    expect(back.seconds, 6204);
  });

  test('reversing leaves what it cannot read as it is', () {
    expect(reversedRoutePlan(null), isNull);
    expect(reversedRoutePlan('nope'), 'nope');
  });
}
