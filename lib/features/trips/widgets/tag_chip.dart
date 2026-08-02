import 'package:flutter/material.dart';

import '../../../data/database/app_database.dart';

/// One tag, drawn in its own colour.
///
/// Small and quiet: a tag says how a trip is filed, which is a caption on the
/// card rather than the card's subject. The colour carries the recognition, so
/// a row of them is scanned rather than read.
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.tag, this.selected, this.onTap});

  final Tag tag;

  /// Whether this chip is currently filtering. Null draws a plain label with no
  /// selection state at all — what a trip card shows.
  final bool? selected;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = Color(tag.colorValue);
    final on = selected ?? false;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: on ? colour : colour.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colour.withValues(alpha: on ? 1 : 0.45)),
      ),
      child: Text(
        tag.name,
        style: theme.textTheme.labelSmall?.copyWith(
          // On the filled state the label sits on the tag's own colour, which
          // the user picked and may be anything, so it takes the contrast-safe
          // white rather than a theme colour that could vanish into it.
          color: on ? Colors.white : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: chip,
    );
  }
}
