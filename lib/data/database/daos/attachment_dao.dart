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
/// exactly one of an item, a group, or the trip ([Attachments]), which is one
/// invariant with no way to express it in the schema, so every write here goes
/// through [_owner] and no caller assembles a companion of its own.
@DriftAccessor(
  tables: [Attachments, AttachmentBlobs, ItineraryItems, ItemGroups, Trips],
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
  ///
  /// Counted **by kind**: the timeline shows the two apart, because a photograph
  /// is looked at and a document is opened, and one number covering both answers
  /// neither question.
  Stream<
    ({Map<int, AttachmentTally> byItem, Map<int, AttachmentTally> byGroup})
  >
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
            attachments.kind,
            attachments.id.count(),
          ])
          ..where(
            itineraryItems.tripId.equals(tripId) |
                itemGroups.tripId.equals(tripId),
          )
          ..groupBy([
            attachments.itemId,
            attachments.groupId,
            attachments.kind,
          ]);
    return query.watch().map((rows) {
      final byItem = <int, AttachmentTally>{};
      final byGroup = <int, AttachmentTally>{};
      for (final row in rows) {
        final count = row.read(attachments.id.count()) ?? 0;
        // `selectOnly` hands back the stored integer rather than the enum, so
        // the comparison is against the index the column holds.
        final photos = row.read(attachments.kind) == AttachmentKind.photo.index;
        final itemId = row.read(attachments.itemId);
        final groupId = row.read(attachments.groupId);
        if (itemId != null) {
          byItem[itemId] = (byItem[itemId] ?? const AttachmentTally()).plus(
            photos: photos ? count : 0,
            documents: photos ? 0 : count,
          );
        }
        if (groupId != null) {
          byGroup[groupId] = (byGroup[groupId] ?? const AttachmentTally()).plus(
            photos: photos ? count : 0,
            documents: photos ? 0 : count,
          );
        }
      }
      return (byItem: byItem, byGroup: byGroup);
    });
  }

  /// What the trip itself carries: the insurance, the passport scan, a
  /// routine's season ticket — the files that belong to the journey rather than
  /// to any one part of it.
  ///
  /// Only those. An entry's and a run's are read by the two above, because the
  /// three are edited in three different places, and a list that mixed them
  /// would be a fourth place showing files nobody could act on from there.
  Stream<List<Attachment>> watchAttachmentsForTrip(int tripId) =>
      _ordered(attachments.tripId.equals(tripId)).watch();

  /// Every photo of one trip, wherever it hangs — what the gallery reads.
  ///
  /// Documents are left out: a gallery is of pictures, and a row saying
  /// `ticket.pdf` between two photographs is a file the reader cannot look at.
  Stream<List<Attachment>> watchPhotosForTrip(int tripId) =>
      _photosForTrip(tripId, positionedOnly: false);

  /// The subset of those that carry a position — what the map draws.
  Stream<List<Attachment>> watchPositionedPhotosForTrip(int tripId) =>
      _photosForTrip(tripId, positionedOnly: true);

  /// Deliberately **not** filtered by the live rule here, unlike
  /// `TrackDao.watchTracksForTrip`: whether a picture belongs on the map — or in
  /// the gallery — is a question about the entry it hangs off, and both screens
  /// already hold the trip's live entries. Answering it in SQL as well would be
  /// a second copy of a definition that `live_items.dart` owns; see
  /// `_photoMarkers` and `tripGallery`, which are the two places that apply it.
  Stream<List<Attachment>> _photosForTrip(
    int tripId, {
    required bool positionedOnly,
  }) {
    final query =
        select(attachments).join([
            leftOuterJoin(
              itineraryItems,
              itineraryItems.id.equalsExp(attachments.itemId),
            ),
            leftOuterJoin(
              itemGroups,
              itemGroups.id.equalsExp(attachments.groupId),
            ),
          ])
          ..where(
            // The trip's own files count here too: a picture hung on the trip
            // rather than on one of its entries is no less part of it, and
            // being on the map is a question about the position it carries.
            (itineraryItems.tripId.equals(tripId) |
                    itemGroups.tripId.equals(tripId) |
                    attachments.tripId.equals(tripId)) &
                attachments.kind.equalsValue(AttachmentKind.photo) &
                (positionedOnly
                    ? attachments.lat.isNotNull() & attachments.lon.isNotNull()
                    : const Constant(true)),
          )
          ..orderBy([
            OrderingTerm(expression: attachments.sortOrder),
            OrderingTerm(expression: attachments.id),
          ]);
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(attachments)).toList(),
    );
  }

  /// How many attachments the whole database holds, and what they weigh.
  ///
  /// Reads [Attachments.byteSize] rather than the payloads — which is the whole
  /// point of storing that number beside the row instead of asking the blob how
  /// long it is. Across every trip, because the question it answers is about the
  /// *file*: what it costs to copy, back up, or hand to another device.
  Future<({int count, int bytes})> attachmentStorage() async {
    final count = attachments.id.count();
    final total = attachments.byteSize.sum();
    final row = await (selectOnly(
      attachments,
    )..addColumns([count, total])).getSingle();
    return (count: row.read(count) ?? 0, bytes: row.read(total)?.toInt() ?? 0);
  }

  /// What every trip's overview card would need to choose a cover from — the
  /// photos' ids and where each one sits, and **no thumbnails**.
  ///
  /// The blob is left out on purpose. There is one query for the whole overview
  /// (a query per card is the thing `watchPositionedItems` and `watchAllTracks`
  /// exist to avoid), and a database with two hundred photographs would
  /// otherwise push three megabytes through it on every tick to pick a dozen
  /// pictures. The caller works out which ids it wants and then asks for those
  /// with [thumbnailsFor] — the same metadata-and-payload split
  /// [AttachmentBlobs] makes, one level up.
  ///
  /// Unfiltered by the live rule, as everything here is: the caller holds the
  /// entries and `tripGallery` applies it.
  Stream<List<CoverCandidate>> watchCoverCandidates() {
    final query =
        select(attachments).join([
            leftOuterJoin(
              itineraryItems,
              itineraryItems.id.equalsExp(attachments.itemId),
            ),
            leftOuterJoin(
              itemGroups,
              itemGroups.id.equalsExp(attachments.groupId),
            ),
          ])
          ..addColumns([itineraryItems.tripId, itemGroups.tripId])
          ..where(attachments.kind.equalsValue(AttachmentKind.photo))
          ..orderBy([
            OrderingTerm(expression: attachments.sortOrder),
            OrderingTerm(expression: attachments.id),
          ]);
    return query.watch().map((rows) {
      final out = <CoverCandidate>[];
      for (final row in rows) {
        final attachment = row.readTable(attachments);
        final tripId =
            attachment.tripId ??
            row.read(itineraryItems.tripId) ??
            row.read(itemGroups.tripId);
        if (tripId == null) continue;
        out.add(CoverCandidate(tripId: tripId, attachment: attachment));
      }
      return out;
    });
  }

  /// The thumbnails of exactly [ids] — the second half of [watchCoverCandidates].
  Future<Map<int, Uint8List>> thumbnailsFor(List<int> ids) async {
    if (ids.isEmpty) return const {};
    final rows =
        await (selectOnly(attachments)
              ..addColumns([attachments.id, attachments.thumbnail])
              ..where(attachments.id.isIn(ids)))
            .get();
    return {
      for (final row in rows)
        if (row.read(attachments.thumbnail) != null)
          row.read(attachments.id)!: row.read(attachments.thumbnail)!,
    };
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
    int? tripId,
  }) {
    final owner = _owner(itemId: itemId, groupId: groupId, tripId: tripId);
    return transaction(() async {
      final existing =
          await (selectOnly(attachments)
                ..addColumns([attachments.sortOrder.max()])
                ..where(
                  _ownedBy(itemId: itemId, groupId: groupId, tripId: tripId),
                ))
              .map((row) => row.read(attachments.sortOrder.max()))
              .getSingleOrNull();
      final id = await into(attachments).insert(
        AttachmentsCompanion.insert(
          itemId: owner.itemId,
          groupId: owner.groupId,
          tripId: owner.tripId,
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

  /// Writes [orderedIds] as the order they are listed in.
  ///
  /// Numbered **per kind**, because that is how they are read: the field shows
  /// photographs and documents as two lists, and nothing anywhere compares a
  /// photograph's place against a document's. So reordering one leaves the
  /// other exactly as it was, and two attachments of one entry may share a
  /// sort order without meaning anything by it.
  ///
  /// The order is not only a list's: it decides which picture a gallery opens
  /// on, in which order the PDF prints them, and — where nobody has chosen a
  /// cover — which one the trip's card shows. Dragging a photograph to the
  /// front of a trip's own is therefore a way of making it the cover, and reads
  /// as one.
  Future<void> reorderAttachments(List<int> orderedIds) {
    return transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(attachments)..where((a) => a.id.equals(orderedIds[i])))
            .write(AttachmentsCompanion(sortOrder: Value(i)));
      }
    });
  }

  Future<void> renameAttachment(int id, String? name) =>
      (update(attachments)..where((a) => a.id.equals(id))).write(
        AttachmentsCompanion(name: Value(name)),
      );

  /// Writes where a photo was taken, or clears it.
  ///
  /// The position and its provenance move together and are never half-written:
  /// [at] null clears both, since a source with nothing to describe would go on
  /// claiming the reading came from somewhere.
  ///
  /// **Photographs only.** A document is a file, not a place — whatever it is a
  /// picture of — so the update passes over one rather than trusting every
  /// caller to check. Nothing offers it either; this is the floor under that.
  Future<void> setAttachmentPosition(
    int id,
    LatLng? at, {
    AttachmentPositionSource source = AttachmentPositionSource.picked,
  }) =>
      (update(attachments)..where(
            (a) => a.id.equals(id) & a.kind.equalsValue(AttachmentKind.photo),
          ))
          .write(
            AttachmentsCompanion(
              lat: Value(at?.latitude),
              lon: Value(at?.longitude),
              positionSource: Value(at == null ? null : source),
            ),
          );

  /// Copies the **trip-level** attachments of [fromTripId] onto [toTripId].
  ///
  /// The one level of ownership that travels with a copy, and only from a
  /// routine: everywhere else in this app a copy takes the plan and not the
  /// record, which is why an entry's photograph of last Tuesday's platform stays
  /// behind. A file on the *trip* of a routine is the template's own paperwork —
  /// the season ticket, the pass, the printed map — and a routine whose paperwork
  /// had to be re-attached every morning would be missing it by Thursday, which
  /// is the reasoning that already sends the checklist, the tags and the fare
  /// across.
  ///
  /// The rule is by **level**, not by kind. A scanned receipt and a season
  /// ticket are both documents and this app cannot tell them apart; where the
  /// user *put* the file is a decision they made, and it reads as one: on the
  /// routine means "needed every time", on a leg means "about that one morning".
  ///
  /// Called from `materializeRoutine` and the reversed duplicate, and — like
  /// `copyItemTracks` — deliberately from nowhere else. This is exactly where
  /// that kind of rule rots if it is not written down.
  Future<void> copyTripAttachments(int fromTripId, int toTripId) async {
    final source = await (select(
      attachments,
    )..where((a) => a.tripId.equals(fromTripId))).get();
    if (source.isEmpty) return;
    for (final row in source) {
      final bytes = await readAttachmentBytes(row.id);
      if (bytes == null) continue;
      final id = await into(attachments).insert(
        AttachmentsCompanion.insert(
          tripId: Value(toTripId),
          kind: row.kind,
          mimeType: row.mimeType,
          name: Value(row.name),
          byteSize: row.byteSize,
          width: Value(row.width),
          height: Value(row.height),
          lat: Value(row.lat),
          lon: Value(row.lon),
          positionSource: Value(row.positionSource),
          thumbnail: Value(row.thumbnail),
          sortOrder: Value(row.sortOrder),
        ),
      );
      await into(attachmentBlobs).insert(
        AttachmentBlobsCompanion.insert(attachmentId: Value(id), bytes: bytes),
      );
    }
  }

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
      const AttachmentsCompanion(
        itemId: Value(null),
        groupId: Value(null),
        tripId: Value(null),
      ),
    );
    return [for (final row in rows) row.id];
  }

  /// Hangs parked attachments back on something. See [parkAttachmentsOf].
  Future<void> rehomeAttachments(
    List<int> ids, {
    int? itemId,
    int? groupId,
    int? tripId,
  }) async {
    if (ids.isEmpty) return;
    final owner = _owner(itemId: itemId, groupId: groupId, tripId: tripId);
    await (update(attachments)..where((a) => a.id.isIn(ids))).write(
      AttachmentsCompanion(
        itemId: owner.itemId,
        groupId: owner.groupId,
        tripId: owner.tripId,
      ),
    );
  }

  Selectable<Attachment> _ordered(Expression<bool> where) => select(attachments)
    ..where((_) => where)
    ..orderBy([
      (a) => OrderingTerm(expression: a.sortOrder),
      (a) => OrderingTerm(expression: a.id),
    ]);

  /// The one invariant the schema cannot state: exactly one owner.
  ({Value<int?> itemId, Value<int?> groupId, Value<int?> tripId}) _owner({
    int? itemId,
    int? groupId,
    int? tripId,
  }) {
    final given = [itemId, groupId, tripId].nonNulls.length;
    if (given != 1) {
      throw ArgumentError(
        'An attachment belongs to exactly one of an item, a group, or a trip.',
      );
    }
    return (
      itemId: Value(itemId),
      groupId: Value(groupId),
      tripId: Value(tripId),
    );
  }

  /// The same one owner, as a predicate — for finding what an owner already
  /// holds. Assumes [_owner] has passed.
  Expression<bool> _ownedBy({int? itemId, int? groupId, int? tripId}) {
    if (itemId != null) return attachments.itemId.equals(itemId);
    if (groupId != null) return attachments.groupId.equals(groupId);
    return attachments.tripId.equals(tripId!);
  }
}

/// A photograph that could be a trip's cover, with the trip it belongs to.
///
/// The trip is resolved here because an attachment names one of three owners
/// and only one of them is the trip directly; the other two reach it through
/// the entry or the run. Carrying the answer means no screen has to join again.
final class CoverCandidate {
  const CoverCandidate({required this.tripId, required this.attachment});

  final int tripId;
  final Attachment attachment;
}

/// How many photographs and how many documents hang on one owner.
///
/// Two numbers rather than one, because the timeline shows them apart: a
/// photograph is looked at and a document is opened, and "5 attachments" tells
/// the reader neither of those things.
final class AttachmentTally {
  const AttachmentTally({this.photos = 0, this.documents = 0});

  final int photos;
  final int documents;

  AttachmentTally plus({int photos = 0, int documents = 0}) => AttachmentTally(
    photos: this.photos + photos,
    documents: this.documents + documents,
  );

  int get total => photos + documents;
}
