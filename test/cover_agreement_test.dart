import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/repositories/trip_repository.dart';
import 'package:travelplanner/features/attachments/application/cover_providers.dart';
import 'package:travelplanner/features/attachments/attachment_import.dart';

/// The overview card and the star must never disagree about which photograph is
/// the trip's cover.
///
/// They are resolved by two different paths — the card from one all-trips query,
/// the star from the trip's own gallery — and they disagreed once, because the
/// card ordered photographs by when they were *added* while the star ordered
/// them by where the plan puts them. That only showed when both had to fall
/// back, so this walks every transition between the three states at every level
/// a photograph can hang on.
///
/// A plain `test`, not `testWidgets`: these are real drift streams and they need
/// a real clock.
void main() {
  late AppDatabase db;
  late TripRepository repo;
  late ProviderContainer container;
  late int trip;

  /// The thumbnail is one byte — the first letter of the file name — so the
  /// card's answer can be read back as a name.
  PreparedAttachment photo(String name) => PreparedAttachment(
    kind: AttachmentKind.photo,
    mimeType: 'image/jpeg',
    bytes: Uint8List.fromList(List.filled(8, 1)),
    name: name,
    thumbnail: Uint8List.fromList([name.codeUnitAt(0)]),
    width: 8,
    height: 8,
  );

  final names = <int, String>{};

  setUp(() async {
    names.clear();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = TripRepository(db);
    container = ProviderContainer(
      overrides: [repositoryProvider.overrideWithValue(repo)],
    );
    trip = await db.tripDao.createTrip(
      TripsCompanion.insert(
        title: 'Rome',
        startDate: Value(DateTime(2026, 5, 1)),
        endDate: Value(DateTime(2026, 5, 2)),
      ),
    );
  });
  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<int> attach(
    String name, {
    int? itemId,
    int? groupId,
    bool onTrip = false,
  }) async {
    final id = await db.attachmentDao.addAttachment(
      photo(name),
      itemId: itemId,
      groupId: groupId,
      tripId: onTrip ? trip : null,
    );
    names[id] = name;
    return id;
  }

  /// Lets the streams catch up, then reads both answers as file names.
  Future<({String card, String star})> settled() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final thumb = (container.read(tripCoversProvider).value ?? const {})[trip];
    final starId = container.read(tripCoverIdProvider(trip));
    return (
      card: thumb == null
          ? 'none'
          : names.values.firstWhere(
              (n) => n.codeUnitAt(0) == thumb.first,
              orElse: () => '?',
            ),
      star: starId == null ? 'none' : names[starId] ?? '?',
    );
  }

  test('card and star agree at every level and every transition', () async {
    final group = await db
        .into(db.itemGroups)
        .insert(ItemGroupsCompanion.insert(tripId: trip));
    Future<int> entry(DateTime day, int sort, {int? inGroup}) =>
        db.itineraryDao.addItem(
          ItineraryItemsCompanion.insert(
            tripId: trip,
            date: day,
            kind: ItemKind.place,
            sortOrder: Value(sort),
            groupId: Value(inGroup),
          ),
        );

    final first = await entry(DateTime(2026, 5, 1), 0);
    final second = await entry(DateTime(2026, 5, 2), 0);
    await entry(DateTime(2026, 5, 2), 1, inGroup: group);
    await entry(DateTime(2026, 5, 2), 2, inGroup: group);

    // Deliberately attached out of the plan's order: the later entry first.
    final later = await attach('later.jpg', itemId: second);
    final earlier = await attach('earlier.jpg', itemId: first);
    final onRun = await attach('run.jpg', groupId: group);
    final onTrip = await attach('trip.jpg', onTrip: true);

    container.listen(tripCoversProvider, (_, _) {});
    container.listen(tripCoverIdProvider(trip), (_, _) {});

    // Derived: the trip's own picture comes before its days'.
    var seen = await settled();
    expect(seen.card, seen.star);
    expect(seen.card, 'trip.jpg');

    for (final named in [later, onRun, onTrip, earlier]) {
      await db.tripDao.setCover(trip, named);
      seen = await settled();
      expect(seen.card, seen.star, reason: 'after starring ${names[named]}');
      expect(seen.card, names[named]);
    }

    // Deleting the named cover: both fall back, and to the same picture.
    await db.attachmentDao.deleteAttachment(earlier);
    seen = await settled();
    expect(seen.card, seen.star, reason: 'after deleting the named cover');
    expect(seen.card, 'trip.jpg');

    // And on down as each is removed.
    await db.attachmentDao.deleteAttachment(onTrip);
    seen = await settled();
    expect(seen.card, seen.star, reason: 'after deleting the trip-level one');
    // Day two, and the loose entry sits before the run that follows it.
    expect(seen.card, 'later.jpg');

    await db.attachmentDao.deleteAttachment(later);
    seen = await settled();
    expect(seen.card, seen.star, reason: 'after deleting the loose one');
    expect(seen.card, 'run.jpg');

    await db.attachmentDao.deleteAttachment(onRun);
    seen = await settled();
    expect(seen.card, 'none');
    expect(seen.star, 'none');
  });

  test('the trip may still say it wants none', () async {
    final place = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: trip,
        date: DateTime(2026, 5, 1),
        kind: ItemKind.place,
      ),
    );
    await attach('a.jpg', itemId: place);
    container.listen(tripCoversProvider, (_, _) {});
    container.listen(tripCoverIdProvider(trip), (_, _) {});

    expect((await settled()).card, 'a.jpg');

    await db.tripDao.setCoverHidden(trip, true);
    final seen = await settled();
    expect(seen.card, 'none');
    expect(seen.star, 'none');
  });

  test("a run's own picture comes before its first member's", () async {
    // The case that was actually wrong, found in a real database: a photograph
    // on the run *Hamburg – Mainz* and another on RB81, the leg the run begins
    // at. The two meet at exactly one position in the plan and nowhere else,
    // and the card decided between them by id while the gallery put the run's
    // first — so the card showed one picture and the star sat on the other.
    final group = await db
        .into(db.itemGroups)
        .insert(
          ItemGroupsCompanion.insert(tripId: trip, label: const Value('Run')),
        );
    final firstMember = await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: trip,
        date: DateTime(2026, 5, 1),
        kind: ItemKind.transport,
        groupId: Value(group),
      ),
    );
    await db.itineraryDao.addItem(
      ItineraryItemsCompanion.insert(
        tripId: trip,
        date: DateTime(2026, 5, 1),
        kind: ItemKind.transport,
        sortOrder: const Value(1),
        groupId: Value(group),
      ),
    );
    // On the leg first, so it takes the lower id — which is what used to win.
    await attach('leg.jpg', itemId: firstMember);
    await attach('run.jpg', groupId: group);

    container.listen(tripCoversProvider, (_, _) {});
    container.listen(tripCoverIdProvider(trip), (_, _) {});

    final seen = await settled();
    expect(seen.card, seen.star);
    expect(seen.card, 'run.jpg');
  });
}
