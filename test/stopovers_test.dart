import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/stopovers.dart';

/// The encoding a leg's stops are stored in. It is written once by the import
/// and read on every journey sheet, so what matters is that it round-trips
/// exactly and that nothing it is handed can bring the timeline down.
void main() {
  test('stops round-trip through the column', () {
    const stops = [
      Stopover(name: 'Büchen', minutes: 577),
      Stopover(name: 'Ludwigslust Bahnhof', minutes: 610),
      // A night train's small hours: the same leg, the next day.
      Stopover(name: 'Nürnberg Hbf', minutes: 134, dayOffset: 1),
    ];

    expect(decodeStopovers(encodeStopovers(stops)), stops);
  });

  test('a delay round-trips, and is absent until something is known', () {
    const stops = [
      Stopover(name: 'Büchen', minutes: 577, delayMinutes: 5),
      Stopover(name: 'Ludwigslust Bahnhof', minutes: 610, delayMinutes: -1),
      Stopover(name: 'Wittenberge, Bahnhof', minutes: 633),
    ];
    final encoded = encodeStopovers(stops)!;

    expect(decodeStopovers(encoded), stops);
    // A stop nothing is known about carries no key at all — the plan is not a
    // claim that the train is on time.
    expect(encoded.split('delay'), hasLength(3));
  });

  test('no stops are stored as nothing at all', () {
    expect(encodeStopovers(const []), isNull);
    expect(decodeStopovers(null), isEmpty);
    expect(decodeStopovers(''), isEmpty);
  });

  test('the common case carries no day offset on the wire', () {
    final encoded = encodeStopovers(const [
      Stopover(name: 'Büchen', minutes: 577),
    ]);
    expect(encoded, isNot(contains('day')));
  });

  test('a value that is not what we wrote reads as no stops', () {
    // A truncated string, another tool's contents, a shape from some future
    // version: a leg is still a leg, and a timeline that threw over its garnish
    // would be the worse failure.
    expect(decodeStopovers('[{"name":"Büchen","minu'), isEmpty);
    expect(decodeStopovers('{"name":"Büchen"}'), isEmpty);
    expect(decodeStopovers('[{"name":"Büchen"}]'), isEmpty);
    expect(decodeStopovers('[42,null]'), isEmpty);
  });

  test('unknown fields are ignored, known ones still read', () {
    expect(decodeStopovers('[{"name":"Büchen","minutes":577,"track":"3"}]'), [
      const Stopover(name: 'Büchen', minutes: 577),
    ]);
  });
}
