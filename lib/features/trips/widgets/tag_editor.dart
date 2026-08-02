import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/accent_picker.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../application/trip_providers.dart';
import 'tag_chip.dart';

/// Which tags a trip carries: every tag in the roster as a chip, tapped on and
/// off, with a field to name a new one.
///
/// Deliberately not a picker behind a button. A tag typed once and never seen
/// again is a tag that stops being applied, and an overview kept navigable by
/// tags depends on their being applied — so the whole roster is on screen while
/// the trip is being written, and adding to it is one line of typing.
class TagEditor extends ConsumerStatefulWidget {
  const TagEditor({super.key, required this.selected, required this.onChanged});

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  ConsumerState<TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends ConsumerState<TagEditor> {
  final _controller = TextEditingController();
  var _adding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Creates the typed tag and selects it in one step: a tag being invented
  /// here is being invented *for this trip*, so making the user then tap it
  /// would be asking twice.
  Future<void> _add() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _adding) return;
    setState(() => _adding = true);
    final id = await ref.read(repositoryProvider).ensureTag(name);
    if (!mounted) return;
    _controller.clear();
    setState(() => _adding = false);
    widget.onChanged({...widget.selected, id});
  }

  void _toggle(Tag tag) {
    final next = {...widget.selected};
    next.contains(tag.id) ? next.remove(tag.id) : next.add(tag.id);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tags = ref.watch(tagListProvider).value ?? const <Tag>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.tagsLabel, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        if (tags.isEmpty)
          Text(
            l10n.tagsNone,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in tags)
                TagChip(
                  tag: tag,
                  selected: widget.selected.contains(tag.id),
                  onTap: () => _toggle(tag),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: l10n.tagsAddHint,
                  prefixIcon: const Icon(Icons.label_outline),
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: l10n.tagsAdd,
              onPressed: _adding ? null : _add,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}

/// Renames, re-colours and deletes tags — the roster itself, rather than one
/// trip's use of it. Reached from the overview's tag bar and from settings.
class TagSettingsScreen extends ConsumerWidget {
  const TagSettingsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, Tag? existing) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: existing?.name ?? '');
    var colour = existing == null
        ? AppTheme.tripAccents.first.toARGB32()
        : existing.colorValue;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? l10n.tagsAdd : l10n.tagRename),
          // The swatches wrap onto several rows in a narrow dialog, which can
          // outgrow a short window.
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: l10n.tagNameLabel),
                ),
                const SizedBox(height: 16),
                // The same picker a trip's accent uses, custom colours included:
                // the two sit side by side on a card, so a tag limited to a fixed
                // palette would be an arbitrary difference.
                AccentPicker(
                  selected: colour,
                  onSelected: (value) => setState(() => colour = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );

    final name = controller.text.trim();
    controller.dispose();
    if (saved != true || name.isEmpty) return;
    final repo = ref.read(repositoryProvider);
    if (existing == null) {
      await repo.createTag(
        TagsCompanion.insert(name: name, colorValue: Value(colour)),
      );
    } else {
      await repo.updateTag(existing.copyWith(name: name, colorValue: colour));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Tag tag) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.tagDeleteQuestion),
        content: Text(l10n.tagDeleteBody),
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
    if (confirmed == true) await ref.read(repositoryProvider).deleteTag(tag.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tags = ref.watch(tagListProvider).value ?? const <Tag>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tagsManage)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add),
        label: Text(l10n.tagsAdd),
      ),
      body: tags.isEmpty
          ? Center(child: Text(l10n.tagsNone))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: tags.length,
              itemBuilder: (context, index) {
                final tag = tags[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: Color(tag.colorValue),
                  ),
                  title: Text(tag.name),
                  onTap: () => _edit(context, ref, tag),
                  trailing: IconButton(
                    tooltip: l10n.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, ref, tag),
                  ),
                );
              },
            ),
    );
  }
}
