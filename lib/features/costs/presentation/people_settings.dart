import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../application/cost_providers.dart';

/// Settings block to manage the reusable list of people who can pay for
/// expenses: add, rename, or remove each person. Mirrors [CostReasonsSettings].
class PeopleSettings extends ConsumerWidget {
  const PeopleSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final people = ref.watch(peopleProvider).value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (people.isEmpty)
          ListTile(
            title: Text(
              l10n.noPeople,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          for (final name in people)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(name),
              onTap: () => _renamePerson(context, ref, name),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                color: theme.colorScheme.error,
                tooltip: l10n.delete,
                onPressed: () => _confirmDelete(context, ref, name),
              ),
            ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.personAdd),
              onPressed: () => _addPerson(context, ref),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addPerson(BuildContext context, WidgetRef ref) async {
    final name = await _promptName(context, title: (l10n) => l10n.personAddTitle);
    if (name == null || name.isEmpty) return;
    await ref.read(costControllerProvider).addPerson(name);
  }

  Future<void> _renamePerson(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final name = await _promptName(
      context,
      title: (l10n) => l10n.personRenameTitle,
      initial: current,
    );
    if (name == null || name.isEmpty || name == current) return;
    await ref.read(costControllerProvider).renamePerson(current, name);
  }

  /// Shows a single-field name dialog, returning the trimmed text or null.
  Future<String?> _promptName(
    BuildContext context, {
    required String Function(AppLocalizations) title,
    String? initial,
  }) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: initial);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title(l10n)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.personLabel,
            hintText: l10n.personHint,
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(initial == null ? l10n.add : l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    return name;
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.personDeleteConfirmTitle),
        content: Text(l10n.personDeleteConfirmBody(name)),
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
    await ref.read(costControllerProvider).deletePerson(name);
  }
}
