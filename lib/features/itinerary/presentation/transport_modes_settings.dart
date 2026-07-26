import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/text_prompt_dialog.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../application/transport_mode_providers.dart';
import '../widgets/transport_mode.dart';

/// Settings block to manage the reusable transport modes: reorder them, add new
/// ones, rename or re-icon any of them (built-ins included), and delete the ones
/// not wanted. The transport counterpart to `CostReasonsSettings`.
class TransportModesSettings extends ConsumerWidget {
  const TransportModesSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final modes = ref.watch(transportModesProvider).value ?? const [];
    // Built-ins the user has deleted — offered back so an accidental delete has
    // a one-tap, identity-preserving undo (a hand-added same-named mode would
    // not restore the builtinKey the sharing bundle and search mapping rely on).
    final presentKeys = {
      for (final m in modes)
        if (m.builtinKey != null) m.builtinKey,
    };
    final missingBuiltins = [
      for (final mode in kTransportModeOrder)
        if (!presentKeys.contains(mode.name)) mode,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (modes.isEmpty)
          ListTile(
            title: Text(
              l10n.noTransportModes,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            // newIndex is already adjusted for the removal at oldIndex
            // (onReorderItem semantics), so it drops straight in.
            onReorderItem: (oldIndex, newIndex) {
              final ids = [for (final m in modes) m.id];
              ids.insert(newIndex, ids.removeAt(oldIndex));
              ref.read(transportModeControllerProvider).reorderModes(ids);
            },
            children: [
              for (final (index, mode) in modes.indexed)
                ListTile(
                  key: ValueKey(mode.id),
                  leading: IconButton(
                    icon: Icon(mode.icon),
                    tooltip: l10n.transportModeChooseIcon,
                    onPressed: () => _chooseIcon(context, ref, mode),
                  ),
                  title: Text(mode.label(l10n)),
                  onTap: () =>
                      _renameMode(context, ref, mode.id, mode.label(l10n)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: theme.colorScheme.error,
                        tooltip: l10n.delete,
                        onPressed: () => _confirmDelete(
                          context,
                          ref,
                          mode.id,
                          mode.label(l10n),
                        ),
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.transportModeAdd),
                onPressed: () => _addMode(context, ref),
              ),
              if (missingBuiltins.isNotEmpty) ...[
                const Spacer(),
                PopupMenuButton<TransportMode>(
                  tooltip: l10n.transportModeRestoreBuiltin,
                  onSelected: (mode) => ref
                      .read(transportModeControllerProvider)
                      .restoreBuiltinMode(mode),
                  itemBuilder: (context) => [
                    for (final mode in missingBuiltins)
                      PopupMenuItem(
                        value: mode,
                        child: Row(
                          children: [
                            Icon(mode.icon),
                            const SizedBox(width: 12),
                            Text(mode.label(l10n)),
                          ],
                        ),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.restore, size: 18),
                        const SizedBox(width: 4),
                        Text(l10n.transportModeRestoreBuiltin),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addMode(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final name = await _promptName(
      context,
      title: l10n.transportModeAddTitle,
      hint: l10n.transportModeHint,
    );
    if (name == null || name.isEmpty) return;
    await ref.read(transportModeControllerProvider).addMode(name);
  }

  Future<void> _renameMode(
    BuildContext context,
    WidgetRef ref,
    int id,
    String current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final name = await _promptName(
      context,
      title: l10n.transportModeRenameTitle,
      initial: current,
    );
    if (name == null || name.isEmpty || name == current) return;
    await ref.read(transportModeControllerProvider).renameMode(id, name);
  }

  Future<void> _chooseIcon(
    BuildContext context,
    WidgetRef ref,
    TransportModeRow mode,
  ) async {
    final iconId = await showTransportModeIconPicker(
      context,
      // Only a built-in has an icon of its own to fall back to; a custom mode's
      // default is the generic three-dots the grid already offers.
      defaultIcon: mode.builtinKey == null ? null : mode.defaultIcon,
    );
    // A -1 sentinel means "default icon"; null means the dialog was dismissed.
    if (iconId == null) return;
    await ref
        .read(transportModeControllerProvider)
        .setModeIcon(mode.id, iconId < 0 ? null : iconId);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int id,
    String label,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.transportModeDeleteConfirmTitle),
        content: Text(l10n.transportModeDeleteConfirmBody(label)),
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
    await ref.read(transportModeControllerProvider).deleteMode(id);
  }

  /// Shared name prompt for add and rename.
  Future<String?> _promptName(
    BuildContext context, {
    required String title,
    String? initial,
    String? hint,
  }) {
    return showTextPromptDialog(
      context,
      title: title,
      label: AppLocalizations.of(context).transportModeLabel,
      hint: hint,
      initial: initial,
    );
  }
}

/// Shows the curated transport-icon grid. Resolves to the chosen icon id, `-1`
/// for the "use the default" choice, or `null` if dismissed.
///
/// [defaultIcon] is the icon the mode falls back to when it has none of its own
/// — a built-in's own icon. Passing it prepends the "use the default" choice,
/// drawn *as that very icon* (just muted) so the button shows exactly what
/// picking it gives.
///
/// It is deliberately omitted for a custom mode: its default is the generic
/// three-dots already offered at the end of the grid, so the choice would be a
/// second route to an identical result — which is what made a struck-through
/// "none" glyph hand back three dots.
Future<int?> showTransportModeIconPicker(
  BuildContext context, {
  IconData? defaultIcon,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.transportModeChooseIcon),
      content: SizedBox(
        width: 320,
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            if (defaultIcon != null)
              IconButton(
                icon: Icon(
                  defaultIcon,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: () => Navigator.pop(context, -1),
              ),
            for (final entry in kTransportModeIcons.entries)
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
