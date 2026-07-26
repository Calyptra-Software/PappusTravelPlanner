import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/transit_filter.dart';

/// Asks which kinds of transport the connection search may use, and returns the
/// chosen categories — or null if the user backed out.
///
/// A sheet rather than a row of chips in the search form: seven categories
/// would wrap into three lines above the results, and this is a setting someone
/// touches once and then travels with, not a control they reach for every
/// search.
Future<Set<TransitFilter>?> showTransitFilterSheet(
  BuildContext context, {
  required Set<TransitFilter> initial,
}) {
  return showModalBottomSheet<Set<TransitFilter>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TransitFilterSheet(initial: initial),
  );
}

/// What the current selection reads as on the button that opens the sheet: the
/// unrestricted case says so in one word, and any restriction names exactly
/// what is left in — a count ("4 of 7") would make the user open the sheet to
/// find out what it excluded.
String transitFilterSummary(AppLocalizations l10n, Set<TransitFilter> filters) {
  if (filters.length >= kAllTransitFilters.length) {
    return l10n.connectionModesAll;
  }
  if (filters.isEmpty) return l10n.connectionModesNone;
  return [
    for (final filter in TransitFilter.values)
      if (filters.contains(filter)) transitFilterLabel(l10n, filter),
  ].join(' · ');
}

String transitFilterLabel(AppLocalizations l10n, TransitFilter filter) =>
    switch (filter) {
      TransitFilter.longDistanceRail => l10n.connectionModeLongDistance,
      TransitFilter.regionalRail => l10n.connectionModeRegional,
      TransitFilter.cityTransit => l10n.connectionModeCity,
      TransitFilter.bus => l10n.connectionModeBus,
      TransitFilter.ferry => l10n.connectionModeFerry,
      TransitFilter.air => l10n.connectionModeAir,
      TransitFilter.other => l10n.connectionModeOther,
    };

IconData transitFilterIcon(TransitFilter filter) => switch (filter) {
  TransitFilter.longDistanceRail => Icons.train,
  TransitFilter.regionalRail => Icons.directions_railway,
  TransitFilter.cityTransit => Icons.subway,
  TransitFilter.bus => Icons.directions_bus,
  TransitFilter.ferry => Icons.directions_boat,
  TransitFilter.air => Icons.flight,
  TransitFilter.other => Icons.terrain,
};

class _TransitFilterSheet extends StatefulWidget {
  const _TransitFilterSheet({required this.initial});

  final Set<TransitFilter> initial;

  @override
  State<_TransitFilterSheet> createState() => _TransitFilterSheetState();
}

class _TransitFilterSheetState extends State<_TransitFilterSheet> {
  late final Set<TransitFilter> _draft = {...widget.initial};

  void _toggle(TransitFilter filter, bool on) {
    setState(() => on ? _draft.add(filter) : _draft.remove(filter));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.connectionModesTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.connectionModesSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final filter in TransitFilter.values)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(transitFilterIcon(filter)),
                  title: Text(transitFilterLabel(l10n, filter)),
                  value: _draft.contains(filter),
                  onChanged: (on) => _toggle(filter, on ?? false),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _draft.length >= kAllTransitFilters.length
                        ? null
                        : () => setState(
                            () => _draft
                              ..clear()
                              ..addAll(kAllTransitFilters),
                          ),
                    child: Text(l10n.connectionModesAll),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    // Nothing ticked can only ever find nothing.
                    onPressed: _draft.isEmpty
                        ? null
                        : () => Navigator.of(context).pop({..._draft}),
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
