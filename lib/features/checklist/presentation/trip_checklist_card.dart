import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/application/trip_providers.dart';
import '../application/checklist_providers.dart';

/// A per-trip checklist shown in the trip detail header: tickable, reorderable
/// items with free text, a customisable heading, an inline field to add more,
/// and a collapsible body.
class TripChecklistCard extends ConsumerStatefulWidget {
  const TripChecklistCard({
    super.key,
    required this.tripId,
    required this.accent,
  });

  final int tripId;
  final Color accent;

  @override
  ConsumerState<TripChecklistCard> createState() => _TripChecklistCardState();
}

class _TripChecklistCardState extends ConsumerState<TripChecklistCard> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _expanded = true;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final label = _controller.text.trim();
    if (label.isEmpty) return;
    await ref.read(checklistControllerProvider).add(widget.tripId, label);
    _controller.clear();
    // Keep the field focused so several items can be added in a row.
    _focusNode.requestFocus();
  }

  Future<void> _edit(ChecklistItem item) async {
    final l10n = AppLocalizations.of(context);
    final result = await _promptText(
      title: l10n.checklistEditTitle,
      initial: item.label,
    );
    if (result == null) return;
    final trimmed = result.trim();
    if (trimmed.isEmpty || trimmed == item.label) return;
    await ref.read(checklistControllerProvider).rename(item, trimmed);
  }

  Future<void> _renameList(String currentTitle) async {
    final l10n = AppLocalizations.of(context);
    final result = await _promptText(
      title: l10n.checklistRenameTitle,
      initial: currentTitle,
      hint: l10n.checklist,
    );
    if (result == null) return;
    await ref
        .read(checklistControllerProvider)
        .setTitle(widget.tripId, result);
  }

  /// Shows a single-field text dialog, returning the entered value or null if
  /// dismissed.
  Future<String?> _promptText({
    required String title,
    required String initial,
    String? hint,
  }) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: hint == null ? null : InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(checklistProvider(widget.tripId)).value ?? const [];
    final customTitle =
        ref.watch(tripProvider(widget.tripId)).value?.checklistTitle;
    final title = (customTitle != null && customTitle.isNotEmpty)
        ? customTitle
        : l10n.checklist;
    final doneCount = items.where((i) => i.done).length;

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Row(
                  children: [
                    Icon(Icons.checklist_outlined,
                        size: 20, color: widget.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleMedium),
                    ),
                    if (items.isNotEmpty)
                      Text(
                        '$doneCount/${items.length}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    IconButton(
                      tooltip: l10n.checklistRenameTitle,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _renameList(customTitle ?? ''),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: _expanded
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
                .reorder(items, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final item = items[index];
              return _ChecklistTile(
                key: ValueKey(item.id),
                index: index,
                item: item,
                onToggle: (v) => ref
                    .read(checklistControllerProvider)
                    .setDone(item, v ?? false),
                onEdit: () => _edit(item),
                onDelete: () =>
                    ref.read(checklistControllerProvider).delete(item.id),
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
