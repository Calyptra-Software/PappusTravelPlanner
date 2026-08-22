import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/daos/attachment_dao.dart'
    show AttachmentTally;
import 'package:travelplanner/features/attachments/application/attachment_providers.dart';
import 'package:travelplanner/features/attachments/application/cover_providers.dart';
import 'package:travelplanner/features/attachments/trip_gallery.dart';

/// Stands in for the attachment streams in any widget test that pumps a
/// timeline, a run's band, or the item form.
///
/// Drift's `.watch()` schedules a zero-duration timer when a query stream is
/// *cancelled* (`StreamQueryStore.markAsClosed`), and under `flutter_test`'s
/// fake-async clock a test that ends on the disposal of its tree leaves that
/// timer pending — which the binding reports as a failure. It is the same
/// hazard `AGENTS.md` describes for reading the real database from a widget
/// test, arriving through teardown rather than through a stream that never
/// emits.
///
/// So the six providers the attachment UI watches are replaced with plain
/// streams. Every one of them says "nothing attached", which is what these
/// tests are about: they exercise the plan, and an attachment badge that never
/// appears is exactly the state they assume. A test that is *about* attachments
/// uses the DAO (`attachment_dao_test.dart`) or overrides these itself.
/// The element type is `Override`, which `flutter_riverpod` does not export by
/// name; inference from the literal gets there without it.
final attachmentTestOverrides = [
  itemAttachmentsProvider.overrideWith(
    (ref, id) => Stream.value(const <Attachment>[]),
  ),
  groupAttachmentsProvider.overrideWith(
    (ref, id) => Stream.value(const <Attachment>[]),
  ),
  // The timeline's photo shortcut reads this, and it is a plain `Provider`
  // rather than a stream — but it *watches* the ones above, so overriding it
  // too keeps a test that stubs only some of them from opening a real query.
  tripGalleryProvider.overrideWith((ref, id) => const <GalleryPhoto>[]),
  tripPhotosProvider.overrideWith(
    (ref, id) => Stream.value(const <Attachment>[]),
  ),
  tripAttachmentsProvider.overrideWith(
    (ref, id) => Stream.value(const <Attachment>[]),
  ),
  tripAttachmentCountsProvider.overrideWith(
    (ref, id) => Stream.value((
      byItem: <int, AttachmentTally>{},
      byGroup: <int, AttachmentTally>{},
    )),
  ),
];
