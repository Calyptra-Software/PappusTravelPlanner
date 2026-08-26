/// Builds the demo database used for the screenshots in the README and
/// `docs/features.md`.
///
/// Run it with the Flutter test runner rather than `dart run`, because
/// `AppDatabase` reaches `database_location.dart`, which pulls in
/// `path_provider` and with it Flutter:
///
///     flutter test tool/seed_demo_db.dart
///     adb push build/demo/pappus-demo.sqlite /sdcard/Download/
///
/// then import it in the app under *Settings → Database → Import database…*.
/// It lives in `tool/` and not in `test/` on purpose: `flutter test` with no
/// path — what CI runs — only picks up `test/`, so this never runs there.
///
/// Dates are written relative to [today] so the hiking trip is always *ongoing*
/// and the timeline has a "you are here" mark to draw. Re-run it whenever the
/// screenshots are refreshed.
///
/// The hiking trip's trains, buses and funicular are **not** written here: they
/// are read from `tool/demo_journeys.json`, which `fetch_demo_journeys.dart`
/// fills from the live routing service. Stops, their coordinates, the lines'
/// names, the minutes they run at and the route they take along the ground all
/// come from there, so the demo map draws a train along its rails rather than a
/// chord across the country. The walking stages between them are still authored
/// (see the coordinate constants below for what that costs), and only the times
/// of day are taken from the fetched answer — the dates stay this script's own.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/database/track_points.dart';

/// Everything is anchored here, so a screenshot taken any day looks the same.
final DateTime today = DateTime(2026, 8, 9);

DateTime day(int offset) => today.add(Duration(days: offset));
int at(int hour, [int minute = 0]) => hour * 60 + minute;

/// Built-in rows are seeded in enum order, so a mode's id is its index + 1.
int mode(TransportMode m) => m.index + 1;

/// Where a walking stage meets a train or a bus: the routing service's own
/// position for that stop, copied out of `tool/demo_journeys.json`.
///
/// Repeated here rather than read from the file because a *walk* is not one of
/// the legs that file describes — it ends at the stop, and the two have to agree
/// or the map draws a footpath finishing three kilometres from the bus.
const klosters = LatLng(46.869267, 9.880677); // Klosters Platz
const bielerhoehe = LatLng(46.91728, 10.092339); // Bielerhöhe Silvrettasee
const zeinisjoch = LatLng(46.97791, 10.125604); // Kops Gh Zeinisjoch
const wagnerHuette = LatLng(47.10531, 10.222298); // Verwall Wagner Hütte
const johannestal = LatLng(47.46319, 11.502173); // Einstieg Johannestal

/// The Nordkette's two cable-car stations, from the geocoder rather than from a
/// timetable: no feed Transitous carries has the aerial cableway above the
/// Hungerburg, so the ride up to the Hafelekar is the one public-transport leg
/// in this trip that stays authored. Real positions, hand-drawn line.
const hungerburg = LatLng(47.286263, 11.400115); // Innsbruck Station Hungerburg
const seegrube = LatLng(47.3064177, 11.3791449);
const hafelekar = LatLng(47.312079, 11.383623);

/// The huts and passes of the walking stages, as WGS84 positions.
///
/// These are approximate — read off a map rather than surveyed, so a hut sits
/// within a few hundred metres of where it really is. Unlike a stop, a hut is
/// nobody's published datum, so there is nothing to fetch: they are the part of
/// the route still waiting to be measured.
const silvrettahuette = LatLng(46.8836, 10.0117);
const saarbrueckerHuette = LatLng(46.8992, 10.0947);
const heilbronnerHuette = LatLng(47.0206, 10.0794);
const fasultal = LatLng(47.0553, 10.1153);
const konstanzerHuette = LatLng(47.0864, 10.1497);
const hallerangerhaus = LatLng(47.3556, 11.4497);
const karwendelhaus = LatLng(47.4131, 11.4189);

/// A public-transport leg as `fetch_demo_journeys.dart` left it: the stops the
/// routing service named, where they really are, when the service really runs,
/// and the route it takes along the ground.
///
/// Read from a committed file rather than looked up here, so re-seeding needs no
/// network and produces the same database every time. See that tool for why the
/// file exists at all — in short, because the coordinates in this script used to
/// be guesses, and a guessed *stop* is the wrong stop.
class Fetched {
  Fetched(Map<String, Object?> json)
    : line = json['line'] as String?,
      fromName = json['fromName'] as String,
      toName = json['toName'] as String,
      from = LatLng(json['fromLat'] as double, json['fromLon'] as double),
      to = LatLng(json['toLat'] as double, json['toLon'] as double),
      departMinutes = json['departMinutes'] as int,
      arriveMinutes = json['arriveMinutes'] as int,
      shape = json['shape'] as String?;

  final String? line;
  final String fromName;
  final String toName;
  final LatLng from;
  final LatLng to;
  final int departMinutes;
  final int arriveMinutes;

  /// The router's own route for this leg, already packed at [kTrackPrecision] by
  /// the fetch tool — so it is written to the column as it stands rather than
  /// decoded and re-encoded here.
  final String? shape;
}

Map<String, List<Fetched>> loadJourneys() {
  final json =
      jsonDecode(File('tool/demo_journeys.json').readAsStringSync())
          as Map<String, Object?>;
  final journeys = json['journeys']! as Map<String, Object?>;
  return {
    for (final entry in journeys.entries)
      entry.key: [
        for (final leg
            in (entry.value! as Map<String, Object?>)['legs']! as List)
          Fetched(leg as Map<String, Object?>),
      ],
  };
}

const int eur = 1;
const int chf = 4;

void main() {
  test('writes the demo database', () async {
    final out = File('build/demo/pappus-demo.sqlite');
    if (out.existsSync()) out.deleteSync();
    out.parent.createSync(recursive: true);

    final db = AppDatabase.forTesting(NativeDatabase(out));
    addTearDown(db.close);

    // The public-transport legs, as fetched from the routing service.
    final journeys = loadJourneys();

    // --- People, tags and expense categories -----------------------------
    Future<int> person(String name, {bool isMe = false}) => db
        .into(db.people)
        .insert(PeopleCompanion.insert(name: name, isMe: Value(isMe)));

    final alex = await person('Alex', isMe: true);
    final sam = await person('Sam');
    final jo = await person('Jo');

    Future<int> tag(String name, int color) => db
        .into(db.tags)
        .insert(TagsCompanion.insert(name: name, colorValue: Value(color)));

    final tagHiking = await tag('hiking', 0xFF2E7D32);
    final tagCommute = await tag('commute', 0xFF546E7A);
    final tagBeach = await tag('beach', 0xFFEF6C00);
    final tagWalk = await tag('walk', 0xFF00838F);

    for (final label in const [
      'Transport',
      'Accommodation',
      'Food',
      'Tickets',
      'Gear',
    ]) {
      await db
          .into(db.costReasons)
          .insert(CostReasonsCompanion.insert(label: label));
    }

    // --- Helpers ---------------------------------------------------------
    Future<int> trip(
      String title, {
      required String destination,
      DateTime? start,
      DateTime? end,
      String? notes,
      int color = 0xFF00695C,
      TripKind kind = TripKind.trip,
      int? fromRoutine,
    }) => db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            title: title,
            destination: Value(destination),
            startDate: Value(start),
            endDate: Value(end),
            notes: Value(notes),
            colorValue: Value(color),
            kind: Value(kind),
            fromRoutineId: Value(fromRoutine),
          ),
        );

    Future<int> place(
      int tripId,
      DateTime date,
      String title, {
      int? from,
      int? to,
      String? location,
      String? notes,
      int sort = 0,
      int? alternativeId,
      int? actualFrom,
      int? actualTo,
      LatLng? pos,
    }) => db
        .into(db.itineraryItems)
        .insert(
          ItineraryItemsCompanion.insert(
            tripId: tripId,
            date: date,
            kind: ItemKind.place,
            title: Value(title),
            location: Value(location),
            lat: Value(pos?.latitude),
            lon: Value(pos?.longitude),
            notes: Value(notes),
            startMinutes: Value(from),
            endMinutes: Value(to),
            actualStartMinutes: Value(actualFrom),
            actualEndMinutes: Value(actualTo),
            sortOrder: Value(sort),
            alternativeId: Value(alternativeId),
          ),
        );

    /// The line an entry followed, packed the way the app stores one — what a
    /// GPX file arrives as once `parseGpx` has dropped its markup.
    Future<int> track(int itemId, String name, List<LatLng> points) => db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            itemId: itemId,
            name: Value(name),
            points: encodeTrackPoints(points),
          ),
        );

    /// A transport entry. [gpx] is the line it followed: when one is given the
    /// leg's own ends default to that line's first and last point, so the track
    /// and the coordinates can never disagree about where the leg began.
    Future<int> leg(
      int tripId,
      DateTime date,
      TransportMode m, {
      String? title,
      required String fromPlace,
      required String toPlace,
      int? from,
      int? to,
      int? actualFrom,
      int? actualTo,
      String? notes,
      int sort = 0,
      int? groupId,
      int? alternativeId,
      LatLng? fromPos,
      LatLng? toPos,
      List<LatLng> gpx = const [],
    }) async {
      final start = fromPos ?? (gpx.isEmpty ? null : gpx.first);
      final end = toPos ?? (gpx.isEmpty ? null : gpx.last);
      final id = await db
          .into(db.itineraryItems)
          .insert(
            ItineraryItemsCompanion.insert(
              tripId: tripId,
              date: date,
              kind: ItemKind.transport,
              title: Value(title),
              mode: Value(mode(m)),
              fromLocation: Value(fromPlace),
              toLocation: Value(toPlace),
              fromLat: Value(start?.latitude),
              fromLon: Value(start?.longitude),
              toLat: Value(end?.latitude),
              toLon: Value(end?.longitude),
              startMinutes: Value(from),
              endMinutes: Value(to),
              actualStartMinutes: Value(actualFrom),
              actualEndMinutes: Value(actualTo),
              notes: Value(notes),
              sortOrder: Value(sort),
              groupId: Value(groupId),
              alternativeId: Value(alternativeId),
            ),
          );
      if (gpx.isNotEmpty) await track(id, '$fromPlace → $toPlace', gpx);
      return id;
    }

    /// A leg the routing service supplied: its stops, its coordinates, its
    /// timetable and its route, all as fetched. Only the mode is passed in — the
    /// demo's rows are the built-ins, and mapping the service's own finer set
    /// (`highSpeedRail`, `funicular`) onto them is the app's job, not this
    /// script's.
    ///
    /// The shape is written as [TrackSource.routed] rather than `imported`,
    /// because that is what it is: the road or rail the router says the service
    /// takes, not a recording of anyone travelling it. The map draws it dashed
    /// for exactly that reason, and the walking stages beside it — which really
    /// are lines out of a GPX file — draw solid.
    Future<int> routedLeg(
      int tripId,
      DateTime date,
      TransportMode m,
      Fetched f, {
      String? notes,
      int? actualFrom,
      int? actualTo,
      int sort = 0,
      int? groupId,
    }) async {
      final id = await db
          .into(db.itineraryItems)
          .insert(
            ItineraryItemsCompanion.insert(
              tripId: tripId,
              date: date,
              kind: ItemKind.transport,
              title: Value(f.line),
              mode: Value(mode(m)),
              fromLocation: Value(f.fromName),
              toLocation: Value(f.toName),
              fromLat: Value(f.from.latitude),
              fromLon: Value(f.from.longitude),
              toLat: Value(f.to.latitude),
              toLon: Value(f.to.longitude),
              startMinutes: Value(f.departMinutes),
              endMinutes: Value(f.arriveMinutes),
              actualStartMinutes: Value(actualFrom),
              actualEndMinutes: Value(actualTo),
              notes: Value(notes),
              sortOrder: Value(sort),
              groupId: Value(groupId),
            ),
          );
      final shape = f.shape;
      if (shape != null) {
        await db
            .into(db.tracks)
            .insert(
              TracksCompanion.insert(
                itemId: id,
                name: Value('${f.fromName} → ${f.toName}'),
                points: shape,
                source: const Value(TrackSource.routed),
              ),
            );
      }
      return id;
    }

    Future<int> cost(
      int amountMinor,
      String reason, {
      int currency = eur,
      int? tripId,
      int? itemId,
      int? groupId,
      String paidBy = 'Alex',
      bool paid = true,
      List<int> forPeople = const [],
    }) async {
      final id = await db
          .into(db.costs)
          .insert(
            CostsCompanion.insert(
              amountMinor: amountMinor,
              currency: currency,
              reason: reason,
              tripId: Value(tripId),
              itemId: Value(itemId),
              groupId: Value(groupId),
              paidBy: Value(paidBy),
              paid: Value(paid),
            ),
          );
      for (final p in forPeople) {
        await db
            .into(db.costBeneficiaries)
            .insert(CostBeneficiariesCompanion.insert(costId: id, personId: p));
      }
      return id;
    }

    Future<void> join(int tripId, List<int> people, List<int> tags) async {
      for (final p in people) {
        await db
            .into(db.tripParticipants)
            .insert(
              TripParticipantsCompanion.insert(tripId: tripId, personId: p),
            );
      }
      for (final t in tags) {
        await db
            .into(db.tripTags)
            .insert(TripTagsCompanion.insert(tripId: tripId, tagId: t));
      }
    }

    // =====================================================================
    // 1. Silvretta to Karwendel — the showcase trip, ongoing today
    // =====================================================================
    // Nine days: out by train to Klosters, then hut to hut across the Silvretta,
    // the Verwall and the Karwendel, with the two bus rides and the cable car
    // the route needs. Every transport entry carries the GPX line it followed,
    // so the map draws the walk and not a chord between the huts.
    final hike = await trip(
      'Silvretta to Karwendel',
      destination: 'Klosters → Karwendel',
      start: day(-4),
      end: day(4),
      notes:
          'Hut-to-hut from Klosters to the Karwendel. Beds booked, '
          'tickets in the app.',
      color: 0xFF2E7D32,
    );
    await join(hike, [alex, sam, jo], [tagHiking]);

    // Day 1 — the journey out, four trains under one ticket. Every one of them
    // comes from the routing service: the line, the stations, where those
    // stations are, when the train runs, and the rails it runs along.
    final outward = journeys['outward']!;
    final ticket = await db
        .into(db.itemGroups)
        .insert(
          ItemGroupsCompanion.insert(
            tripId: hike,
            label: const Value('Würzburg → Klosters Platz'),
          ),
        );
    for (final (i, f) in outward.indexed) {
      await routedLeg(
        hike,
        day(-4),
        TransportMode.train,
        f,
        // A delay on the first leg, so the timeline has a miss to print.
        actualFrom: i == 0 ? f.departMinutes : null,
        actualTo: i == 0 ? f.arriveMinutes + 12 : null,
        notes: i == 0 ? 'Coach 26, seats 51–53' : null,
        sort: i,
        groupId: ticket,
      );
    }
    await cost(21600, 'Transport', groupId: ticket, forPeople: [alex, sam, jo]);
    final guesthouse = await place(
      hike,
      day(-4),
      'Hotel Alpina',
      location: 'Klosters',
      pos: outward.last.to,
      from: at(17, 30),
      notes: 'Three beds, breakfast from 07:00.',
      sort: outward.length,
    );
    await cost(
      24000,
      'Accommodation',
      currency: chf,
      itemId: guesthouse,
      forPeople: [alex, sam, jo],
    );

    // Day 2 — up the Sardasca valley to the first hut.
    await place(
      hike,
      day(-3),
      'Breakfast at the Alpina',
      from: at(7),
      to: at(7, 45),
      sort: 0,
    );
    await leg(
      hike,
      day(-3),
      TransportMode.walk,
      fromPlace: 'Klosters Platz',
      toPlace: 'Silvrettahütte',
      from: at(8, 15),
      to: at(13, 30),
      actualFrom: at(8, 22),
      actualTo: at(13, 52),
      notes: '1 150 m of ascent. Steep above Alp Sardasca.',
      sort: 1,
      gpx: const [
        klosters,
        LatLng(46.8742, 9.9081), // Monbiel
        LatLng(46.8683, 9.9450),
        LatLng(46.8706, 9.9761), // Alp Sardasca
        LatLng(46.8792, 10.0006),
        silvrettahuette,
      ],
    );
    final swissHut = await place(
      hike,
      day(-3),
      'Silvrettahütte',
      location: '2 341 m · SAC',
      pos: silvrettahuette,
      from: at(14),
      notes: 'Dormitory. Francs up here, and no card reader.',
      sort: 2,
    );
    await cost(
      10500,
      'Accommodation',
      currency: chf,
      itemId: swissHut,
      forPeople: [alex, sam, jo],
    );
    await cost(
      7200,
      'Food',
      currency: chf,
      itemId: swissHut,
      paidBy: 'Sam',
      forPeople: [alex, sam, jo],
    );

    // Day 3 — over the Rote Furka and into Austria.
    await leg(
      hike,
      day(-2),
      TransportMode.walk,
      fromPlace: 'Silvrettahütte',
      toPlace: 'Saarbrücker Hütte',
      from: at(7, 30),
      to: at(14, 0),
      actualFrom: at(7, 35),
      actualTo: at(14, 20),
      notes: 'Over the Rote Furka — Austria from the pass.',
      sort: 0,
      gpx: const [
        silvrettahuette,
        LatLng(46.8867, 10.0311),
        LatLng(46.8878, 10.0522), // Rote Furka
        LatLng(46.8931, 10.0728),
        LatLng(46.8961, 10.0872),
        saarbrueckerHuette,
      ],
    );
    final saarbruecker = await place(
      hike,
      day(-2),
      'Saarbrücker Hütte',
      location: '2 538 m · DAV',
      pos: saarbrueckerHuette,
      from: at(14, 30),
      sort: 1,
    );
    await cost(
      8850,
      'Accommodation',
      itemId: saarbruecker,
      forPeople: [alex, sam, jo],
    );

    // Day 4 — down to the Bielerhöhe, the bus over to the Zeinisjoch, and on
    // to the Heilbronner Hütte.
    await leg(
      hike,
      day(-1),
      TransportMode.walk,
      fromPlace: 'Saarbrücker Hütte',
      toPlace: 'Bielerhöhe',
      from: at(8),
      to: at(9, 45),
      sort: 0,
      gpx: const [
        saarbrueckerHuette,
        LatLng(46.9042, 10.0961),
        LatLng(46.9086, 10.0919), // Vermuntstausee
        LatLng(46.9128, 10.0906),
        bielerhoehe,
      ],
    );
    final zeinisBus = await routedLeg(
      hike,
      day(-1),
      TransportMode.bus,
      journeys['zeinisjochBus']!.single,
      notes: 'Rucksacks go in the trailer.',
      sort: 1,
    );
    await cost(
      1560,
      'Tickets',
      itemId: zeinisBus,
      paidBy: 'Jo',
      forPeople: [alex, sam, jo],
    );
    await leg(
      hike,
      day(-1),
      TransportMode.walk,
      fromPlace: 'Kops Gh Zeinisjoch',
      toPlace: 'Neue Heilbronner Hütte',
      from: at(10, 45),
      to: at(15, 0),
      actualFrom: at(10, 52),
      actualTo: at(14, 40),
      notes: 'Past the Kopssee, then the Verbellatal.',
      sort: 2,
      gpx: const [
        zeinisjoch,
        LatLng(46.9878, 10.1300), // Kopssee
        LatLng(47.0044, 10.1050),
        LatLng(47.0131, 10.0917),
        heilbronnerHuette,
      ],
    );
    final heilbronner = await place(
      hike,
      day(-1),
      'Neue Heilbronner Hütte',
      location: '2 320 m · DAV',
      pos: heilbronnerHuette,
      from: at(16),
      sort: 3,
    );
    await cost(
      8550,
      'Accommodation',
      itemId: heilbronner,
      forPeople: [alex, sam, jo],
    );

    // Day 5 — today. Carries the "you are here" mark and the open decision:
    // two ways down the Verwall to the Konstanzer Hütte.
    await place(
      hike,
      day(0),
      'Breakfast at the hut',
      from: at(6, 30),
      to: at(7, 15),
      actualFrom: at(6, 30),
      actualTo: at(7, 20),
      sort: 0,
    );
    await leg(
      hike,
      day(0),
      TransportMode.walk,
      fromPlace: 'Neue Heilbronner Hütte',
      toPlace: 'Fasultal',
      from: at(7, 30),
      to: at(9, 0),
      actualFrom: at(7, 38),
      actualTo: at(8, 55),
      sort: 1,
      gpx: const [
        heilbronnerHuette,
        LatLng(47.0311, 10.0925),
        LatLng(47.0431, 10.1042),
        fasultal,
      ],
    );

    // An open decision for the rest of the day.
    final decision = await db
        .into(db.alternativeSets)
        .insert(
          AlternativeSetsCompanion.insert(
            tripId: hike,
            date: day(0),
            sortOrder: const Value(2),
            label: const Value('To the Konstanzer Hütte'),
          ),
        );
    final viaRidge = await db
        .into(db.alternatives)
        .insert(
          AlternativesCompanion.insert(
            setId: decision,
            label: const Value('Over the Kaltenberg'),
            sortOrder: const Value(0),
            chosen: const Value(true),
          ),
        );
    final viaValley = await db
        .into(db.alternatives)
        .insert(
          AlternativesCompanion.insert(
            setId: decision,
            label: const Value('Down the Fasultal'),
            sortOrder: const Value(1),
          ),
        );
    await leg(
      hike,
      day(0),
      TransportMode.walk,
      fromPlace: 'Fasultal',
      toPlace: 'Konstanzer Hütte',
      from: at(9, 15),
      to: at(15, 0),
      notes: '500 m more climbing, but the ridge is the point.',
      sort: 0,
      alternativeId: viaRidge,
      gpx: const [
        fasultal,
        LatLng(47.0644, 10.1069),
        LatLng(47.0742, 10.1194),
        LatLng(47.0819, 10.1364),
        konstanzerHuette,
      ],
    );
    final ridgeHut = await place(
      hike,
      day(0),
      'Konstanzer Hütte',
      location: '1 688 m · DAV',
      pos: konstanzerHuette,
      from: at(15, 30),
      sort: 1,
      alternativeId: viaRidge,
    );
    await cost(
      8250,
      'Accommodation',
      itemId: ridgeHut,
      paid: false,
      forPeople: [alex, sam, jo],
    );
    final fasulalpe = await place(
      hike,
      day(0),
      'Fasulalpe',
      location: 'Fasultal',
      pos: const LatLng(47.0592, 10.1206),
      from: at(11),
      to: at(12),
      notes: 'Kaiserschmarrn on the terrace.',
      sort: 0,
      alternativeId: viaValley,
    );
    await cost(
      3600,
      'Food',
      itemId: fasulalpe,
      paid: false,
      forPeople: [alex, sam, jo],
    );
    await leg(
      hike,
      day(0),
      TransportMode.walk,
      fromPlace: 'Fasulalpe',
      toPlace: 'Konstanzer Hütte',
      from: at(12, 15),
      to: at(14, 0),
      notes: 'Flat along the Fasulbach.',
      sort: 1,
      alternativeId: viaValley,
      gpx: const [
        LatLng(47.0592, 10.1206),
        LatLng(47.0661, 10.1281),
        LatLng(47.0747, 10.1367),
        LatLng(47.0814, 10.1442),
        konstanzerHuette,
      ],
    );
    final valleyHut = await place(
      hike,
      day(0),
      'Konstanzer Hütte',
      location: '1 688 m · DAV',
      pos: konstanzerHuette,
      from: at(14, 30),
      sort: 2,
      alternativeId: viaValley,
    );
    await cost(
      8250,
      'Accommodation',
      itemId: valleyHut,
      paid: false,
      forPeople: [alex, sam, jo],
    );

    // Day 6 — out of the Verwall by bus and train, a night in Innsbruck.
    await leg(
      hike,
      day(1),
      TransportMode.walk,
      fromPlace: 'Konstanzer Hütte',
      toPlace: 'Verwall Wagner Hütte',
      from: at(9, 30),
      to: at(11, 30),
      notes: 'Down the Verwalltal on the alp road.',
      sort: 0,
      gpx: const [
        konstanzerHuette,
        LatLng(47.0928, 10.1642),
        LatLng(47.0989, 10.1806),
        wagnerHuette,
      ],
    );
    final verwallBus = await routedLeg(
      hike,
      day(1),
      TransportMode.bus,
      journeys['verwallBus']!.single,
      sort: 1,
    );
    await cost(
      1800,
      'Tickets',
      itemId: verwallBus,
      paidBy: 'Sam',
      forPeople: [alex, sam, jo],
    );
    final arlbergTrain = await routedLeg(
      hike,
      day(1),
      TransportMode.train,
      journeys['arlbergTrain']!.single,
      notes: 'Six minutes\u2019 walk from the bus terminal to the station.',
      sort: 2,
    );
    await cost(
      5700,
      'Transport',
      itemId: arlbergTrain,
      forPeople: [alex, sam, jo],
    );
    final innsbruckHotel = await place(
      hike,
      day(1),
      'Hotel Weisses Kreuz',
      location: 'Innsbruck',
      pos: const LatLng(47.2678, 11.3936),
      from: at(14, 30),
      notes: 'Laundry, and a bed that is not a mattress camp.',
      sort: 3,
    );
    await cost(
      18600,
      'Accommodation',
      itemId: innsbruckHotel,
      paidBy: 'Jo',
      forPeople: [alex, sam, jo],
    );

    // Day 7 — up the Nordkette, then over the ridge into the Karwendel.
    //
    // Two entries, because the ride really is two things and the data says so:
    // the Hungerburgbahn is a funicular in the Tyrolean feed, timetable and
    // track included, while the cableway above it appears in no feed at all —
    // so its line is drawn between the two stations' own positions and its
    // times are the operator's published ones.
    await routedLeg(
      hike,
      day(2),
      TransportMode.other,
      journeys['hungerburgbahn']!.single,
      sort: 0,
    );
    final cableCar = await leg(
      hike,
      day(2),
      TransportMode.other,
      title: 'Nordkettenbahnen',
      fromPlace: 'Innsbruck Station Hungerburg',
      toPlace: 'Hafelekar',
      from: at(9, 30),
      to: at(9, 55),
      notes: 'Change at the Seegrube.',
      sort: 1,
      gpx: const [hungerburg, seegrube, hafelekar],
    );
    await cost(
      12300,
      'Tickets',
      itemId: cableCar,
      paidBy: 'Jo',
      forPeople: [alex, sam, jo],
    );
    await leg(
      hike,
      day(2),
      TransportMode.walk,
      fromPlace: 'Hafelekar',
      toPlace: 'Hallerangerhaus',
      from: at(10, 15),
      to: at(15, 30),
      notes: 'Over the Hafelekarspitze, the Pfeishütte and the Stempeljoch.',
      sort: 2,
      gpx: const [
        hafelekar,
        LatLng(47.3139, 11.3800), // Hafelekarspitze
        LatLng(47.3211, 11.3986), // Mandlscharte
        LatLng(47.3283, 11.4183), // Pfeishütte
        LatLng(47.3308, 11.4392), // Stempeljoch
        LatLng(47.3392, 11.4592), // Lafatscher Joch
        hallerangerhaus,
      ],
    );
    final hallerangerHut = await place(
      hike,
      day(2),
      'Hallerangerhaus',
      location: '1 768 m · DAV',
      pos: hallerangerhaus,
      from: at(16),
      sort: 3,
    );
    await cost(
      8250,
      'Accommodation',
      itemId: hallerangerHut,
      paid: false,
      forPeople: [alex, sam, jo],
    );

    // Day 8 — the Hinterautal and up to the Karwendelhaus.
    await leg(
      hike,
      day(3),
      TransportMode.walk,
      fromPlace: 'Hallerangerhaus',
      toPlace: 'Karwendelhaus',
      from: at(7, 30),
      to: at(14, 30),
      notes: 'Kastenalm, the Hinterautal, then the Hochalmsattel.',
      sort: 0,
      gpx: const [
        hallerangerhaus,
        LatLng(47.3769, 11.4222), // Kastenalm
        LatLng(47.3922, 11.4053), // Hinterautal
        LatLng(47.4053, 11.4144), // Hochalmsattel
        karwendelhaus,
      ],
    );
    final karwendelHut = await place(
      hike,
      day(3),
      'Karwendelhaus',
      location: '1 765 m · DAV',
      pos: karwendelhaus,
      from: at(15),
      sort: 1,
    );
    await cost(
      8250,
      'Accommodation',
      itemId: karwendelHut,
      paid: false,
      forPeople: [alex, sam, jo],
    );

    // Day 9 — down the Johannestal and home by bus and train.
    await leg(
      hike,
      day(4),
      TransportMode.walk,
      fromPlace: 'Karwendelhaus',
      toPlace: 'Einstieg Johannestal',
      from: at(8, 30),
      to: at(11, 30),
      sort: 0,
      gpx: const [
        karwendelhaus,
        LatLng(47.4283, 11.4519), // Kleiner Ahornboden
        LatLng(47.4392, 11.4650),
        johannestal,
      ],
    );
    final rissBus = await routedLeg(
      hike,
      day(4),
      TransportMode.bus,
      journeys['rissBus']!.single,
      notes:
          'Via Hinterriß and the Sylvensteinsee. Twice a day, so this one '
          'is the one.',
      sort: 1,
    );
    await cost(
      2250,
      'Tickets',
      itemId: rissBus,
      paidBy: 'Sam',
      forPeople: [alex, sam, jo],
    );
    final homeTicket = await db
        .into(db.itemGroups)
        .insert(
          ItemGroupsCompanion.insert(
            tripId: hike,
            label: const Value('Lenggries → Würzburg'),
          ),
        );
    for (final (i, f) in journeys['homeward']!.indexed) {
      await routedLeg(
        hike,
        day(4),
        TransportMode.train,
        f,
        sort: 2 + i,
        groupId: homeTicket,
      );
    }
    await cost(
      16800,
      'Transport',
      groupId: homeTicket,
      paid: false,
      forPeople: [alex, sam, jo],
    );

    // Trip-level costs and a checklist.
    await cost(
      4800,
      'Gear',
      tripId: hike,
      paidBy: 'Sam',
      forPeople: [alex, sam, jo],
    );
    final packing = await db
        .into(db.checklists)
        .insert(
          ChecklistsCompanion.insert(
            tripId: hike,
            title: const Value('Packing'),
          ),
        );
    const packingItems = <(String, bool)>[
      ('Hut sleeping bag liner', true),
      ('Rain shell', true),
      ('Head torch', true),
      ('Alpine club card', true),
      ('Francs for the Silvrettahütte', false),
      ('Blister plasters', false),
    ];
    for (final (i, entry) in packingItems.indexed) {
      await db
          .into(db.checklistItems)
          .insert(
            ChecklistItemsCompanion.insert(
              checklistId: packing,
              label: entry.$1,
              done: Value(entry.$2),
              sortOrder: Value(i),
            ),
          );
    }

    // =====================================================================
    // 2. Beach week — upcoming, a different shape of trip
    // =====================================================================
    final beach = await trip(
      'Beach week in Valencia',
      destination: 'Valencia',
      start: day(28),
      end: day(34),
      notes: 'Flights booked, apartment paid.',
      color: 0xFFEF6C00,
    );
    await join(beach, [alex, jo], [tagBeach]);
    final flight = await leg(
      beach,
      day(28),
      TransportMode.flight,
      title: 'VY 1875',
      fromPlace: 'Hamburg',
      toPlace: 'Valencia',
      from: at(10, 5),
      to: at(13, 25),
      sort: 0,
    );
    await cost(23800, 'Transport', itemId: flight, forPeople: [alex, jo]);
    final apartment = await place(
      beach,
      day(28),
      'Apartment El Cabanyal',
      location: 'Valencia',
      from: at(15),
      sort: 1,
    );
    await cost(
      62000,
      'Accommodation',
      itemId: apartment,
      paidBy: 'Jo',
      forPeople: [alex, jo],
    );
    await place(
      beach,
      day(29),
      'Playa de la Malvarrosa',
      from: at(10),
      to: at(16),
      sort: 0,
    );

    // =====================================================================
    // 3. Sunday walk — a one-day trip, to show the same tools apply
    // =====================================================================
    final walk = await trip(
      'Sunday walk along the Elbe',
      destination: 'Blankenese',
      start: day(-7),
      end: day(-7),
      color: 0xFF00838F,
    );
    await join(walk, [alex, sam], [tagWalk]);
    await leg(
      walk,
      day(-7),
      TransportMode.subway,
      title: 'S1',
      fromPlace: 'Altona',
      toPlace: 'Blankenese',
      from: at(10, 12),
      to: at(10, 31),
      sort: 0,
    );
    await place(
      walk,
      day(-7),
      'Treppenviertel',
      from: at(10, 40),
      to: at(12, 0),
      sort: 1,
    );
    final cafe = await place(
      walk,
      day(-7),
      'Café Schuldt',
      from: at(12, 15),
      to: at(13, 0),
      sort: 2,
    );
    await cost(1840, 'Food', itemId: cafe, forPeople: [alex, sam]);

    // =====================================================================
    // 4. The commute — a routine, plus one trip stamped out of it
    // =====================================================================
    final routine = await trip(
      'Morning commute',
      destination: 'Home → Office',
      color: 0xFF546E7A,
      kind: TripKind.routine,
    );
    await join(routine, [alex], [tagCommute]);
    // A routine's items are laid out from the anchor day, not from real dates.
    final anchor = DateTime(1970);
    await leg(
      routine,
      anchor,
      TransportMode.bike,
      fromPlace: 'Home',
      toPlace: 'Altona',
      from: at(7, 40),
      to: at(7, 52),
      sort: 0,
    );
    final commuteTrain = await leg(
      routine,
      anchor,
      TransportMode.train,
      title: 'S31',
      fromPlace: 'Altona',
      toPlace: 'Dammtor',
      from: at(8, 1),
      to: at(8, 9),
      sort: 1,
    );
    await cost(
      370,
      'Transport',
      itemId: commuteTrain,
      paid: false,
      forPeople: [alex],
    );
    await leg(
      routine,
      anchor,
      TransportMode.walk,
      fromPlace: 'Dammtor',
      toPlace: 'Office',
      from: at(8, 12),
      to: at(8, 20),
      sort: 2,
    );

    final commuteToday = await trip(
      'Morning commute',
      destination: 'Home → Office',
      start: day(-4),
      end: day(-4),
      color: 0xFF546E7A,
      fromRoutine: routine,
    );
    await join(commuteToday, [alex], [tagCommute]);
    await leg(
      commuteToday,
      day(-4),
      TransportMode.bike,
      fromPlace: 'Home',
      toPlace: 'Altona',
      from: at(7, 40),
      to: at(7, 52),
      actualFrom: at(7, 44),
      actualTo: at(7, 58),
      sort: 0,
    );
    await leg(
      commuteToday,
      day(-4),
      TransportMode.train,
      title: 'S31',
      fromPlace: 'Altona',
      toPlace: 'Dammtor',
      from: at(8, 1),
      to: at(8, 9),
      actualFrom: at(8, 7),
      actualTo: at(8, 15),
      notes: 'Signal fault at Holstenstraße.',
      sort: 1,
    );

    final counts = <String, int>{
      'trips': await db.trips.count().getSingle(),
      'items': await db.itineraryItems.count().getSingle(),
      'costs': await db.costs.count().getSingle(),
      'people': await db.people.count().getSingle(),
      'tags': await db.tags.count().getSingle(),
    };
    // ignore: avoid_print
    print('wrote ${out.path}: $counts');
    expect(counts['trips'], 5);
  });
}
