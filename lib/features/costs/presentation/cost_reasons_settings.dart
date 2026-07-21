import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/text_prompt_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../application/cost_display_provider.dart';
import '../application/cost_providers.dart';
import '../cost_reason_icons.dart';

/// Settings block to manage saved cost reasons: choose how reasons render on
/// cost chips (icon / text / both), and add, delete, or re-icon each reason.
class CostReasonsSettings extends ConsumerWidget {
  const CostReasonsSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final display = ref.watch(costReasonDisplayProvider);
    final rows = ref.watch(reasonRowsProvider).value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<CostReasonDisplay>(
              segments: [
                ButtonSegment(
                  value: CostReasonDisplay.icon,
                  icon: const Icon(Icons.image_outlined),
                  label: Text(l10n.costReasonDisplayIcon),
                ),
                ButtonSegment(
                  value: CostReasonDisplay.text,
                  icon: const Icon(Icons.title),
                  label: Text(l10n.costReasonDisplayText),
                ),
                ButtonSegment(
                  value: CostReasonDisplay.both,
                  icon: const Icon(Icons.view_agenda_outlined),
                  label: Text(l10n.costReasonDisplayBoth),
                ),
              ],
              selected: {display},
              onSelectionChanged: (selection) => ref
                  .read(costReasonDisplayProvider.notifier)
                  .setDisplay(selection.first),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            l10n.costReasonDisplayHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (rows.isEmpty)
          ListTile(
            title: Text(
              l10n.noCostReasons,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final row in rows)
            ListTile(
              leading: IconButton(
                icon: Icon(iconForReason(row.iconId)),
                tooltip: l10n.costReasonChooseIcon,
                onPressed: () => _chooseIcon(context, ref, row.label),
              ),
              title: Text(row.label),
              onTap: () => _renameReason(context, ref, row.label),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                color: theme.colorScheme.error,
                tooltip: l10n.delete,
                onPressed: () => _confirmDelete(context, ref, row.label),
              ),
            ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.costReasonAdd),
              onPressed: () => _addReason(context, ref),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addReason(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final label = await showTextPromptDialog(
      context,
      title: l10n.costReasonAddTitle,
      label: l10n.costReasonLabel,
      hint: l10n.costReasonHint,
    );
    if (label == null || label.isEmpty) return;
    await ref.read(costControllerProvider).addReason(label);
  }

  Future<void> _renameReason(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final label = await showTextPromptDialog(
      context,
      title: l10n.costReasonRenameTitle,
      label: l10n.costReasonLabel,
      initial: current,
    );
    if (label == null || label.isEmpty || label == current) return;
    await ref.read(costControllerProvider).renameReason(current, label);
  }

  Future<void> _chooseIcon(
    BuildContext context,
    WidgetRef ref,
    String label,
  ) async {
    final iconId = await showCostReasonIconPicker(context);
    // A -1 sentinel means "no icon"; null means the dialog was dismissed.
    if (iconId == null) return;
    await ref
        .read(costControllerProvider)
        .setReasonIcon(label, iconId < 0 ? null : iconId);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String label,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.costReasonDeleteConfirmTitle),
        content: Text(l10n.costReasonDeleteConfirmBody(label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(costControllerProvider).deleteReason(label);
  }
}

/// Shows the curated icon grid. Resolves to the chosen icon id, `-1` for the
/// "no icon" (default) choice, or `null` if dismissed.
Future<int?> showCostReasonIconPicker(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.costReasonChooseIcon),
      content: SizedBox(
        width: 320,
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            // "No icon" (default) choice, then the curated set.
            IconButton(
              icon: Icon(
                kDefaultCostReasonIcon,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.pop(context, -1),
            ),
            for (final entry in kCostReasonIcons.entries)
              IconButton(
                icon: Icon(entry.value),
                onPressed: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    ),
  );
}
