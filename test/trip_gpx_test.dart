import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/database/track_points.dart';
import 'package:travelplanner/features/map/gpx.dart';
import 'package:travelplanner/features/sharing/trip_bundle.dart';
import 'package:travelplanner/features/sharing/trip_gpx.dart';
import 'package:xml/xml.dart';

/// The lines a trip carries, written out in the format every mapping tool
/// reads.
///
/// Half of what is stored has no original anywhere else — the pieces one
/// recording was cut into, and the routes the connection search computed — so
/// this is the only way they leave the app without a decoder being written
/// first.
void main() {
  /// A fixed instant, so the document's own timestamp does not vary run to run.
  final exportedAt = DateTime.utc(2026, 7, 20, 8, 30, 15);

  const walked = [LatLng(53.5511, 9.9937), LatLng(53.5600, 10.0100)];
  const computed = [LatLng(53.5511, 9.9937), LatLng(53.5550, 10.0000)];

  BundleTrack track(
    List<LatLng> points, {
    String? name,
    TrackSource source = TrackSource.imported,
    TrackDisplay display = TrackDisplay.auto,
  }) => BundleTrack(
    points: encodeTrackPoints(points),
    source: source,
    name: name,
    display: display,
  );

  BundleItem leg(
    int id, {
    List<BundleTrack> tracks = const [],
    String? title,
    String? mode,
    int? alternativeLocalId,
    DateTime? date,
  }) => BundleItem(
    localId: id,
    date: date ?? DateTime(2026, 5, 1),
    kind: ItemKind.transport,
    title: title,
    mode: mode,
    fromLocation: 'Jungfernstieg',
    toLocation: 'Winterhude',
    tracks: tracks,
    alternativeLocalId: alternativeLocalId,
  );

  TripBundle bundleWith({
    List<BundleItem> items = const [],
    List<BundleAlternativeSet> alternativeSets = const [],
    TripKind kind = TripKind.trip,
  }) => TripBundle(
    schemaVersion: 22,
    trip: BundleTrip(
      title: 'Hamburg',
      destination: '',
      colorValue: 0xFF00695C,
      createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      kind: kind,
    ),
    items: items,
    costs: const [],
    alternativeSets: alternativeSets,
  );

  XmlDocument parse(String? gpx) => XmlDocument.parse(gpx!);

  test('a trip with no lines is no file at all', () {
    // A document holding nothing would be worse than the message the caller
    // shows instead.
    expect(buildTripGpx(bundle: bundleWith(items: [leg(1)])), isNull);
    expect(buildTripGpx(bundle: bundleWith()), isNull);
  });

  test('a recording is a track, a computed route is a route', () {
    // The distinction GPX itself draws — where something went, against how it
    // could go — which is the one `TrackSource` draws and the map dashes.
    final doc = parse(
      buildTripGpx(
        bundle: bundleWith(
          items: [
            leg(
              1,
              tracks: [
                track(computed, source: TrackSource.routed),
                track(walked, name: 'alster.gpx'),
              ],
            ),
          ],
        ),
        exportedAt: exportedAt,
      ),
    );

    expect(doc.findAllElements('trk'), hasLength(1));
    expect(doc.findAllElements('rte'), hasLength(1));
    expect(doc.findAllElements('trkpt'), hasLength(2));
    expect(doc.findAllElements('rtept'), hasLength(2));
    // A track's points live in a segment, a route's directly in the route.
    expect(doc.findAllElements('trkseg'), hasLength(1));
  });

  test('routes are written before tracks, as the schema demands', () {
    // Not in the plan's order: a strict reader rejects a file that orders the
    // two by anything else.
    final gpx = buildTripGpx(
      bundle: bundleWith(
        items: [
          leg(1, tracks: [track(walked)]),
          leg(2, tracks: [track(computed, source: TrackSource.routed)]),
        ],
      ),
      exportedAt: exportedAt,
    )!;

    expect(gpx.indexOf('<rte>'), lessThan(gpx.indexOf('<trk>')));
  });

  test('the road not taken does not leave the app', () {
    // The rule the PDF and the calendar already follow.
    final doc = parse(
      buildTripGpx(
        bundle: bundleWith(
          alternativeSets: [
            BundleAlternativeSet(
              localId: 10,
              date: DateTime(2026, 5, 1),
              alternatives: const [
                BundleAlternative(localId: 100, chosen: true),
                BundleAlternative(localId: 101),
              ],
            ),
          ],
          items: [
            leg(
              1,
              title: 'Ferry',
              alternativeLocalId: 100,
              tracks: [track(walked)],
            ),
            leg(
              2,
              title: 'Bridge',
              alternativeLocalId: 101,
              tracks: [track(computed)],
            ),
          ],
        ),
        exportedAt: exportedAt,
      ),
    );

    expect(doc.findAllElements('trk'), hasLength(1));
    expect(
      doc.findAllElements('name').map((e) => e.innerText),
      contains('Ferry'),
    );
  });

  test('a line the map is not drawing is exported all the same', () {
    // Hiding is a statement about the picture; a GPX is the record, and an eye
    // quietly changing what a file holds would be the worse surprise.
    final doc = parse(
      buildTripGpx(
        bundle: bundleWith(
          items: [
            leg(1, tracks: [track(walked, display: TrackDisplay.hidden)]),
          ],
        ),
        exportedAt: exportedAt,
      ),
    );

    expect(doc.findAllElements('trk'), hasLength(1));
  });

  test('a line is named after its entry and the file it came from', () {
    final doc = parse(
      buildTripGpx(
        bundle: bundleWith(
          items: [
            leg(
              1,
              title: 'To the station',
              tracks: [track(walked, name: 'alster.gpx')],
            ),
          ],
        ),
        exportedAt: exportedAt,
      ),
    );

    expect(
      doc.findAllElements('trk').single.getElement('name')!.innerText,
      'To the station · alster.gpx',
    );
  });

  test('an unnamed line on an unlabeled entry reads as its ends', () {
    // Nothing is invented — the rule the table itself follows.
    final doc = parse(
      buildTripGpx(
        bundle: bundleWith(
          items: [
            leg(1, tracks: [track(walked)]),
          ],
        ),
        exportedAt: exportedAt,
      ),
    );

    expect(
      doc.findAllElements('trk').single.getElement('name')!.innerText,
      'Jungfernstieg → Winterhude',
    );
  });

  test('the entry carries its day and its mode, and no clock', () {
    final doc = parse(
      buildTripGpx(
        bundle: bundleWith(
          items: [
            leg(
              1,
              mode: 'train',
              date: DateTime(2026, 5, 3),
              tracks: [track(walked)],
            ),
          ],
        ),
        exportedAt: exportedAt,
      ),
    );

    final trk = doc.findAllElements('trk').single;
    expect(trk.getElement('desc')!.innerText, '2026-05-03');
    expect(trk.getElement('type')!.innerText, 'train');
    // The import dropped the timestamps deliberately; this cannot invent them.
    expect(doc.findAllElements('time'), hasLength(1));
    expect(doc.findAllElements('ele'), isEmpty);
    expect(
      doc.findAllElements('time').single.innerText,
      exportedAt.toIso8601String(),
    );
  });

  test("a routine's lines carry no day, because it has none", () {
    // Its entries sit on an anchor date that is a sort origin, not a day
    // anybody travelled — writing it out would be the 1970 fiction.
    final doc = parse(
      buildTripGpx(
        bundle: bundleWith(
          kind: TripKind.routine,
          items: [
            leg(1, date: DateTime(1970, 1, 1), tracks: [track(walked)]),
          ],
        ),
        exportedAt: exportedAt,
      ),
    );

    expect(doc.findAllElements('trk'), hasLength(1));
    expect(doc.findAllElements('desc'), isEmpty);
  });

  test('coordinates are written at the precision the column holds', () {
    // Five decimals is about a metre; more digits would be precision this app
    // does not have to give.
    final doc = parse(
      buildTripGpx(
        bundle: bundleWith(
          items: [
            leg(1, tracks: [track(walked)]),
          ],
        ),
        exportedAt: exportedAt,
      ),
    );

    final first = doc.findAllElements('trkpt').first;
    expect(first.getAttribute('lat'), '53.55110');
    expect(first.getAttribute('lon'), '9.99370');
  });

  test('a line that will not decode costs its own line and nothing else', () {
    // The trade the map already makes: a row from somebody else's copy must
    // not cost the whole trip its export.
    final doc = parse(
      buildTripGpx(
        bundle: bundleWith(
          items: [
            leg(
              1,
              tracks: [
                const BundleTrack(
                  points: 'not a polyline at all ~~~',
                  source: TrackSource.imported,
                ),
                track(walked),
              ],
            ),
          ],
        ),
        exportedAt: exportedAt,
      ),
    );

    expect(doc.findAllElements('trk'), hasLength(1));
  });

  test('a name the reader would choke on is escaped, not written raw', () {
    final gpx = buildTripGpx(
      bundle: bundleWith(
        items: [
          leg(1, title: 'Fish & <chips>', tracks: [track(walked)]),
        ],
      ),
      exportedAt: exportedAt,
    )!;

    expect(gpx, contains('Fish &amp; &lt;chips>'));
    expect(
      XmlDocument.parse(
        gpx,
      ).findAllElements('trk').single.getElement('name')!.innerText,
      'Fish & <chips>',
    );
  });

  test("the app reads back what it writes, and keeps the two kinds apart", () {
    // `parseGpx` is the reader on the other side of this, so a file that only
    // some other tool could open would be a strange thing to have written.
    final gpx = buildTripGpx(
      bundle: bundleWith(
        items: [
          leg(
            1,
            title: 'To the station',
            tracks: [
              track(computed, source: TrackSource.routed),
              track(walked, name: 'alster.gpx'),
            ],
          ),
        ],
      ),
      exportedAt: exportedAt,
    )!;

    final read = parseGpx(gpx);
    expect(read, hasLength(2));
    expect(read.map((t) => t.points.length), [2, 2]);
    // Both come back as lines carrying their names — the reader takes tracks
    // first and routes after, which is its own order and not the file's.
    expect(read.map((t) => t.name), [
      'To the station · alster.gpx',
      'To the station',
    ]);
    // And the geometry survives the trip out and back, to the metre the column
    // stores.
    expect(read.first.points.first.latitude, closeTo(53.5511, 1e-5));
    expect(read.first.points.last.longitude, closeTo(10.0100, 1e-5));
  });

  test('the document says what it is and who wrote it', () {
    final doc = parse(
      buildTripGpx(
        bundle: bundleWith(
          items: [
            leg(1, tracks: [track(walked)]),
          ],
        ),
        creator: 'PappusTravelPlanner/1.9.0',
        exportedAt: exportedAt,
      ),
    );

    final gpx = doc.rootElement;
    expect(gpx.name.local, 'gpx');
    expect(gpx.getAttribute('version'), '1.1');
    expect(gpx.getAttribute('creator'), 'PappusTravelPlanner/1.9.0');
    expect(gpx.getAttribute('xmlns'), 'http://www.topografix.com/GPX/1/1');
    expect(
      doc.findAllElements('metadata').single.getElement('name')!.innerText,
      'Hamburg',
    );
  });
}
