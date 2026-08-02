import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'tag_dao.g.dart';

/// The user's tag roster and which trips carry which tags.
///
/// Modelled on [People] / [TripParticipants] down to the shape of the queries,
/// because it is the same thing: a small reusable vocabulary the user manages,
/// linked many-to-many to trips. Deleting a tag unfiles every trip it was on
/// and nothing else — a tag describes a trip, it does not own it.
@DriftAccessor(tables: [Tags, TripTags, Trips])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  TagDao(super.db);

  /// Every tag, in the user's own order and then alphabetically — the order the
  /// filter bar and the tag pickers show them in.
  Stream<List<Tag>> watchAllTags() {
    return (select(tags)..orderBy([
          (t) => OrderingTerm(expression: t.sortOrder),
          (t) => OrderingTerm(expression: t.name),
        ]))
        .watch();
  }

  /// The tags on one trip.
  Stream<List<Tag>> watchTagsForTrip(int tripId) {
    final query =
        select(
            tags,
          ).join([innerJoin(tripTags, tripTags.tagId.equalsExp(tags.id))])
          ..where(tripTags.tripId.equals(tripId))
          ..orderBy([
            OrderingTerm(expression: tags.sortOrder),
            OrderingTerm(expression: tags.name),
          ]);
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(tags)).toList(),
    );
  }

  /// The tags of every trip, keyed by trip id — one query behind the overview,
  /// which needs a chip row on each card and a filter over all of them.
  Stream<Map<int, List<Tag>>> watchTagsByTrip() {
    final query =
        select(
          tripTags,
        ).join([innerJoin(tags, tags.id.equalsExp(tripTags.tagId))])..orderBy([
          OrderingTerm(expression: tags.sortOrder),
          OrderingTerm(expression: tags.name),
        ]);
    return query.watch().map((rows) {
      final byTrip = <int, List<Tag>>{};
      for (final row in rows) {
        final tripId = row.readTable(tripTags).tripId;
        byTrip.putIfAbsent(tripId, () => []).add(row.readTable(tags));
      }
      return byTrip;
    });
  }

  Future<int> createTag(TagsCompanion tag) => into(tags).insert(tag);

  Future<bool> updateTag(Tag tag) => update(tags).replace(tag);

  Future<int> deleteTag(int id) =>
      (delete(tags)..where((t) => t.id.equals(id))).go();

  /// The tag named [name], creating it if the roster has none — how a tag
  /// arrives from a text field, and from an imported trip that names one the
  /// recipient has never used.
  Future<int> ensureTag(String name) async {
    final trimmed = name.trim();
    return transaction(() async {
      final existing = await (select(
        tags,
      )..where((t) => t.name.equals(trimmed))).getSingleOrNull();
      if (existing != null) return existing.id;
      return into(tags).insert(TagsCompanion.insert(name: trimmed));
    });
  }

  /// Files [tripId] under exactly [tagIds] — what a trip's tag editor saves.
  /// Written as a replacement rather than a diff because the editor's answer is
  /// the whole set; the rows removed are only links, so nothing is lost.
  Future<void> setTagsForTrip(int tripId, Set<int> tagIds) {
    return transaction(() async {
      await (delete(tripTags)..where((tt) => tt.tripId.equals(tripId))).go();
      for (final tagId in tagIds) {
        await into(tripTags).insert(
          TripTagsCompanion.insert(tripId: tripId, tagId: tagId),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// Adds [tagIds] to [tripId], leaving any it already carries. Used when a
  /// trip inherits its routine's tags: the trip may have been given tags of its
  /// own already, and the routine's are an addition, not a replacement.
  Future<void> addTagsToTrip(int tripId, Iterable<int> tagIds) {
    return transaction(() async {
      for (final tagId in tagIds) {
        await into(tripTags).insert(
          TripTagsCompanion.insert(tripId: tripId, tagId: tagId),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// The ids of the tags on [tripId], for copying them onto another trip.
  Future<List<int>> tagIdsForTrip(int tripId) async {
    final rows = await (select(
      tripTags,
    )..where((tt) => tt.tripId.equals(tripId))).get();
    return [for (final row in rows) row.tagId];
  }
}
