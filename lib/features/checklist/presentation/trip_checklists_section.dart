import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../core/widgets/text_prompt_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/application/trip_providers.dart';
import '../../trips/widgets/trip_picker.dart';
import '../application/checklist_providers.dart';

/// Shows a single-field text dialog, returning the entered value, or null if
/// dismissed.
Future<String?> _promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
}) {
  return showTextPromptDialog(
    context,
    title: title,
    hint: hint,
    initial: initial,
    confirmLabel: AppLocalizations.of(context).save,
  );
}

/// The trip's checklists shown in the detail header: any number of named,
/// collapsible checklists plus a button to add another.
class TripChecklistsSection extends ConsumerWidget {
  const TripChecklistsSection({
    super.key,
    required this.tripId,
    required this.accent,
  });

  final int tripId;
  final Color accent;

  Future<void> _addChecklist(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final name = await _promptText(
      context,
      title: l10n.checklistNewTitle,
      hint: l10n.checklist,
    );
    if (name == null) return;
    await ref
        .read(checklistControllerProvider)
        .addChecklist(tripId, title: name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final checklists = ref.watch(checklistsProvider(tripId)).value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final checklist in checklists)
          _ChecklistCard(
            key: ValueKey(checklist.id),
            checklist: checklist,
            accent: accent,
          ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: OutlinedButton.icon(
            onPressed: () => _addChecklist(context, ref),
            icon: const Icon(Icons.add),
            label: Text(l10n.checklistAdd),
          ),
        ),
      ],
    );
  }
}

/// What the checklist card's overflow menu offers.
enum _ChecklistAction { rename, duplicate, copyToTrip, moveToTrip, delete }

/// One collapsible checklist card: tickable, reorderable items with an inline
/// add field, plus rename/delete of the checklist itself.
class _ChecklistCard extends ConsumerStatefulWidget {
  const _ChecklistCard({
    super.key,
    required this.checklist,
    required this.accent,
  });

  final Checklist checklist;
  final Color accent;

  @override
  ConsumerState<_ChecklistCard> createState() => _ChecklistCardState();
}

class _ChecklistCardState extends ConsumerState<_ChecklistCard> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final label = _controller.text.trim();
    if (label.isEmpty) return;
    await ref
        .read(checklistControllerProvider)
        .addItem(widget.checklist.id, label);
    _controller.clear();
    // Keep the field focused so several items can be added in a row.
    _focusNode.requestFocus();
  }

  Future<void> _editItem(ChecklistItem item) async {
    final l10n = AppLocalizations.of(context);
    final result = await _promptText(
      context,
      title: l10n.checklistEditTitle,
      initial: item.label,
    );
    if (result == null) return;
    final trimmed = result.trim();
    if (trimmed.isEmpty || trimmed == item.label) return;
    await ref.read(checklistControllerProvider).renameItem(item, trimmed);
  }

  Future<void> _rename() async {
    final l10n = AppLocalizations.of(context);
    final result = await _promptText(
      context,
      title: l10n.checklistRenameTitle,
      initial: widget.checklist.title,
      hint: l10n.checklist,
    );
    if (result == null || result.trim() == widget.checklist.title) return;
    await ref
        .read(checklistControllerProvider)
        .renameChecklist(widget.checklist, result);
  }

  Future<void> _delete(int itemCount) async {
    final l10n = AppLocalizations.of(context);
    if (itemCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.checklistDeleteTitle),
          content: Text(l10n.checklistDeleteBody(_displayTitle(l10n))),
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
    }
    await ref
        .read(checklistControllerProvider)
        .deleteChecklist(widget.checklist.id);
  }

  /// Runs the overflow menu's choice. [itemCount] is only needed by delete,
  /// which asks first when the list isn't empty.
  void _onAction(_ChecklistAction action, int itemCount) {
    switch (action) {
      case _ChecklistAction.rename:
        _rename();
      case _ChecklistAction.duplicate:
        _duplicate();
      case _ChecklistAction.copyToTrip:
        _toAnotherTrip(copy: true);
      case _ChecklistAction.moveToTrip:
        _toAnotherTrip(copy: false);
      case _ChecklistAction.delete:
        _delete(itemCount);
    }
  }

  Future<void> _duplicate() async {
    final l10n = AppLocalizations.of(context);
    await ref
        .read(checklistControllerProvider)
        .duplicateChecklist(
          widget.checklist.id,
          widget.checklist.tripId,
          title: l10n.checklistCopyTitle(_displayTitle(l10n)),
        );
  }

  /// Copies or moves this checklist into another trip, asking which one.
  ///
  /// The copy arrives unticked — the point of reusing a packing list is to pack
  /// again — so the confirmation says as much rather than leaving it to be
  /// discovered.
  Future<void> _toAnotherTrip({required bool copy}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(checklistControllerProvider);

    // The trip it is already in is left out: copying a list to where it already
    // is is [_ChecklistAction.duplicate], which needs no dialog.
    final others = [
      for (final trip in ref.read(tripListProvider).value ?? const <Trip>[])
        if (trip.id != widget.checklist.tripId) trip,
    ];
    if (others.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.checklistNoOtherTrips)),
      );
      return;
    }
    final target = await showTripPicker(context, others);
    if (target == null) return;

    if (copy) {
      await controller.copyChecklistToTrip(widget.checklist.id, target.id);
    } else {
      await controller.moveChecklistToTrip(widget.checklist.id, target.id);
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          copy
              ? l10n.checklistCopiedTo(target.title)
              : l10n.checklistMovedTo(target.title),
        ),
      ),
    );
  }

  String _displayTitle(AppLocalizations l10n) =>
      widget.checklist.title.isNotEmpty
      ? widget.checklist.title
      : l10n.checklist;

  PopupMenuItem<_ChecklistAction> _menuItem(
    _ChecklistAction value,
    IconData icon,
    String label,
  ) => PopupMenuItem(
    value: value,
    child: ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20),
      title: Text(label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final items =
        ref.watch(checklistItemsProvider(widget.checklist.id)).value ??
        const [];
    final doneCount = items.where((i) => i.done).length;
    final expanded = !widget.checklist.collapsed;

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => ref
                  .read(checklistControllerProvider)
                  .setCollapsed(widget.checklist, expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.checklist_outlined,
                      size: 20,
                      color: widget.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _displayTitle(l10n),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (items.isNotEmpty)
                      Text(
                        '$doneCount/${items.length}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    // One menu rather than a row of icons: with copying and
                    // moving added, four buttons plus the chevron would leave a
                    // long list title nowhere to go on a phone.
                    PopupMenuButton<_ChecklistAction>(
                      tooltip: l10n.checklistActions,
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (action) => _onAction(action, items.length),
                      itemBuilder: (context) => [
                        _menuItem(
                          _ChecklistAction.rename,
                          Icons.edit_outlined,
                          l10n.checklistRenameTitle,
                        ),
                        _menuItem(
                          _ChecklistAction.duplicate,
                          Icons.control_point_duplicate,
                          l10n.checklistDuplicate,
                        ),
                        _menuItem(
                          _ChecklistAction.copyToTrip,
                          Icons.content_copy,
                          l10n.checklistCopyToTrip,
                        ),
                        _menuItem(
                          _ChecklistAction.moveToTrip,
                          Icons.drive_file_move_outline,
                          l10n.checklistMoveToTrip,
                        ),
                        _menuItem(
                          _ChecklistAction.delete,
                          Icons.delete_outline,
                          l10n.checklistDelete,
                        ),
                      ],
                    ),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: _buildBody(context, items, l10n),
              secondChild: const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<ChecklistItem> items,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: items.length,
            // newIndex is already adjusted for the removal at oldIndex.
            onReorderItem: (oldIndex, newIndex) => ref
                .read(checklistControllerProvider)
                .reorderItems(items, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final item = items[index];
              return _ChecklistTile(
                key: ValueKey(item.id),
                index: index,
                item: item,
                onToggle: (v) => ref
                    .read(checklistControllerProvider)
                    .setDone(item, v ?? false),
                onEdit: () => _editItem(item),
                onDelete: () =>
                    ref.read(checklistControllerProvider).deleteItem(item.id),
              );
            },
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.checklistAddHint,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              IconButton(
                tooltip: l10n.add,
                icon: const Icon(Icons.add),
                onPressed: _add,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    super.key,
    required this.index,
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final int index;
  final ChecklistItem item;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        ReorderableDragStartListener(
          index: index,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.drag_indicator,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Checkbox(value: item.done, onChanged: onToggle),
        Expanded(
          child: InkWell(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                item.label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  decoration: item.done ? TextDecoration.lineThrough : null,
                  color: item.done ? theme.colorScheme.onSurfaceVariant : null,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
          icon: const Icon(Icons.close, size: 20),
          onPressed: onDelete,
        ),
      ],
    );
  }
}
