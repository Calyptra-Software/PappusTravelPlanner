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
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';

/// Everything is anchored here, so a screenshot taken any day looks the same.
final DateTime today = DateTime(2026, 8, 9);

DateTime day(int offset) => today.add(Duration(days: offset));
int at(int hour, [int minute = 0]) => hour * 60 + minute;

/// Built-in rows are seeded in enum order, so a mode's id is its index + 1.
int mode(TransportMode m) => m.index + 1;

const int eur = 1;
const int chf = 4;

void main() {
  test('writes the demo database', () async {
    final out = File('build/demo/pappus-demo.sqlite');
    if (out.existsSync()) out.deleteSync();
    out.parent.createSync(recursive: true);

    final db = AppDatabase.forTesting(NativeDatabase(out));
    addTearDown(db.close);

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
    }) => db.into(db.trips).insert(
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
    }) => db
        .into(db.itineraryItems)
        .insert(
          ItineraryItemsCompanion.insert(
            tripId: tripId,
            date: date,
            kind: ItemKind.place,
            title: Value(title),
            location: Value(location),
            notes: Value(notes),
            startMinutes: Value(from),
            endMinutes: Value(to),
            actualStartMinutes: Value(actualFrom),
            actualEndMinutes: Value(actualTo),
            sortOrder: Value(sort),
            alternativeId: Value(alternativeId),
          ),
        );

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
    }) => db
        .into(db.itineraryItems)
        .insert(
          ItineraryItemsCompanion.insert(
            tripId: tripId,
            date: date,
            kind: ItemKind.transport,
            title: Value(title),
            mode: Value(mode(m)),
            location: Value(fromPlace),
            toLocation: Value(toPlace),
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
            .insert(
              CostBeneficiariesCompanion.insert(costId: id, personId: p),
            );
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
    // 1. Alpine Crossing — the showcase trip, ongoing today
    // =====================================================================
    final alps = await trip(
      'Alpine Crossing',
      destination: 'Oberstdorf → Meran',
      start: day(-2),
      end: day(3),
      notes: 'Hut-to-hut across the Alps. Beds booked, tickets in the app.',
      color: 0xFF2E7D32,
    );
    await join(alps, [alex, sam, jo], [tagHiking]);

    // Day 1 — the journey out, three trains under one ticket.
    final ticket = await db
        .into(db.itemGroups)
        .insert(
          ItemGroupsCompanion.insert(
            tripId: alps,
            label: const Value('Hamburg → Oberstdorf'),
          ),
        );
    await leg(
      alps,
      day(-2),
      TransportMode.train,
      title: 'ICE 599',
      fromPlace: 'Hamburg Hbf',
      toPlace: 'München Hbf',
      from: at(6, 34),
      to: at(12, 2),
      actualFrom: at(6, 34),
      actualTo: at(12, 14),
      notes: 'Platform 6 · coach 24, seats 51–53',
      sort: 0,
      groupId: ticket,
    );
    await leg(
      alps,
      day(-2),
      TransportMode.train,
      title: 'RE 57',
      fromPlace: 'München Hbf',
      toPlace: 'Immenstadt',
      from: at(12, 51),
      to: at(14, 38),
      sort: 1,
      groupId: ticket,
    );
    await leg(
      alps,
      day(-2),
      TransportMode.train,
      title: 'RB 74',
      fromPlace: 'Immenstadt',
      toPlace: 'Oberstdorf',
      from: at(14, 46),
      to: at(15, 12),
      sort: 2,
      groupId: ticket,
    );
    await cost(
      13980,
      'Transport',
      groupId: ticket,
      forPeople: [alex, sam, jo],
    );
    final guesthouse = await place(
      alps,
      day(-2),
      'Gästehaus Alpenrose',
      location: 'Oberstdorf',
      from: at(16),
      notes: 'Three beds, breakfast from 07:00.',
      sort: 3,
    );
    await cost(
      21000,
      'Accommodation',
      itemId: guesthouse,
      forPeople: [alex, sam, jo],
    );

    // Day 2 — up to the first hut.
    await place(
      alps,
      day(-1),
      'Breakfast at the Alpenrose',
      from: at(7),
      to: at(7, 45),
      sort: 0,
    );
    await leg(
      alps,
      day(-1),
      TransportMode.bus,
      title: 'Bus 1',
      fromPlace: 'Oberstdorf',
      toPlace: 'Spielmannsau',
      from: at(8, 15),
      to: at(8, 38),
      sort: 1,
    );
    await leg(
      alps,
      day(-1),
      TransportMode.walk,
      fromPlace: 'Spielmannsau',
      toPlace: 'Kemptner Hütte',
      from: at(8, 45),
      to: at(13, 30),
      actualFrom: at(8, 52),
      actualTo: at(13, 58),
      notes: '1 070 m of ascent. Steep after the Sperrbachtobel.',
      sort: 2,
    );
    final hut = await place(
      alps,
      day(-1),
      'Kemptner Hütte',
      location: '1 844 m · DAV',
      from: at(14),
      notes: 'Dormitory. Cash only above the valley.',
      sort: 3,
    );
    await cost(9600, 'Accommodation', itemId: hut, forPeople: [alex, sam, jo]);
    await cost(
      6450,
      'Food',
      itemId: hut,
      paidBy: 'Sam',
      forPeople: [alex, sam, jo],
    );

    // Day 3 — today. Carries the "you are here" mark and the decision.
    await place(
      alps,
      day(0),
      'Breakfast at the hut',
      from: at(6, 30),
      to: at(7, 15),
      actualFrom: at(6, 30),
      actualTo: at(7, 20),
      sort: 0,
    );
    await leg(
      alps,
      day(0),
      TransportMode.walk,
      fromPlace: 'Kemptner Hütte',
      toPlace: 'Mädelejoch',
      from: at(7, 30),
      to: at(9, 0),
      actualFrom: at(7, 38),
      actualTo: at(8, 55),
      notes: 'The border ridge — Austria from here.',
      sort: 1,
    );

    // An open decision for the afternoon.
    final decision = await db
        .into(db.alternativeSets)
        .insert(
          AlternativeSetsCompanion.insert(
            tripId: alps,
            date: day(0),
            sortOrder: const Value(2),
            label: const Value('Afternoon'),
          ),
        );
    final viaSummit = await db
        .into(db.alternatives)
        .insert(
          AlternativesCompanion.insert(
            setId: decision,
            label: const Value('Over the summit'),
            sortOrder: const Value(0),
            chosen: const Value(true),
          ),
        );
    final viaLake = await db
        .into(db.alternatives)
        .insert(
          AlternativesCompanion.insert(
            setId: decision,
            label: const Value('Along the lake'),
            sortOrder: const Value(1),
          ),
        );
    await leg(
      alps,
      day(0),
      TransportMode.walk,
      fromPlace: 'Mädelejoch',
      toPlace: 'Krottenkopf (2 656 m)',
      from: at(9, 15),
      to: at(12, 30),
      notes: '400 m more climbing, but the view is the point.',
      sort: 0,
      alternativeId: viaSummit,
    );
    final summitHut = await place(
      alps,
      day(0),
      'Memminger Hütte',
      location: '2 242 m',
      from: at(15, 30),
      sort: 1,
      alternativeId: viaSummit,
    );
    await cost(
      10200,
      'Accommodation',
      itemId: summitHut,
      paid: false,
      forPeople: [alex, sam, jo],
    );
    await leg(
      alps,
      day(0),
      TransportMode.walk,
      fromPlace: 'Mädelejoch',
      toPlace: 'Holzgau',
      from: at(9, 15),
      to: at(13, 0),
      notes: 'Flatter, and there is a bakery.',
      sort: 0,
      alternativeId: viaLake,
    );
    final valleyInn = await place(
      alps,
      day(0),
      'Gasthof Bären',
      location: 'Holzgau',
      from: at(14),
      sort: 1,
      alternativeId: viaLake,
    );
    await cost(
      13500,
      'Accommodation',
      itemId: valleyInn,
      paid: false,
      forPeople: [alex, sam, jo],
    );

    // Day 4 — a cable car and a border crossing, priced in francs.
    await leg(
      alps,
      day(1),
      TransportMode.walk,
      fromPlace: 'Memminger Hütte',
      toPlace: 'Zams',
      from: at(7, 30),
      to: at(12, 45),
      sort: 0,
    );
    final cableCar = await leg(
      alps,
      day(1),
      TransportMode.other,
      title: 'Venetbahn',
      fromPlace: 'Zams',
      toPlace: 'Krahberg',
      from: at(13, 30),
      to: at(13, 48),
      sort: 1,
    );
    await cost(
      2400,
      'Tickets',
      currency: chf,
      itemId: cableCar,
      paidBy: 'Jo',
      forPeople: [alex, sam, jo],
    );
    await place(
      alps,
      day(1),
      'Krahberg viewpoint',
      location: '2 208 m',
      from: at(14),
      to: at(15),
      sort: 2,
    );

    // Day 6 — the way home.
    await leg(
      alps,
      day(3),
      TransportMode.train,
      title: 'EC 87',
      fromPlace: 'Meran',
      toPlace: 'München Hbf',
      from: at(9, 12),
      to: at(14, 20),
      sort: 0,
    );

    // Trip-level costs and a checklist.
    await cost(
      4800,
      'Gear',
      tripId: alps,
      paidBy: 'Sam',
      forPeople: [alex, sam, jo],
    );
    final packing = await db
        .into(db.checklists)
        .insert(
          ChecklistsCompanion.insert(
            tripId: alps,
            title: const Value('Packing'),
          ),
        );
    const packingItems = <(String, bool)>[
      ('Hut sleeping bag liner', true),
      ('Rain shell', true),
      ('Head torch', true),
      ('Alpine club card', true),
      ('Cash for the huts', false),
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
