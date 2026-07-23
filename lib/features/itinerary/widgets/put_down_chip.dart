import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../application/item_clipboard.dart';

/// The offer to put the held entry down *here* — appended to the add-row of a
/// day and of every option, so the destination is simply the place you have
/// navigated to and can see.
///
/// Shown only while something is held, which is what keeps this out of the way
/// of everyone not moving anything: the row it joins is otherwise unchanged.
class PutDownChip extends StatelessWidget {
  const PutDownChip({super.key, required this.mode, required this.onPressed});

  final HoldMode mode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ActionChip(
      avatar: Icon(
        mode == HoldMode.move ? Icons.south_east : Icons.content_copy,
        size: 16,
      ),
      label: Text(mode == HoldMode.move ? l10n.moveHere : l10n.copyHere),
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}
