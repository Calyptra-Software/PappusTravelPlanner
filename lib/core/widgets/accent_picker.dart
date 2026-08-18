import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'color_picker_dialog.dart';

/// Picks an accent colour: the app's presets, plus one swatch that opens the
/// full picker for anything else.
///
/// Shared by everything the user gives a color — a trip, a tag, and an entry on
/// the map alike — because it is the same choice. A tag confined to a fixed
/// palette while a trip could be any color would be an arbitrary difference
/// between two things that sit on the same card.
///
/// Some things have a color *by default* rather than of their own: an itinerary
/// entry is drawn in its trip's accent until somebody says otherwise. Passing
/// [onInherit] adds a leading swatch for exactly that state, so "back to the
/// trip's color" is a choice in the same row as the others rather than a clear
/// button somewhere else — and [selected] may then be null, which is what that
/// state *is*.
class AccentPicker extends StatelessWidget {
  const AccentPicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.inherited,
    this.onInherit,
    this.inheritTooltip,
  });

  /// The chosen color, or null when nothing has been chosen — only meaningful
  /// alongside [onInherit], which is what makes "nothing" a state one can pick.
  final int? selected;
  final ValueChanged<int> onSelected;

  /// What the inherited color actually looks like, so the swatch shows the
  /// color it would fall back to rather than a blank.
  final Color? inherited;

  /// Chooses "no color of my own". Omitted by the callers that have no such
  /// state — a trip and a tag always carry one — and their swatch row is then
  /// exactly what it was.
  final VoidCallback? onInherit;
  final String? inheritTooltip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPreset = AppTheme.tripAccents.any(
      (color) => color.toARGB32() == selected,
    );
    // The chosen color when it is one the presets do not already offer — what
    // the custom swatch stands for. Null both when a preset is chosen and when
    // nothing is.
    final custom = selected == null || isPreset ? null : Color(selected!);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (onInherit != null)
          _AccentDot(
            color: inherited,
            selected: selected == null,
            // Outlined even when it is not the selection, because it is not one
            // color among the presets: it says "whatever the trip is", and the
            // ring is what distinguishes it from a preset that happens to match.
            outlined: true,
            tooltip: inheritTooltip,
            onTap: onInherit!,
          ),
        for (final color in AppTheme.tripAccents)
          _AccentDot(
            color: color,
            selected: color.toARGB32() == selected,
            onTap: () => onSelected(color.toARGB32()),
          ),
        // Custom-color swatch: shows the current custom color when one is
        // chosen and is not a preset, otherwise a neutral "add" dot. Nothing
        // chosen at all counts as "not custom" — the inherited swatch above
        // already carries that selection.
        _AccentDot(
          color: custom,
          selected: custom != null,
          icon: custom == null ? Icons.add : Icons.check,
          tooltip: l10n.customColour,
          onTap: () async {
            final picked = await showColorPickerDialog(
              context,
              // Opens on whatever is on screen: the chosen color, or the one
              // being inherited, so the wheel starts where the eye is.
              initial: custom ?? inherited ?? AppTheme.tripAccents.first,
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
    this.outlined = false,
  });

  /// The swatch colour, or `null` to render a neutral outlined "add" dot.
  final Color? color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? tooltip;

  /// Keeps a ring around the dot even when it is not the selection — for a
  /// swatch that stands for something other than "this color".
  final bool outlined;

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
                : (fill == null || outlined
                      ? scheme.outline
                      : Colors.transparent),
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
