import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';

/// Tags are the one axis the overview is organised by, so they are the user's
/// vocabulary and nothing else: renameable, deletable, and never load-bearing.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> makeTrip([String title = 'Rome']) =>
      db.tripDao.createTrip(TripsCompanion.insert(title: title));

  test('a fresh database has no tags at all', () async {
    // Unlike the currencies and the transport modes, nothing is seeded: only
    // the user can say what their trips should be filed under.
    expect(await db.tagDao.watchAllTags().first, isEmpty);
  });

  test('ensureTag creates once and then reuses', () async {
    final first = await db.tagDao.ensureTag('walks');
    final second = await db.tagDao.ensureTag('walks');
    expect(second, first);
    expect(await db.tagDao.watchAllTags().first, hasLength(1));
  });

  test('ensureTag trims, so " walks " is not a second tag', () async {
    final first = await db.tagDao.ensureTag('walks');
    expect(await db.tagDao.ensureTag('  walks  '), first);
  });

  test('setTagsForTrip replaces the whole set', () async {
    final tripId = await makeTrip();
    final walks = await db.tagDao.ensureTag('walks');
    final rides = await db.tagDao.ensureTag('rides');

    await db.tagDao.setTagsForTrip(tripId, {walks, rides});
    expect(await db.tagDao.tagIdsForTrip(tripId), hasLength(2));

    await db.tagDao.setTagsForTrip(tripId, {rides});
    expect(await db.tagDao.tagIdsForTrip(tripId), [rides]);
  });

  test('addTagsToTrip adds without clearing what is there', () async {
    final tripId = await makeTrip();
    final walks = await db.tagDao.ensureTag('walks');
    final commute = await db.tagDao.ensureTag('commute');
    await db.tagDao.setTagsForTrip(tripId, {walks});

    // What a trip stamped out of a routine does: the routine's tags are an
    // addition, not a replacement of any the trip already carries.
    await db.tagDao.addTagsToTrip(tripId, [commute]);
    expect(
      (await db.tagDao.watchTagsForTrip(tripId).first).map((t) => t.name),
      containsAll(['walks', 'commute']),
    );
  });

  test('tagging the same pair twice is not an error', () async {
    final tripId = await makeTrip();
    final walks = await db.tagDao.ensureTag('walks');
    await db.tagDao.addTagsToTrip(tripId, [walks, walks]);
    await db.tagDao.addTagsToTrip(tripId, [walks]);
    expect(await db.tagDao.tagIdsForTrip(tripId), [walks]);
  });

  test('deleting a tag unfiles the trips but leaves them alone', () async {
    final tripId = await makeTrip();
    final walks = await db.tagDao.ensureTag('walks');
    await db.tagDao.setTagsForTrip(tripId, {walks});

    await db.tagDao.deleteTag(walks);

    expect(await db.tagDao.watchTagsForTrip(tripId).first, isEmpty);
    // A tag describes a trip; it does not own it.
    expect(await db.tripDao.findTrip(tripId), isNotNull);
  });

  test('deleting a trip takes its links, not the tag', () async {
    final tripId = await makeTrip();
    final walks = await db.tagDao.ensureTag('walks');
    await db.tagDao.setTagsForTrip(tripId, {walks});

    await db.tripDao.deleteTrip(tripId);

    expect(await db.tagDao.watchAllTags().first, hasLength(1));
  });

  test('renaming a tag keeps every trip filed under it', () async {
    final tripId = await makeTrip();
    final walks = await db.tagDao.ensureTag('walks');
    await db.tagDao.setTagsForTrip(tripId, {walks});

    final tag = (await db.tagDao.watchAllTags().first).single;
    await db.tagDao.updateTag(tag.copyWith(name: 'Spaziergänge'));

    expect(
      (await db.tagDao.watchTagsForTrip(tripId).first).single.name,
      'Spaziergänge',
    );
  });

  test('watchTagsByTrip keys every trip that carries one', () async {
    final a = await makeTrip('Rome');
    final b = await makeTrip('River walk');
    final walks = await db.tagDao.ensureTag('walks');
    await db.tagDao.setTagsForTrip(b, {walks});

    final byTrip = await db.tagDao.watchTagsByTrip().first;
    expect(byTrip.keys, [b]);
    // An untagged trip is absent rather than present-and-empty: the overview
    // reads a missing key the same way, and one row per link is the query.
    expect(byTrip.containsKey(a), isFalse);
  });

  test('tags come back in the user order they were given', () async {
    await db.tagDao.createTag(
      TagsCompanion.insert(name: 'zebra', sortOrder: const Value(0)),
    );
    await db.tagDao.createTag(
      TagsCompanion.insert(name: 'apple', sortOrder: const Value(1)),
    );
    expect((await db.tagDao.watchAllTags().first).map((t) => t.name), [
      'zebra',
      'apple',
    ]);
  });
}
