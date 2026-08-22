import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart';

import '../app_database.dart';
import '../tables.dart';
import '../../../features/attachments/attachment_import.dart'
    show PreparedAttachment;

part 'attachment_dao.g.dart';

/// The files hung on parts of a plan.
///
/// Two things shape everything here. The payload lives in its own table, so
/// *listing* attachments is not *reading* them — drift selects every column of
/// the table it is given, and a stream over a day's entries would otherwise
/// carry every photo in that day on every rebuild. And an attachment belongs to
/// exactly one of an item or a group ([Attachments]), which is one invariant
/// with no way to express it in the schema, so every write here goes through
/// [_owner] and no caller assembles a companion of its own.
@DriftAccessor(
  tables: [Attachments, AttachmentBlobs, ItineraryItems, ItemGroups],
)
class AttachmentDao extends DatabaseAccessor<AppDatabase>
    with _$AttachmentDaoMixin {
  AttachmentDao(super.db);

  /// What one entry carries, in its own order. Metadata and thumbnails only.
  Stream<List<Attachment>> watchAttachmentsForItem(int itemId) =>
      _ordered(attachments.itemId.equals(itemId)).watch();

  /// What one run carries — the shared ticket, the booking for the whole
  /// journey. Hangs off the group for the reason its fare does.
  Stream<List<Attachment>> watchAttachmentsForGroup(int groupId) =>
      _ordered(attachments.groupId.equals(groupId)).watch();

  /// How many attachments each entry and each run of one trip carries, keyed by
  /// item id and by group id respectively.
  ///
  /// A count and not the rows: this answers the timeline's question — is there
  /// anything here — for a whole trip at once, and the rows themselves are read
  /// when something is opened. Deliberately unfiltered by the live rule, unlike
  /// `TrackDao.watchTracksForTrip`: an option nobody chose is still drawn in the
  /// timeline, and a badge missing from it would read as "no attachments" rather
  /// than as "not counted".
  Stream<({Map<int, int> byItem, Map<int, int> byGroup})>
  watchAttachmentCountsForTrip(int tripId) {
    final query =
        selectOnly(attachments).join([
            leftOuterJoin(
              itineraryItems,
              itineraryItems.id.equalsExp(attachments.itemId),
            ),
            leftOuterJoin(
              itemGroups,
              itemGroups.id.equalsExp(attachments.groupId),
            ),
          ])
          ..addColumns([
            attachments.itemId,
            attachments.groupId,
            attachments.id.count(),
          ])
          ..where(
            itineraryItems.tripId.equals(tripId) |
                itemGroups.tripId.equals(tripId),
          )
          ..groupBy([attachments.itemId, attachments.groupId]);
    return query.watch().map((rows) {
      final byItem = <int, int>{};
      final byGroup = <int, int>{};
      for (final row in rows) {
        final count = row.read(attachments.id.count()) ?? 0;
        final itemId = row.read(attachments.itemId);
        final groupId = row.read(attachments.groupId);
        if (itemId != null) byItem[itemId] = count;
        if (groupId != null) byGroup[groupId] = count;
      }
      return (byItem: byItem, byGroup: byGroup);
    });
  }

  /// One row, for a viewer that was handed an id rather than the row.
  Future<Attachment?> attachment(int id) =>
      (select(attachments)..where((a) => a.id.equals(id))).getSingleOrNull();

  /// One row, live — what the sheet that renames and positions an attachment
  /// reads, so the value on screen is the value in the database rather than the
  /// one the tile was tapped with. Null once it has been deleted.
  Stream<Attachment?> watchAttachment(int id) =>
      (select(attachments)..where((a) => a.id.equals(id))).watchSingleOrNull();

  /// The payload — the only read that touches a full-size file. Null when the
  /// row is gone, which is what a viewer left open on a deleted attachment sees.
  Future<Uint8List?> readAttachmentBytes(int id) async {
    final row = await (select(
      attachmentBlobs,
    )..where((b) => b.attachmentId.equals(id))).getSingleOrNull();
    return row?.bytes;
  }

  /// Writes a prepared file onto an item or a group, appended after whatever
  /// that owner already carries. Returns the new row's id.
  ///
  /// Takes a [PreparedAttachment] rather than raw bytes for the reason
  /// `TrackDao.addTracks` takes points rather than a file: deciding what is
  /// stored is `prepareAttachment`'s job, it is pure, and it has no database
  /// under it.
  Future<int> addAttachment(
    PreparedAttachment prepared, {
    int? itemId,
    int? groupId,
  }) {
    final owner = _owner(itemId: itemId, groupId: groupId);
    return transaction(() async {
      final existing =
          await (selectOnly(attachments)
                ..addColumns([attachments.sortOrder.max()])
                ..where(
                  itemId != null
                      ? attachments.itemId.equals(itemId)
                      : attachments.groupId.equals(groupId!),
                ))
              .map((row) => row.read(attachments.sortOrder.max()))
              .getSingleOrNull();
      final id = await into(attachments).insert(
        AttachmentsCompanion.insert(
          itemId: owner.itemId,
          groupId: owner.groupId,
          kind: prepared.kind,
          mimeType: prepared.mimeType,
          name: Value(prepared.name),
          byteSize: prepared.byteSize,
          width: Value(prepared.width),
          height: Value(prepared.height),
          lat: Value(prepared.position?.latitude),
          lon: Value(prepared.position?.longitude),
          positionSource: Value(prepared.positionSource),
          thumbnail: Value(prepared.thumbnail),
          sortOrder: Value((existing ?? -1) + 1),
        ),
      );
      await into(attachmentBlobs).insert(
        AttachmentBlobsCompanion.insert(
          attachmentId: Value(id),
          bytes: prepared.bytes,
        ),
      );
      return id;
    });
  }

  /// Removes one attachment; the payload follows by cascade.
  Future<int> deleteAttachment(int id) =>
      (delete(attachments)..where((a) => a.id.equals(id))).go();

  Future<void> renameAttachment(int id, String? name) =>
      (update(attachments)..where((a) => a.id.equals(id))).write(
        AttachmentsCompanion(name: Value(name)),
      );

  /// Writes where a photo was taken, or clears it.
  ///
  /// The position and its provenance move together and are never half-written:
  /// [at] null clears both, since a source with nothing to describe would go on
  /// claiming the reading came from somewhere.
  Future<void> setAttachmentPosition(
    int id,
    LatLng? at, {
    AttachmentPositionSource source = AttachmentPositionSource.picked,
  }) => (update(attachments)..where((a) => a.id.equals(id))).write(
    AttachmentsCompanion(
      lat: Value(at?.latitude),
      lon: Value(at?.longitude),
      positionSource: Value(at == null ? null : source),
    ),
  );

  /// Takes the attachments of [itemIds] off their entries without deleting
  /// them, and returns the ids that were parked. For [rehomeAttachments].
  ///
  /// A row with neither owner is a state nothing outside a transaction may see —
  /// it belongs to no trip and appears in no list. It exists for the same reason
  /// `RoutineDao.replaceJourneyLegs` parks a rescued cost on the trip: the entry
  /// the file hangs on is about to be deleted, and its replacement does not exist
  /// yet.
  Future<List<int>> parkAttachmentsOf(List<int> itemIds) async {
    if (itemIds.isEmpty) return const [];
    final rows = await (select(
      attachments,
    )..where((a) => a.itemId.isIn(itemIds))).get();
    if (rows.isEmpty) return const [];
    await (update(attachments)..where((a) => a.itemId.isIn(itemIds))).write(
      const AttachmentsCompanion(itemId: Value(null), groupId: Value(null)),
    );
    return [for (final row in rows) row.id];
  }

  /// Hangs parked attachments back on something. See [parkAttachmentsOf].
  Future<void> rehomeAttachments(
    List<int> ids, {
    int? itemId,
    int? groupId,
  }) async {
    if (ids.isEmpty) return;
    final owner = _owner(itemId: itemId, groupId: groupId);
    await (update(attachments)..where((a) => a.id.isIn(ids))).write(
      AttachmentsCompanion(itemId: owner.itemId, groupId: owner.groupId),
    );
  }

  Selectable<Attachment> _ordered(Expression<bool> where) => select(attachments)
    ..where((_) => where)
    ..orderBy([
      (a) => OrderingTerm(expression: a.sortOrder),
      (a) => OrderingTerm(expression: a.id),
    ]);

  /// The one invariant the schema cannot state: exactly one owner.
  ({Value<int?> itemId, Value<int?> groupId}) _owner({
    int? itemId,
    int? groupId,
  }) {
    if ((itemId == null) == (groupId == null)) {
      throw ArgumentError(
        'An attachment belongs to exactly one of an item or a group.',
      );
    }
    return (itemId: Value(itemId), groupId: Value(groupId));
  }
}
