import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/byte_format.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../application/attachment_providers.dart';
import '../attachment_flow.dart';
import '../presentation/attachment_sheet.dart';
import '../presentation/gallery_screen.dart';
import '../trip_gallery.dart';

/// Opens the documents of one entry, from the line under it.
///
/// A gallery is for the photographs; this is the other half — the tickets and
/// the bookings, in a list from which each one goes on to whatever program
/// understands it. A document that is a picture is here too, by the rule that
/// what it *is* was decided at the door it came through: tapping it opens a
/// gallery of this entry's picture-documents, so a `.png` ticket can still be
/// looked at without pretending to be a photograph of the trip.
Future<void> showItemDocumentsSheet(BuildContext context, int itemId) =>
    _showAttachmentsSheet(
      context,
      AttachmentsField(itemId: itemId, only: AttachmentKind.document),
    );

/// The same, for a run: its shared tickets.
Future<void> showGroupDocumentsSheet(BuildContext context, int groupId) =>
    _showAttachmentsSheet(
      context,
      AttachmentsField(groupId: groupId, only: AttachmentKind.document),
    );

/// Opens what a whole run carries, from the label above it.
///
/// A sheet of its own rather than a section of some member's form: a run has no
/// form, and picking one of its legs to hold the shared ticket would be the same
/// accident the group menu exists to undo.
Future<void> showGroupAttachmentsSheet(BuildContext context, int groupId) =>
    _showAttachmentsSheet(context, AttachmentsField(groupId: groupId));

/// The frame all three share: a scrolling sheet holding one field.
Future<void> _showAttachmentsSheet(BuildContext context, Widget field) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(child: field),
      ),
    ),
  );
}

/// The files hanging on one entry or one run, in the form that edits it.
///
/// Offered on something that **already exists**, for the reason [TrackField]
/// is: an attachment hangs off a row, and a form being filled in for a new entry
/// has no row yet. Not a hardship — attaching the ticket is something done about
/// a leg that is already in the plan.
///
/// Exactly one of [itemId], [groupId] and [tripId] is set: an attachment
/// belongs to an entry, to a run, or to the trip, never to two of them. The
/// run's is reached from the label above it, where everything about a run is
/// done; the trip's from its own section on the trip screen, since a file filed
/// there appears on no timeline row and would be forgotten behind a menu.
class AttachmentsField extends ConsumerWidget {
  const AttachmentsField({
    super.key,
    this.itemId,
    this.groupId,
    this.tripId,
    this.only,
  }) : assert(
         (itemId == null ? 0 : 1) +
                 (groupId == null ? 0 : 1) +
                 (tripId == null ? 0 : 1) ==
             1,
         'An attachment belongs to exactly one of an item, a group, or a trip.',
       );

  final int? itemId;
  final int? groupId;
  final int? tripId;

  /// Narrows the list — and the *Add* buttons — to one kind. Null lists
  /// everything, which is what the item form wants; the documents sheet reached
  /// from the timeline sets it, since the photographs there are already one tap
  /// away in the gallery beside it.
  final AttachmentKind? only;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final attachments =
        ref
            .watch(
              itemId != null
                  ? itemAttachmentsProvider(itemId!)
                  : groupId != null
                  ? groupAttachmentsProvider(groupId!)
                  : tripAttachmentsProvider(tripId!),
            )
            .value ??
        const <Attachment>[];

    List<Attachment> of(AttachmentKind kind) => [
      for (final a in attachments)
        if (a.kind == kind) a,
    ];

    // Narrowed to one kind — the documents sheet reached from the timeline —
    // there is one section and no heading to choose between.
    if (only case final kind?) {
      return _Section(
        title: kind == AttachmentKind.photo
            ? l10n.photosTitle
            : l10n.documentsTitle,
        attachments: of(kind),
        addLabel: kind == AttachmentKind.photo
            ? l10n.attachmentsAddPhoto
            : l10n.attachmentsAddFile,
        addIcon: kind == AttachmentKind.photo
            ? Icons.add_photo_alternate_outlined
            : Icons.attach_file,
        onAdd: () => _add(context, ref, kind),
      );
    }

    // Two headed sections rather than one list under "Attachments". They are
    // two different things to have — one is looked at, the other is opened —
    // and a flat list made the reader sort a ticket from a photograph by its
    // icon. Each carries its own *Add*, so which door a file comes through (and
    // therefore what it becomes) is chosen where the thing itself is listed.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: l10n.photosTitle,
          attachments: of(AttachmentKind.photo),
          addLabel: l10n.attachmentsAddPhoto,
          addIcon: Icons.add_photo_alternate_outlined,
          onAdd: () => _add(context, ref, AttachmentKind.photo),
        ),
        const SizedBox(height: 8),
        _Section(
          title: l10n.documentsTitle,
          attachments: of(AttachmentKind.document),
          addLabel: l10n.attachmentsAddFile,
          addIcon: Icons.attach_file,
          onAdd: () => _add(context, ref, AttachmentKind.document),
        ),
      ],
    );
  }

  void _add(BuildContext context, WidgetRef ref, AttachmentKind kind) {
    addAttachments(
      context,
      ref,
      itemId: itemId,
      groupId: groupId,
      tripId: tripId,
      kind: kind,
    );
  }
}

/// One headed list of files, with the button that adds another of its kind.
///
/// An empty section is its heading and its button, and nothing else: there is
/// no line saying "nothing here", because a heading over an invitation already
/// says it — and two of those, one per kind, would be noise where the point is
/// to see at a glance what there is.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.attachments,
    required this.addLabel,
    required this.addIcon,
    required this.onAdd,
  });

  final String title;
  final List<Attachment> attachments;
  final String addLabel;
  final IconData addIcon;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // What a gallery opened from this section walks: its own pictures, in the
    // order they are listed. A document that is a picture is here too — filed
    // under documents, and still something that can be looked at.
    final viewable = [
      for (final a in attachments)
        if (a.isViewable) a,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: theme.textTheme.labelLarge),
            if (attachments.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                '${attachments.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        for (final attachment in attachments)
          AttachmentTile(
            attachment: attachment,
            // A picture opens the gallery of *this section*, at itself; a file
            // nothing can draw opens the sheet, there being nothing to leaf
            // through. No `tripId` either way: a gallery opened here is about
            // one entry's files, and a document is not the trip's photograph,
            // so the cover star has no business in it.
            onTap: () => attachment.isViewable
                ? showGallery(
                    context,
                    photos: [
                      for (final a in viewable) GalleryPhoto(attachment: a),
                    ],
                    initialIndex: viewable.indexOf(attachment),
                  )
                : showAttachmentSheet(context, attachment),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onAdd,
            icon: Icon(addIcon),
            label: Text(addLabel),
          ),
        ),
      ],
    );
  }
}

/// One attachment as a row: what it is, what it costs, and a way in.
///
/// A photo shows its stored thumbnail rather than a scaled-down original — the
/// whole reason one is kept beside it — and a document shows an icon, because
/// there is nothing else it can honestly show.
class AttachmentTile extends StatelessWidget {
  const AttachmentTile({super.key, required this.attachment, this.onTap});

  final Attachment attachment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final thumbnail = attachment.thumbnail;
    final positioned = attachment.lat != null && attachment.lon != null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: SizedBox(
        width: 44,
        height: 44,
        child: thumbnail != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(thumbnail, fit: BoxFit.cover),
              )
            : Icon(
                attachment.kind == AttachmentKind.photo
                    ? Icons.image_outlined
                    : Icons.insert_drive_file_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
      ),
      title: Text(
        attachment.name ?? l10n.attachmentsLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        formatBytes(attachment.byteSize),
        style: theme.textTheme.bodySmall,
      ),
      // A pin and nothing more: that the photo has a position is worth showing
      // in a list, where it came from is not — that is a question for the sheet.
      trailing: positioned
          ? Icon(
              Icons.place_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            )
          : null,
      onTap: onTap,
    );
  }
}
