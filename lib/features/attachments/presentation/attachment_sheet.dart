import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/format/byte_format.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../../map/presentation/map_picker_screen.dart';
import '../application/attachment_providers.dart';
import '../attachment_flow.dart';

/// Opens one attachment: the picture at the size the app kept it, or a document
/// with the one thing that can be done to it — hand it to a program that
/// understands the format.
Future<void> showAttachmentSheet(BuildContext context, Attachment attachment) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => AttachmentSheet(attachment: attachment),
  );
}

/// What one attachment is, and the four things that can be done to it.
///
/// A **reading with edits**, unlike `MapItemSheet`, which is a reading alone:
/// there is no other form that owns a file. Renaming, positioning, handing it
/// out and deleting it all happen here, because here is the only place the file
/// exists as something to act on.
///
/// The bytes are read only once this is open — they are the one thing in the app
/// that can be megabytes, and a list must never pull them.
class AttachmentSheet extends ConsumerWidget {
  const AttachmentSheet({super.key, required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // The row as the database holds it: this sheet writes the name and the
    // position, and a value that stays as it was when the tile was tapped would
    // look like the edit missed. Falls back to what it was opened with while the
    // first read is in flight, and if the row is gone the sheet simply closes.
    final live =
        ref.watch(attachmentProvider(attachment.id)).value ?? attachment;
    final position = live.lat != null && live.lon != null
        ? LatLng(live.lat!, live.lon!)
        : null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              live.name ?? l10n.attachmentsLabel,
              style: theme.textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              [
                formatBytes(live.byteSize),
                if (live.width != null && live.height != null)
                  '${live.width}×${live.height}',
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (live.kind == AttachmentKind.photo)
              _Picture(attachment: live)
            else
              _DocumentPlaceholder(mimeType: live.mimeType),
            const SizedBox(height: 12),
            // Photographs only: a document is a file, not a place — whatever
            // it is a picture of — so a `.png` ticket is offered no position to
            // put on the map. `AttachmentDao.setAttachmentPosition` refuses one
            // as well, so this is the visible half of a rule with a floor under
            // it.
            if (live.kind == AttachmentKind.photo)
              _PositionRow(attachment: live, position: position),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => shareAttachment(context, ref, live),
                  icon: const Icon(Icons.ios_share),
                  label: Text(l10n.attachmentShare),
                ),
                TextButton.icon(
                  onPressed: () => _rename(context, ref, live),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.attachmentRename),
                ),
                TextButton.icon(
                  onPressed: () => _delete(context, ref, live),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.attachmentDelete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Attachment attachment,
  ) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: attachment.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.attachmentRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.attachmentNameLabel),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (name == null) return;
    final trimmed = name.trim();
    await ref
        .read(repositoryProvider)
        .renameAttachment(attachment.id, trimmed.isEmpty ? null : trimmed);
  }

  /// Deleting asks first, and the question says why: the file is here and
  /// nowhere else, which is the whole point of storing it in the database and
  /// the one thing that makes this delete different from removing a note.
  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Attachment attachment,
  ) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.attachmentDeleteQuestion),
        content: Text(l10n.attachmentDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.attachmentDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(repositoryProvider).deleteAttachment(attachment.id);
    navigator.pop();
  }
}

/// The picture, at the size it is stored.
///
/// Capped at a third of the screen so the actions underneath stay reachable: a
/// sheet that has to be scrolled to reach *Delete* is one where the picture has
/// taken over from the thing it is attached to.
class _Picture extends ConsumerWidget {
  const _Picture({required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(attachmentBytesProvider(attachment.id));
    final maxHeight = MediaQuery.sizeOf(context).height / 3;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: bytes.when(
          data: (data) => data == null
              ? const SizedBox.shrink()
              : Image.memory(data, fit: BoxFit.contain),
          // The thumbnail is already in hand, so the full picture arriving is a
          // sharpening rather than a blank waiting to be filled.
          loading: () => attachment.thumbnail == null
              ? const SizedBox(height: 80)
              : Image.memory(attachment.thumbnail!, fit: BoxFit.contain),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _DocumentPlaceholder extends StatelessWidget {
  const _DocumentPlaceholder({required this.mimeType});

  final String mimeType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(mimeType, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// Where the photo says it was taken, and the two ways that can change.
///
/// The provenance is spelled out rather than implied: a reading out of the
/// file's EXIF is where the *camera* stood, which is near the subject and may be
/// an old fix, while a position pointed at on the map is a statement. They are
/// not the same claim, and the app does not quietly upgrade one into the other.
class _PositionRow extends ConsumerWidget {
  const _PositionRow({required this.attachment, required this.position});

  final Attachment attachment;
  final LatLng? position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final source = attachment.positionSource;
    final label = position == null
        ? l10n.attachmentPositionNone
        : switch (source) {
            AttachmentPositionSource.exif => l10n.attachmentPositionExif,
            _ => l10n.attachmentPositionPicked,
          };

    return Row(
      children: [
        Icon(
          position == null ? Icons.location_off_outlined : Icons.place_outlined,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            position == null
                ? label
                : '$label · ${position!.latitude.toStringAsFixed(5)}, '
                      '${position!.longitude.toStringAsFixed(5)}',
            style: theme.textTheme.bodySmall,
          ),
        ),
        IconButton(
          tooltip: l10n.attachmentPositionSet,
          icon: const Icon(Icons.edit_location_alt_outlined),
          onPressed: () async {
            final picked = await pickPointOnMap(
              context,
              title: l10n.attachmentPositionSet,
              initial: position,
            );
            if (picked == null) return;
            await ref
                .read(repositoryProvider)
                .setAttachmentPosition(attachment.id, picked);
          },
        ),
        if (position != null)
          IconButton(
            tooltip: l10n.attachmentPositionClear,
            icon: const Icon(Icons.location_off_outlined),
            onPressed: () => ref
                .read(repositoryProvider)
                .setAttachmentPosition(attachment.id, null),
          ),
      ],
    );
  }
}
