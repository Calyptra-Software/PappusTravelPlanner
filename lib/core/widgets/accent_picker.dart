import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'color_picker_dialog.dart';

/// Picks an accent colour: the app's presets, plus one swatch that opens the
/// full picker for anything else.
///
/// Shared by everything the user gives a colour — a trip and a tag alike —
/// because it is the same choice. A tag confined to a fixed palette while a
/// trip could be any colour would be an arbitrary difference between two things
/// that sit on the same card.
class AccentPicker extends StatelessWidget {
  const AccentPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPreset = AppTheme.tripAccents.any(
      (color) => color.toARGB32() == selected,
    );
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final color in AppTheme.tripAccents)
          _AccentDot(
            color: color,
            selected: color.toARGB32() == selected,
            onTap: () => onSelected(color.toARGB32()),
          ),
        // Custom-colour swatch: shows the current custom colour when the
        // selection is not one of the presets, otherwise a neutral "add" dot.
        _AccentDot(
          color: isPreset ? null : Color(selected),
          selected: !isPreset,
          icon: isPreset ? Icons.add : Icons.check,
          tooltip: l10n.customColour,
          onTap: () async {
            final picked = await showColorPickerDialog(
              context,
              initial: Color(selected),
            );
            if (picked != null) onSelected(picked.toARGB32());
          },
        ),
      ],
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
    this.tooltip,
  });

  /// The swatch colour, or `null` to render a neutral outlined "add" dot.
  final Color? color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = color;
    // Contrasting icon colour so the check mark stays legible on any swatch.
    final iconColor = fill == null
        ? scheme.onSurfaceVariant
        : (fill.computeLuminance() > 0.5 ? Colors.black : Colors.white);
    final showIcon = icon ?? (selected ? Icons.check : null);
    Widget dot = InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: fill ?? scheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? scheme.onSurface
                : (fill == null ? scheme.outline : Colors.transparent),
            width: 3,
          ),
        ),
        child: showIcon != null
            ? Icon(showIcon, color: iconColor, size: 20)
            : null,
      ),
    );
    if (tooltip != null) {
      dot = Tooltip(message: tooltip!, child: dot);
    }
    return dot;
  }
}
