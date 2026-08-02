import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../application/trip_providers.dart';
import 'tag_chip.dart';

/// The tag roster as a scrollable row of filter chips above the overview.
///
/// This is what keeps the list navigable once a commute is recorded twice a
/// day, and it is in the open rather than inside the filter sheet for exactly
/// that reason: a filter two taps deep is one that stops being used, and then
/// the filing that fed it stops too.
///
/// Tags match **any-of** — tapping "walks" and "bike rides" shows both — so the
/// chips read as widening the view rather than narrowing it to nothing, which
/// is what an all-of row of two would usually do.
class TagFilterBar extends ConsumerWidget {
  const TagFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.onManage,
  });

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tags = ref.watch(tagListProvider).value ?? const <Tag>[];
    // Nothing to file under yet: an empty bar would be a permanent strip of
    // blank above every list, teaching nothing.
    if (tags.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // "All" is the way back out, and it is a chip rather than a cleared
          // selection so that turning the filter off is as visible as turning
          // it on.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _AllChip(
              selected: selected.isEmpty,
              label: l10n.tagsAll,
              onTap: () => onChanged(const {}),
            ),
          ),
          for (final tag in tags)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TagChip(
                tag: tag,
                selected: selected.contains(tag.id),
                onTap: () {
                  final next = {...selected};
                  next.contains(tag.id)
                      ? next.remove(tag.id)
                      : next.add(tag.id);
                  onChanged(next);
                },
              ),
            ),
          IconButton(
            tooltip: l10n.tagsManage,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.tune, size: 18),
            onPressed: onManage,
          ),
        ],
      ),
    );
  }
}

class _AllChip extends StatelessWidget {
  const _AllChip({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? scheme.secondaryContainer : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: selected
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
