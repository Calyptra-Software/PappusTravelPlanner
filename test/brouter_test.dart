import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/core/app_info.dart';
import 'package:travelplanner/features/route_planner/application/route_engine.dart';
import 'package:travelplanner/features/route_planner/data/brouter_client.dart';
import 'package:travelplanner/features/route_planner/data/brouter_parser.dart';
import 'package:travelplanner/features/route_planner/domain/route_profile.dart';

String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

const _jsonUtf8 = {'content-type': 'application/json; charset=utf-8'};

void main() {
  group('parseBrouterResponse', () {
    // Recorded from brouter.de on 2026-11-16: a mountain hike of 6.4 km.
    final path = parseBrouterResponse(
      jsonDecode(_fixture('brouter_hiking_mountain.json')),
    );

    test('reads the line in travel order, latitude first', () {
      expect(path.points, hasLength(276));
      expect(path.points.first, const LatLng(47.424079, 11.081568));
      expect(path.points.last, const LatLng(47.410394, 11.069267));
    });

    test('keeps a height for every point', () {
      expect(path.elevations, hasLength(276));
      expect(path.elevations!.first, 1848.5);
      expect(path.elevations!.last, 1171.5);
    });

    test('reads the totals, which arrive as strings', () {
      expect(path.lengthMeters, 6396);
      expect(path.ascentMeters, 123);
      // 123 m climbed on a way ending 676 m below its start.
      expect(path.descentMeters, 799);
      expect(path.duration, const Duration(seconds: 6204));
    });

    test('drops the heights when one point has none', () {
      final json = _route([
        [11.0, 47.0, 500],
        [11.1, 47.1],
      ]);
      final parsed = parseBrouterResponse(json);
      expect(parsed.points, hasLength(2));
      expect(parsed.elevations, isNull);
    });

    test('leaves the totals it was not given as null', () {
      final parsed = parseBrouterResponse(
        _route([
          [11.0, 47.0],
          [11.1, 47.1],
        ]),
      );
      expect(parsed.ascentMeters, isNull);
      expect(parsed.descentMeters, isNull);
      expect(parsed.duration, isNull);
    });

    test('refuses an answer that is not a route', () {
      expect(() => parseBrouterResponse('nope'), throwsFormatException);
      expect(
        () => parseBrouterResponse({'features': <Object>[]}),
        throwsFormatException,
      );
      expect(
        () => parseBrouterResponse(
          _route([
            [11.0, 47.0],
          ]),
        ),
        throwsFormatException,
      );
    });
  });

  group('BrouterRouteEngine', () {
    const waypoints = [LatLng(47.422, 11.085), LatLng(47.405, 11.07)];

    test(
      'asks with longitude first, the profile and the app\'s name',
      () async {
        late http.Request sent;
        final engine = BrouterRouteEngine(
          userAgent: buildUserAgent('1.2.3'),
          httpClient: MockClient((request) async {
            sent = request;
            return http.Response(
              _fixture('brouter_hiking_mountain.json'),
              200,
              headers: _jsonUtf8,
            );
          }),
        );

        final path = await engine.route(
          waypoints: waypoints,
          profile: RouteProfile.foot,
        );

        expect(path.points, hasLength(276));
        expect(sent.url.host, 'brouter.de');
        expect(sent.url.path, '/brouter');
        expect(
          sent.url.queryParameters['lonlats'],
          '11.085000,47.422000|11.070000,47.405000',
        );
        expect(sent.url.queryParameters['profile'], 'hiking-mountain');
        expect(sent.url.queryParameters['format'], 'geojson');
        expect(sent.headers['User-Agent'], buildUserAgent('1.2.3'));
      },
    );

    test('names every profile a stock BRouter profile', () {
      expect({
        for (final profile in RouteProfile.values) brouterProfileFor(profile),
      }, hasLength(RouteProfile.values.length));
    });

    test('reports a point the router has no way to as no route', () async {
      final engine = BrouterRouteEngine(
        httpClient: MockClient(
          (_) async => http.Response('datafile W30_N45.rd5 not found\n', 400),
        ),
      );

      await expectLater(
        engine.route(waypoints: waypoints, profile: RouteProfile.bike),
        throwsA(
          isA<RouteEngineException>()
              .having((e) => e.failure, 'failure', RouteEngineFailure.noRoute)
              .having(
                (e) => e.serverMessage,
                'serverMessage',
                'datafile W30_N45.rd5 not found',
              ),
        ),
      );
    });

    test('reports any other refusal as failed', () async {
      final engine = BrouterRouteEngine(
        httpClient: MockClient((_) async => http.Response('', 500)),
      );

      await expectLater(
        engine.route(waypoints: waypoints, profile: RouteProfile.bike),
        throwsA(
          isA<RouteEngineException>()
              .having((e) => e.failure, 'failure', RouteEngineFailure.failed)
              .having((e) => e.serverMessage, 'serverMessage', isNull),
        ),
      );
    });

    test('reports no answer as unreachable', () async {
      final engine = BrouterRouteEngine(
        httpClient: MockClient(
          (_) async => throw http.ClientException('no network'),
        ),
      );

      await expectLater(
        engine.route(waypoints: waypoints, profile: RouteProfile.car),
        throwsA(
          isA<RouteEngineException>().having(
            (e) => e.failure,
            'failure',
            RouteEngineFailure.unreachable,
          ),
        ),
      );
    });

    test('reports an unreadable answer as failed', () async {
      final engine = BrouterRouteEngine(
        httpClient: MockClient(
          (_) async => http.Response('{"features": []}', 200),
        ),
      );

      await expectLater(
        engine.route(waypoints: waypoints, profile: RouteProfile.car),
        throwsA(
          isA<RouteEngineException>().having(
            (e) => e.failure,
            'failure',
            RouteEngineFailure.failed,
          ),
        ),
      );
    });

    test('refuses a single waypoint without asking', () {
      final engine = BrouterRouteEngine(
        httpClient: MockClient((_) async => fail('must not ask')),
      );

      expect(
        () => engine.route(
          waypoints: const [LatLng(47, 11)],
          profile: RouteProfile.foot,
        ),
        throwsArgumentError,
      );
    });
  });
}

Map<String, Object> _route(List<List<num>> coordinates) => {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'properties': {'track-length': '100'},
      'geometry': {'type': 'LineString', 'coordinates': coordinates},
    },
  ],
};
