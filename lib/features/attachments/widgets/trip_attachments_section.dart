import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../application/attachment_providers.dart';
import 'attachments_field.dart';

/// What the whole trip carries: the insurance, the passport scan, the visa, a
/// routine's season ticket.
///
/// A **section on the trip screen**, not an entry in its ⋮ menu, and that is the
/// one decision here. An attachment on an entry or a run announces itself with a
/// badge on the timeline row it hangs on; the trip has no row, so a file filed at
/// this level appears nowhere at all unless the screen shows it. Behind a menu it
/// would be the insurance nobody can find in the one situation it exists for.
///
/// Collapsed to a single line while there is nothing, so a trip that has never
/// used the feature costs one row rather than a heading and an empty state. The
/// button is the heading: there is nothing to say about no files.
class TripAttachmentsSection extends ConsumerWidget {
  const TripAttachmentsSection({
    super.key,
    required this.tripId,
    required this.accent,
  });

  final int tripId;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final attachments = ref.watch(tripAttachmentsProvider(tripId)).value;

    // Nothing yet — and nothing while the first read is in flight, so the row
    // does not appear and then rearrange itself under the reader's finger.
    if (attachments == null || attachments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => showTripAttachmentsSheet(context, tripId),
            icon: const Icon(Icons.attach_file),
            label: Text(l10n.attachmentsTripAdd),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => showTripAttachmentsSheet(context, tripId),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.attach_file, size: 20, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.attachmentsTripTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  l10n.attachmentsCount(attachments.length),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The trip's own files, in the same field an entry and a run use — one list,
/// one set of acts, wherever it was opened from.
Future<void> showTripAttachmentsSheet(BuildContext context, int tripId) {
  return showAppSheet<void>(
    context,
    builder: (_) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(child: AttachmentsField(tripId: tripId)),
      ),
    ),
  );
}
