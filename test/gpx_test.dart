import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/features/map/gpx.dart';

/// Reading a GPX file: what it takes, and what it deliberately leaves.
void main() {
  const walk = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Some Watch">
  <metadata><name>Ignored</name></metadata>
  <wpt lat="53.0" lon="9.0"><name>Parking</name></wpt>
  <trk>
    <name>Morning walk</name>
    <trkseg>
      <trkpt lat="53.55110" lon="9.99370"><ele>12.4</ele><time>2026-08-14T06:12:00Z</time></trkpt>
      <trkpt lat="53.55131" lon="9.99402"><ele>12.9</ele></trkpt>
      <trkpt lat="53.55160" lon="9.99450"/>
    </trkseg>
    <trkseg>
      <trkpt lat="53.56000" lon="10.00100"/>
      <trkpt lat="53.56050" lon="10.00200"/>
    </trkseg>
  </trk>
</gpx>
''';

  test('every segment becomes a line, under its track\'s name', () {
    final tracks = parseGpx(walk);

    expect(tracks, hasLength(2));
    expect(tracks.every((t) => t.name == 'Morning walk'), isTrue);
    expect(tracks[0].points, hasLength(3));
    expect(tracks[1].points, hasLength(2));
    expect(tracks[0].points.first.latitude, closeTo(53.5511, 1e-6));
    expect(tracks[0].points.first.longitude, closeTo(9.9937, 1e-6));
  });

  test('a gap between segments is left as a gap', () {
    // The two halves are 1 km apart — the tunnel, the pause, the lost fix. One
    // line through them would be ground nobody covered.
    final tracks = parseGpx(walk);
    expect(
      tracks[0].points.last.latitude,
      isNot(tracks[1].points.first.latitude),
    );
    expect(tracks, hasLength(2), reason: 'joined into one line');
  });

  test('a waypoint is not a line, and not an entry either', () {
    // The file above carries a <wpt>. Turning marks into places is a different
    // import, and not one to make behind the user's back.
    final tracks = parseGpx(walk);
    expect(tracks.expand((t) => t.points), hasLength(5));
  });

  test('a route counts as a line too', () {
    final tracks = parseGpx('''
<gpx version="1.1">
  <rte><name>Planned</name>
    <rtept lat="50.1" lon="8.6"/>
    <rtept lat="50.2" lon="8.7"/>
  </rte>
</gpx>
''');
    expect(tracks, hasLength(1));
    expect(tracks.single.name, 'Planned');
    expect(tracks.single.points, hasLength(2));
  });

  test('a namespace prefix does not hide the points', () {
    // Both spellings are written by real programs.
    final tracks = parseGpx('''
<gpx:gpx xmlns:gpx="http://www.topografix.com/GPX/1/1" version="1.1">
  <gpx:trk><gpx:trkseg>
    <gpx:trkpt lat="1.0" lon="2.0"/>
    <gpx:trkpt lat="1.1" lon="2.1"/>
  </gpx:trkseg></gpx:trk>
</gpx:gpx>
''');
    expect(tracks.single.points, hasLength(2));
  });

  test('a single point is not a line', () {
    final tracks = parseGpx('''
<gpx version="1.1"><trk><trkseg><trkpt lat="1.0" lon="2.0"/></trkseg></trk></gpx>
''');
    expect(tracks, isEmpty);
  });

  test('a nameless track keeps no name rather than a made-up one', () {
    final tracks = parseGpx('''
<gpx version="1.1"><trk><trkseg>
  <trkpt lat="1.0" lon="2.0"/><trkpt lat="1.1" lon="2.1"/>
</trkseg></trk></gpx>
''');
    expect(tracks.single.name, isNull);
  });

  group('a file from outside is not trusted', () {
    test('something that is not XML is refused', () {
      expect(() => parseGpx('not xml at all <<<'), throwsFormatException);
    });

    test('XML that is not GPX is refused', () {
      expect(() => parseGpx('<kml><Placemark/></kml>'), throwsFormatException);
    });

    test('a point without coordinates is refused, not skipped', () {
      // Skipping it would move the line to somewhere nobody went, quietly.
      expect(
        () => parseGpx('''
<gpx version="1.1"><trk><trkseg>
  <trkpt lat="1.0" lon="2.0"/><trkpt lat="1.1"/>
</trkseg></trk></gpx>
'''),
        throwsFormatException,
      );
    });

    test('a point outside the world is refused', () {
      expect(
        () => parseGpx('''
<gpx version="1.1"><trk><trkseg>
  <trkpt lat="1.0" lon="2.0"/><trkpt lat="91.0" lon="2.1"/>
</trkseg></trk></gpx>
'''),
        throwsFormatException,
      );
    });
  });

  group('times are read, all or nothing per line', () {
    String segment(List<String?> times) {
      final points = [
        for (var i = 0; i < times.length; i++)
          '<trkpt lat="1.$i" lon="2.0">'
              '${times[i] == null ? '' : '<time>${times[i]}</time>'}'
              '</trkpt>',
      ];
      return '<gpx version="1.1"><trk><trkseg>${points.join()}'
          '</trkseg></trk></gpx>';
    }

    test('every point timed, and an offset read as the instant it names', () {
      final tracks = parseGpx(
        segment(['2026-08-14T06:12:00Z', '2026-08-14T08:13:30+02:00']),
      );
      expect(tracks.single.times, [
        DateTime.utc(2026, 8, 14, 6, 12),
        DateTime.utc(2026, 8, 14, 6, 13, 30),
      ]);
    });

    test('one point without a time leaves the line without times', () {
      // A line timed in places would read its legs' times by guesswork.
      final tracks = parseGpx(segment(['2026-08-14T06:12:00Z', null]));
      expect(tracks.single.times, isNull);
      expect(tracks.single.points, hasLength(2));
    });

    test('a time that names no zone is not read as UTC', () {
      // The writer's local clock, off by an offset nobody knows.
      final tracks = parseGpx(
        segment(['2026-08-14T06:12:00', '2026-08-14T06:13:00']),
      );
      expect(tracks.single.times, isNull);
    });

    test('times running backwards are not a recording', () {
      final tracks = parseGpx(
        segment(['2026-08-14T06:13:00Z', '2026-08-14T06:12:00Z']),
      );
      expect(tracks.single.times, isNull);
    });

    test('a route carries no times, even when it has some', () {
      // A time on a route is a schedule somebody computed.
      final tracks = parseGpx('''
<gpx version="1.1"><rte>
  <rtept lat="50.1" lon="8.6"><time>2026-08-14T06:12:00Z</time></rtept>
  <rtept lat="50.2" lon="8.7"><time>2026-08-14T06:20:00Z</time></rtept>
</rte></gpx>
''');
      expect(tracks.single.times, isNull);
    });

    test('the first walk\'s untimed points leave it without times', () {
      // The file at the top times only its first point.
      expect(parseGpx(walk).every((t) => t.times == null), isTrue);
    });
  });
}
