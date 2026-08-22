import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';

/// What one entry carries — the reading its own form does.
final itemAttachmentsProvider = StreamProvider.autoDispose
    .family<List<Attachment>, int>(
      (ref, itemId) =>
          ref.watch(repositoryProvider).watchAttachmentsForItem(itemId),
    );

/// What one run carries: the shared ticket, the booking for the whole journey.
final groupAttachmentsProvider = StreamProvider.autoDispose
    .family<List<Attachment>, int>(
      (ref, groupId) =>
          ref.watch(repositoryProvider).watchAttachmentsForGroup(groupId),
    );

/// What the trip itself carries — the insurance, the passport scan, a
/// routine's season ticket. Not the same question as
/// [tripAttachmentCountsProvider], which is about its entries and runs.
final tripAttachmentsProvider = StreamProvider.autoDispose
    .family<List<Attachment>, int>(
      (ref, tripId) =>
          ref.watch(repositoryProvider).watchAttachmentsForTrip(tripId),
    );

/// How many files hang on each entry and each run of one trip.
///
/// One stream for the whole trip rather than one per tile: a timeline draws
/// every entry of every visible day, and a family keyed by item id would open a
/// query per row.
final tripAttachmentCountsProvider = StreamProvider.autoDispose
    .family<({Map<int, int> byItem, Map<int, int> byGroup}), int>(
      (ref, tripId) =>
          ref.watch(repositoryProvider).watchAttachmentCountsForTrip(tripId),
    );

/// The positioned photos of one trip, for its map.
///
/// Carries each row's thumbnail, which is what the marker is drawn from — the
/// whole reason one is stored beside the picture rather than derived from it.
final tripPhotoMarkersProvider = StreamProvider.autoDispose
    .family<List<Attachment>, int>(
      (ref, tripId) =>
          ref.watch(repositoryProvider).watchPositionedPhotosForTrip(tripId),
    );

/// One attachment, live — for the sheet that renames and positions it, where
/// what is on screen has to be what is stored. Null once it is deleted.
final attachmentProvider = StreamProvider.autoDispose.family<Attachment?, int>(
  (ref, id) => ref.watch(repositoryProvider).watchAttachment(id),
);

/// The payload of one attachment — the only read that touches a full-size file,
/// so it is asked for by whatever is about to show or hand out the file and
/// never as part of a list.
///
/// `autoDispose`, emphatically: this is the one provider in the app that can
/// hold megabytes, and a viewer that has been closed must not go on holding the
/// photo it was showing.
final attachmentBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, int>(
      (ref, id) => ref.watch(repositoryProvider).readAttachmentBytes(id),
    );
