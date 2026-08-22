import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/byte_format.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../application/attachment_providers.dart';
import '../attachment_flow.dart';
import '../presentation/attachment_sheet.dart';

/// Opens what a whole run carries, from the label above it.
///
/// A sheet of its own rather than a section of some member's form: a run has no
/// form, and picking one of its legs to hold the shared ticket would be the same
/// accident the group menu exists to undo.
Future<void> showGroupAttachmentsSheet(BuildContext context, int groupId) {
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
        child: SingleChildScrollView(child: AttachmentsField(groupId: groupId)),
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
  const AttachmentsField({super.key, this.itemId, this.groupId, this.tripId})
    : assert(
        (itemId == null ? 0 : 1) +
                (groupId == null ? 0 : 1) +
                (tripId == null ? 0 : 1) ==
            1,
        'An attachment belongs to exactly one of an item, a group, or a trip.',
      );

  final int? itemId;
  final int? groupId;
  final int? tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.attachmentsLabel, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        if (attachments.isEmpty)
          Text(
            l10n.attachmentsNone,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final attachment in attachments)
            AttachmentTile(
              attachment: attachment,
              onTap: () => showAttachmentSheet(context, attachment),
            ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => addAttachments(
                context,
                ref,
                itemId: itemId,
                groupId: groupId,
                tripId: tripId,
                photosOnly: true,
              ),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(l10n.attachmentsAddPhoto),
            ),
            TextButton.icon(
              onPressed: () => addAttachments(
                context,
                ref,
                itemId: itemId,
                groupId: groupId,
                tripId: tripId,
              ),
              icon: const Icon(Icons.attach_file),
              label: Text(l10n.attachmentsAddFile),
            ),
          ],
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
