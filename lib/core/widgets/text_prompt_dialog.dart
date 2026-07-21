import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Shows a dialog with a single text field — the app's one "name this thing"
/// prompt, shared by every add/rename across the features.
///
/// Resolves to the trimmed text, or null if the dialog was dismissed. An empty
/// string is distinct from null and means the field was cleared, which is how a
/// caller resets an optional label back to its default.
///
/// [confirmLabel] defaults to "Add" when there is no [initial] text and "Save"
/// when there is; pass it explicitly to override that.
///
/// The controller lives inside [_TextPromptDialog] rather than beside this
/// call on purpose: `showDialog`'s future completes the moment the dialog is
/// popped, but the dialog stays mounted through its exit animation. Creating a
/// controller here and disposing it once the future returned would leave the
/// still-live `TextField` reading a disposed controller — which throws, and
/// drags a rebuild into a build scope the dialog no longer belongs to.
Future<String?> showTextPromptDialog(
  BuildContext context, {
  required String title,
  String? label,
  String? hint,
  String? initial,
  String? confirmLabel,
  TextCapitalization textCapitalization = TextCapitalization.sentences,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextPromptDialog(
      title: title,
      label: label,
      hint: hint,
      initial: initial,
      confirmLabel: confirmLabel,
      textCapitalization: textCapitalization,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    this.label,
    this.hint,
    this.initial,
    this.confirmLabel,
    required this.textCapitalization,
  });

  final String title;
  final String? label;
  final String? hint;
  final String? initial;
  final String? confirmLabel;
  final TextCapitalization textCapitalization;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: widget.textCapitalization,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            widget.confirmLabel ??
                (widget.initial == null ? l10n.add : l10n.save),
          ),
        ),
      ],
    );
  }
}
