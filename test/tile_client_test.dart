import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:travelplanner/features/map/tile_client.dart';

void main() {
  final a = Uri.parse('https://a.example/1/1/1.png');
  final b = Uri.parse('https://b.example/1/1/1.png');

  late DateTime now;
  late List<Uri> asked;

  RateLimitRespectingClient client({
    int status = 429,
    Map<String, String> headers = const {},
  }) => RateLimitRespectingClient(
    MockClient((request) async {
      asked.add(request.url);
      return http.Response(
        '',
        request.url == a ? status : 200,
        headers: headers,
      );
    }),
    now: () => now,
  );

  setUp(() {
    now = DateTime(2026, 11, 9, 12);
    asked = [];
  });

  test('a host that answered 429 is not asked again', () async {
    final c = client();
    expect((await c.get(a)).statusCode, 429);
    expect((await c.get(a)).statusCode, 429);
    expect(asked, [a]);
  });

  test('other hosts are not affected', () async {
    final c = client();
    await c.get(a);
    expect((await c.get(b)).statusCode, 200);
    expect(asked, [a, b]);
  });

  test('it asks again once the pause is over', () async {
    final c = client();
    await c.get(a);
    now = now.add(kTileRateLimitPause);
    await c.get(a);
    expect(asked, [a, a]);
  });

  test('a Retry-After in seconds sets the pause', () async {
    final c = client(headers: {'retry-after': '60'});
    await c.get(a);

    now = now.add(const Duration(seconds: 59));
    await c.get(a);
    expect(asked, [a]);

    now = now.add(const Duration(seconds: 1));
    await c.get(a);
    expect(asked, [a, a]);
  });

  test('any other status pauses nothing', () async {
    final c = client(status: 500);
    await c.get(a);
    await c.get(a);
    expect(asked, [a, a]);
  });
}
