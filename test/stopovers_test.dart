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

  test('a skipped stop is stored as skipped, never as punctual', () {
    const stops = [
      Stopover(name: 'Lüneburg', minutes: 1385, cancelled: true),
      Stopover(name: 'Uelzen', minutes: 1410, cancelled: true),
      Stopover(name: 'Celle Bahnhof', minutes: 1440 - 5, delayMinutes: 45),
    ];

    expect(decodeStopovers(encodeStopovers(stops)), stops);
    // The flag says what the delay cannot: a train that is not calling here is
    // not calling here on time.
    expect(decodeStopovers(encodeStopovers(stops)).first.delayMinutes, isNull);
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

  test('position, zone and dwell round-trip, and are optional', () {
    const stops = [
      Stopover(
        name: 'Schwerin Hauptbahnhof',
        minutes: 475,
        dwellMinutes: 2,
        lat: 53.635628,
        lon: 11.407445,
        timeZone: 'Europe/Berlin',
      ),
      // As an import from before these were kept stored it.
      Stopover(name: 'Büchen', minutes: 511),
    ];
    final encoded = encodeStopovers(stops)!;

    expect(decodeStopovers(encoded), stops);
    expect(encoded.split('"lat"'), hasLength(2));
  });

  test('stops written before positions were kept still read', () {
    expect(
      decodeStopovers('[{"name":"Büchen","minutes":511,"delay":3}]'),
      const [Stopover(name: 'Büchen', minutes: 511, delayMinutes: 3)],
    );
  });

  test('a live figure is taken off without the position going with it', () {
    const stop = Stopover(
      name: 'Bergedorf',
      minutes: 528,
      delayMinutes: 4,
      dwellMinutes: 4,
      lat: 53.49,
      lon: 10.21,
      timeZone: 'Europe/Berlin',
    );

    expect(
      stop.withLive(),
      const Stopover(
        name: 'Bergedorf',
        minutes: 528,
        dwellMinutes: 4,
        lat: 53.49,
        lon: 10.21,
        timeZone: 'Europe/Berlin',
      ),
    );
  });

  test('filling a stop in keeps what it already knew', () {
    const known = Stopover(name: 'X', minutes: 1, lat: 1, lon: 2);

    final filled = known.filledFrom(lat: 9, lon: 9, timeZone: 'Europe/Paris');
    expect(filled.lat, 1);
    expect(filled.lon, 2);
    expect(filled.timeZone, 'Europe/Paris');
  });

  group('RunStops', () {
    const run = RunStops(
      before: [
        Stopover(
          name: 'Origin',
          minutes: 1350,
          dayOffset: -1,
          delayMinutes: 12,
        ),
      ],
      after: [Stopover(name: 'Terminus', minutes: 925, lat: 48.14, lon: 11.56)],
    );

    test('round-trips through its column', () {
      expect(decodeRunStops(encodeRunStops(run)), run);
    });

    test('a leg that is the whole run is stored, not left unasked', () {
      // Null means "never loaded"; an empty run is an answer.
      final encoded = encodeRunStops(const RunStops());
      expect(encoded, isNotNull);
      expect(decodeRunStops(encoded)!.isEmpty, isTrue);
    });

    test('nothing, or something unreadable, reads as never loaded', () {
      expect(decodeRunStops(null), isNull);
      expect(decodeRunStops(''), isNull);
      expect(decodeRunStops('{"before":'), isNull);
      expect(decodeRunStops('[1,2]'), isNull);
    });

    test('the live figures come off for another day', () {
      final stripped = decodeRunStops(runStopsWithoutLive(encodeRunStops(run)));
      expect(stripped!.before.single.delayMinutes, isNull);
      expect(stripped.before.single.dayOffset, -1);
      expect(stripped.after.single.lat, 48.14);
      expect(runStopsWithoutLive(null), isNull);
    });
  });
}
