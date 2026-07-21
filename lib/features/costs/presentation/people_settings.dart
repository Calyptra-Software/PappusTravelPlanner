import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/text_prompt_dialog.dart';
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
    final people = ref.watch(peopleRowsProvider).value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (people.isEmpty)
          ListTile(
            title: Text(
              l10n.noPeople,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final person in people)
            ListTile(
              leading: Icon(
                person.isMe ? Icons.person : Icons.person_outline,
                color: person.isMe ? theme.colorScheme.primary : null,
              ),
              title: Text(person.name),
              subtitle: person.isMe ? Text(l10n.personIsMe) : null,
              onTap: () => _renamePerson(context, ref, person.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      person.isMe
                          ? Icons.how_to_reg
                          : Icons.person_add_alt_outlined,
                    ),
                    color: person.isMe ? theme.colorScheme.primary : null,
                    tooltip: person.isMe
                        ? l10n.personIsMe
                        : l10n.personMarkAsMe,
                    onPressed: () => ref
                        .read(costControllerProvider)
                        .setMePerson(person.isMe ? null : person.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: theme.colorScheme.error,
                    tooltip: l10n.delete,
                    onPressed: () => _confirmDelete(context, ref, person.name),
                  ),
                ],
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
    final name = await _promptName(
      context,
      title: (l10n) => l10n.personAddTitle,
    );
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
  }) {
    final l10n = AppLocalizations.of(context);
    return showTextPromptDialog(
      context,
      title: title(l10n),
      label: l10n.personLabel,
      hint: l10n.personHint,
      initial: initial,
      textCapitalization: TextCapitalization.words,
    );
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
