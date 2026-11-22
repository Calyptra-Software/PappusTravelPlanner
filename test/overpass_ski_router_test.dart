import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/core/cache_files.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/route_planner/application/route_engine.dart';
import 'package:travelplanner/features/route_planner/application/terrain_heights.dart';
import 'package:travelplanner/features/route_planner/data/ski/overpass_client.dart';
import 'package:travelplanner/features/route_planner/data/ski/overpass_ski_router.dart';
import 'package:travelplanner/features/route_planner/domain/piste_difficulty.dart';
import 'package:travelplanner/features/route_planner/domain/routed_path.dart';

/// [CacheFiles] in memory.
class _MemoryFiles implements CacheFiles {
  final files = <String, String>{};

  @override
  Future<String?> read(String key) async => files[key];

  @override
  Future<void> write(String key, String content) async => files[key] = content;

  @override
  Future<List<String>> keys() async => files.keys.toList();

  @override
  Future<void> delete(String key) async => files.remove(key);
}

/// [TerrainHeights] from a function of the point, or none at all.
class _FakeHeights implements TerrainHeights {
  _FakeHeights(this.height);

  final double Function(LatLng point)? height;
  final asked = <List<LatLng>>[];

  @override
  Future<List<double>?> at(List<LatLng> points) async {
    asked.add(points);
    final height = this.height;
    return height == null ? null : [for (final p in points) height(p)];
  }
}

// Recorded once on 2026-11-21. Map data © OpenStreetMap contributors, ODbL.
final String _garmisch = File(
  'test/fixtures/overpass_garmisch_classic.json',
).readAsStringSync();

const _kreuzeckValley = LatLng(47.4715, 11.0637);

/// What a run that is not the point of a test answers with.
final _dummy = RoutedPath(points: const [], lengthMeters: 0);
const _hausbergValley = LatLng(47.4818, 11.0947);

Matcher _refusedAs(RouteEngineFailure failure) => throwsA(
  isA<RouteEngineException>().having((e) => e.failure, 'failure', failure),
);

void main() {
  late List<http.Request> requests;
  late http.Response Function(http.Request request) answer;
  late _MemoryFiles files;
  late DateTime now;

  setUp(() {
    requests = [];
    answer = (_) => http.Response.bytes(utf8.encode(_garmisch), 200);
    files = _MemoryFiles();
    now = DateTime(2026, 11, 21);
  });

  OverpassSkiRouter router({bool withFiles = true, TerrainHeights? heights}) =>
      OverpassSkiRouter(
        OverpassClient(
          httpClient: MockClient((request) async {
            requests.add(request);
            return answer(request);
          }),
          userAgent: 'Test/1.0',
        ),
        heights: heights,
        files: Future.value(withFiles ? files : null),
        now: () => now,
      );

  Future<RoutedPath> route(OverpassSkiRouter router) => router.route(
    waypoints: const [_kreuzeckValley, _hausbergValley],
    maxDifficulty: PisteDifficulty.standard,
  );

  group('OverpassClient', () {
    test('posts the query as a form field and names the app', () async {
      await route(router());

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url, kOverpassUrl);
      expect(request.headers['User-Agent'], 'Test/1.0');
      final query = Uri.splitQueryString(request.body)['data']!;
      expect(query, startsWith('[out:json]'));
      expect(query, contains('[bbox:'));
    });

    test('leaves the User-Agent out where told to', () async {
      final client = OverpassClient(
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 200);
        }),
        sendUserAgent: false,
      );

      await client.run('[out:json];');

      expect(requests.single.headers, isNot(contains('User-Agent')));
    });

    test('a refusal keeps its status, and a busy server says so', () async {
      answer = (_) => http.Response('rate_limited', 429);

      await expectLater(route(router()), _refusedAs(RouteEngineFailure.busy));
    });

    test('no answer at all is unreachable', () async {
      final client = OverpassClient(
        httpClient: MockClient((_) async => throw http.ClientException('off')),
      );

      await expectLater(
        client.run('[out:json];'),
        _refusedAs(RouteEngineFailure.unreachable),
      );
    });
  });

  group('OverpassSkiRouter', () {
    test(
      'a path gets heights, a ride straight from station to station',
      () async {
        final heights = _FakeHeights(
          (point) => 700 + (point.latitude - 47.4) * 10000,
        );

        final path = await route(router(heights: heights));

        final elevations = path.elevations!;
        expect(heights.asked.single, path.points);
        final ride = path.segments!.first;
        expect(ride.kind, SegmentKind.lift);
        // Off the ride, and at its ends, the heights are the ground's; between
        // its stops they are lifted off it (`levelAloft`, tested on its own).
        double ground(int i) => 700 + (path.points[i].latitude - 47.4) * 10000;
        expect(elevations.first, ground(0));
        expect(elevations.last, ground(elevations.length - 1));
        expect(elevations[ride.end], ground(ride.end));
        final lifted = [
          for (var i = ride.start; i <= ride.end; i++)
            if ((elevations[i] - ground(i)).abs() > 0.01) i,
        ];
        expect(lifted, isNotEmpty, reason: 'the ride runs over pylons');
        for (var i = 0; i < elevations.length; i++) {
          if (i < ride.start || i > ride.end) {
            expect(elevations[i], closeTo(ground(i), 0.01));
          }
        }
        expect(path.ascentMeters, isNotNull);
        expect(path.descentMeters, isNotNull);
      },
    );

    test('without heights the path comes all the same', () async {
      final path = await route(router(heights: _FakeHeights(null)));

      expect(path.segments, isNotEmpty);
      expect(path.elevations, isNull);
      expect(path.ascentMeters, isNull);
    });

    test('routes over the area it loaded, the ride under its name', () async {
      final path = await route(router());

      final ride = path.segments!.first;
      expect(ride.kind, SegmentKind.lift);
      expect(ride.name, 'Kreuzeckbahn');
      expect(ride.liftMode, TransportMode.gondola);
    });

    test('loads an area once, and around the waypoints', () async {
      final skiRouter = router();

      await route(skiRouter);
      await route(skiRouter);
      await skiRouter.route(
        waypoints: const [_hausbergValley, _kreuzeckValley],
        maxDifficulty: PisteDifficulty.standard,
      );

      expect(requests, hasLength(1));
      final query = Uri.splitQueryString(requests.single.body)['data']!;
      // The waypoints and three kilometers around, in whole hundredths.
      expect(query, contains('[bbox:47.44000,11.02000,47.51000,11.14000]'));
    });

    test('two runs routed at once wait for one load', () async {
      final skiRouter = router();

      await Future.wait([route(skiRouter), route(skiRouter)]);

      expect(requests, hasLength(1));
    });

    test('keeps the area on disk, for the next launch', () async {
      await route(router());
      expect(files.files.keys.single, '47.44_11.02_47.51_11.14_20261121');

      await route(router());

      expect(requests, hasLength(1));
    });

    test('loads an area again once it is a month old', () async {
      await route(router());
      now = DateTime(2026, 12, 22);

      await route(router());

      expect(requests, hasLength(2));
      expect(files.files.keys.single, endsWith('_20261222'));
    });

    test('a file that does not read is loaded again', () async {
      files.files['47.44_11.02_47.51_11.14_20261121'] = 'not json';

      await route(router());

      expect(requests, hasLength(1));
      expect(files.files.values.single, _garmisch);
    });

    test('forget loads the area afresh', () async {
      final skiRouter = router();
      await route(skiRouter);

      await skiRouter.forget();
      expect(files.files, isEmpty);
      await route(skiRouter);

      expect(requests, hasLength(2));
    });

    test('without a cache directory the area is kept in memory', () async {
      final skiRouter = router(withFiles: false);

      await route(skiRouter);
      await route(skiRouter);

      expect(requests, hasLength(1));
    });

    test('a run reaching too far is refused before asking anyone', () async {
      await expectLater(
        router().route(
          waypoints: const [LatLng(47.4, 11), LatLng(47.7, 11)],
          maxDifficulty: PisteDifficulty.standard,
        ),
        _refusedAs(RouteEngineFailure.tooLarge),
      );
      expect(requests, isEmpty);
    });

    test('an answer the server cut short is not routed over', () async {
      answer = (_) => http.Response(
        jsonEncode({
          'elements': <Object>[],
          'remark': 'runtime error: Query timed out in "query" at line 1',
        }),
        200,
      );

      await expectLater(route(router()), _refusedAs(RouteEngineFailure.busy));
      expect(files.files, isEmpty);
    });

    test('a run near the limit is loaded with less around it', () async {
      // About 26 km apart: with a kilometer around them they fit, with
      // three they would not.
      await router()
          .route(
            waypoints: const [_kreuzeckValley, LatLng(47.7055, 11.0637)],
            maxDifficulty: PisteDifficulty.standard,
          )
          .catchError((_) => _dummy);

      final query = Uri.splitQueryString(requests.single.body)['data']!;
      final box = RegExp(r'bbox:([^\]]+)').firstMatch(query)!.group(1)!;
      final [south, west, north, east] = [
        for (final part in box.split(',')) double.parse(part),
      ];
      expect(
        SkiBox(south, west, north, east).longestSideMeters,
        lessThanOrEqualTo(kMaxSkiAreaMeters),
      );
    });

    test('of two areas kept on disk the fresher is read', () async {
      files.files['47.44_11.02_47.51_11.14_20261101'] = 'stale';
      files.files['47.40_11.00_47.55_11.20_20261115'] = _garmisch;

      await route(router());

      expect(requests, isEmpty);
    });

    test('an answer without elements is a failure', () async {
      answer = (_) => http.Response('{"remark": "fine"}', 200);

      await expectLater(route(router()), _refusedAs(RouteEngineFailure.failed));
    });

    test('an answer that is not JSON is a failure', () async {
      answer = (_) => http.Response('<html>', 200);

      await expectLater(route(router()), _refusedAs(RouteEngineFailure.failed));
    });
  });

  group('SkiBox', () {
    test('grows outward to whole hundredths', () {
      const box = SkiBox(47.431, 11.039, 47.471, 11.111);

      expect(box.rounded, const SkiBox(47.43, 11.03, 47.48, 11.12));
      expect(box.rounded.key, '47.43_11.03_47.48_11.12');
      expect(box.rounded.contains(box), isTrue);
      expect(box.contains(box.rounded), isFalse);
    });

    test('measures its longer side', () {
      // A tenth of a degree of latitude, less of longitude this far north.
      expect(
        const SkiBox(47, 11, 47.1, 11.1).longestSideMeters,
        closeTo(11120, 20),
      );
    });
  });
}
