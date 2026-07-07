import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../application/cost_providers.dart';

/// Sentinel dropdown value meaning "type a new person".
const String _kNewPerson = ' new_person_picker';

/// Shows a dialog to pick a person from the shared roster — a dropdown of
/// everyone not already in [currentNames], plus a "New person…" option that
/// reveals a text field. Watches the roster live so the dropdown fills in as
/// soon as it loads. Resolves to the chosen name, or null if dismissed.
Future<String?> showPersonPicker(
  BuildContext context, {
  required Set<String> currentNames,
  required String title,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _PersonPickerDialog(currentNames: currentNames, title: title),
  );
}

class _PersonPickerDialog extends ConsumerStatefulWidget {
  const _PersonPickerDialog({required this.currentNames, required this.title});

  /// Names already chosen, excluded from the dropdown.
  final Set<String> currentNames;
  final String title;

  @override
  ConsumerState<_PersonPickerDialog> createState() =>
      _PersonPickerDialogState();
}

class _PersonPickerDialogState extends ConsumerState<_PersonPickerDialog> {
  final _controller = TextEditingController();

  String? _selected;
  bool _creatingNew = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The chosen name — typed or picked — or null if nothing usable is entered.
  String? _result({required bool typing}) {
    final raw = typing ? _controller.text : (_selected ?? '');
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final roster = ref.watch(peopleProvider).value ?? const <String>[];
    final suggestions =
        roster.where((name) => !widget.currentNames.contains(name)).toList();
    // Fall back to the text field when there's no one left to pick.
    final showTextField = _creatingNew || suggestions.isEmpty;

    return AlertDialog(
      title: Text(widget.title),
      // A dropdown of roster people, or — when adding a new one — a single text
      // field with an X to return to the dropdown. Never both at once.
      content: showTextField
          ? TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.personLabel,
                hintText: l10n.personHint,
                suffixIcon: suggestions.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.cancel,
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _creatingNew = false;
                          _controller.clear();
                        }),
                      ),
              ),
              onSubmitted: (_) => Navigator.pop(context, _result(typing: true)),
            )
          : DropdownButtonFormField<String>(
              initialValue: _selected,
              decoration: InputDecoration(labelText: l10n.personLabel),
              items: [
                for (final name in suggestions)
                  DropdownMenuItem(value: name, child: Text(name)),
                DropdownMenuItem(
                  value: _kNewPerson,
                  child: Text(l10n.costPaidByNew),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  if (value == _kNewPerson) {
                    _creatingNew = true;
                    _selected = null;
                  } else {
                    _selected = value;
                  }
                });
              },
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, _result(typing: showTextField)),
          child: Text(l10n.add),
        ),
      ],
    );
  }
}
