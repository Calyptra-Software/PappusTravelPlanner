import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/journey_options.dart';
import '../domain/transit_filter.dart';

/// Asks how the connection search should be run — which transport, how long a
/// change needs to be, how fast the traveller walks, how many interchanges —
/// and returns the chosen options, or null if the user backed out.
///
/// A sheet rather than controls in the search form: four settings would push
/// the results off the screen, and these are things someone sets once and then
/// travels with. A sheet rather than app settings, though, because their effect
/// is only legible beside the results they change — the moment anyone wants a
/// longer change is the moment they are looking at a three-minute one.
Future<JourneySearchOptions?> showSearchOptionsSheet(
  BuildContext context, {
  required JourneySearchOptions initial,
}) {
  return showModalBottomSheet<JourneySearchOptions>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SearchOptionsSheet(initial: initial),
  );
}

/// What the current options read as on the row that opens the sheet.
///
/// Only what *deviates* from the defaults is named, so an untouched search says
/// one short thing and a narrowed one states its own terms — a filter someone
/// forgot they set is how a missing connection turns into a puzzle.
String searchOptionsSummary(
  AppLocalizations l10n,
  JourneySearchOptions options,
) => [
  transitFilterSummary(l10n, options.modes),
  if (options.minTransferMinutes > 0)
    l10n.connectionSummaryMinTransfer(options.minTransferMinutes),
  if (options.walkingSpeedKmh != kNormalWalkingSpeedKmh)
    l10n.connectionSpeedValue(formatWalkingSpeed(options.walkingSpeedKmh)),
  if (options.byBike)
    options.bikeOnBoard ? l10n.connectionBikeOnBoard : l10n.connectionByBike,
  if (options.maxTransfers != null)
    l10n.connectionSummaryMaxChanges(options.maxTransfers!),
  // A small budget is one of the few settings that can empty the results on its
  // own, so it has to be visible without opening the sheet.
  if (options.maxPreTransitMinutes != null)
    l10n.connectionSummaryToStop(options.maxPreTransitMinutes!),
  if (options.maxPostTransitMinutes != null)
    l10n.connectionSummaryFromStop(options.maxPostTransitMinutes!),
  if (options.maxDirectMinutes != null)
    l10n.connectionSummaryOwnWay(options.maxDirectMinutes!),
].join(' · ');

/// The transport part of the summary: unrestricted says so in one word, and a
/// restriction names exactly what is left in — a count ("4 of 7") would make
/// the user open the sheet to find out what it excluded.
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

/// A walking speed as it is written for a human: one decimal, since the slider
/// moves in half-km/h steps.
String formatWalkingSpeed(double kmh) => kmh.toStringAsFixed(1);

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

class _SearchOptionsSheet extends StatefulWidget {
  const _SearchOptionsSheet({required this.initial});

  final JourneySearchOptions initial;

  @override
  State<_SearchOptionsSheet> createState() => _SearchOptionsSheetState();
}

class _SearchOptionsSheetState extends State<_SearchOptionsSheet> {
  late JourneySearchOptions _draft = widget.initial;
  late final Set<TransitFilter> _modes = {...widget.initial.modes};

  void _toggle(TransitFilter filter, bool on) {
    setState(() {
      on ? _modes.add(filter) : _modes.remove(filter);
      _draft = _draft.copyWith(modes: {..._modes});
    });
  }

  void _reset() {
    setState(() {
      _draft = const JourneySearchOptions();
      _modes
        ..clear()
        ..addAll(kAllTransitFilters);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final speed = _draft.walkingSpeedKmh;
    final speedValue = l10n.connectionSpeedValue(formatWalkingSpeed(speed));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.connectionOptionsTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.connectionModesTitle,
                style: theme.textTheme.titleSmall,
              ),
              Text(l10n.connectionModesSubtitle, style: hintStyle),
              for (final filter in TransitFilter.values)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  secondary: Icon(transitFilterIcon(filter)),
                  title: Text(transitFilterLabel(l10n, filter)),
                  value: _modes.contains(filter),
                  onChanged: (on) => _toggle(filter, on ?? false),
                ),
              const SizedBox(height: 12),
              _SliderRow(
                label: l10n.connectionMinTransfer,
                value: _draft.minTransferMinutes == 0
                    ? l10n.connectionMinTransferAny
                    : l10n.connectionMinutesShort(_draft.minTransferMinutes),
                hint: l10n.connectionMinTransferHint,
                hintStyle: hintStyle,
                slider: Slider(
                  value: _draft.minTransferMinutes.toDouble(),
                  max: kMaxMinTransferMinutes.toDouble(),
                  divisions: kMaxMinTransferMinutes,
                  label: '${_draft.minTransferMinutes}',
                  onChanged: (v) => setState(
                    () =>
                        _draft = _draft.copyWith(minTransferMinutes: v.round()),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SliderRow(
                label: l10n.connectionWalkingSpeed,
                // The default carries its name, so someone who has dragged the
                // thumb can find their way back to it.
                value: speed == kNormalWalkingSpeedKmh
                    ? '$speedValue · ${l10n.connectionSpeedNormal}'
                    : speedValue,
                hint: l10n.connectionWalkingSpeedHint,
                hintStyle: hintStyle,
                slider: Slider(
                  value: speed,
                  min: kMinWalkingSpeedKmh,
                  max: kMaxWalkingSpeedKmh,
                  divisions:
                      ((kMaxWalkingSpeedKmh - kMinWalkingSpeedKmh) /
                              kWalkingSpeedStepKmh)
                          .round(),
                  label: formatWalkingSpeed(speed),
                  onChanged: (v) => setState(
                    () => _draft = _draft.copyWith(walkingSpeedKmh: v),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                secondary: const Icon(Icons.directions_bike),
                title: Text(l10n.connectionByBike),
                subtitle: Text(l10n.connectionByBikeHint),
                value: _draft.byBike,
                onChanged: (on) =>
                    setState(() => _draft = _draft.copyWith(byBike: on)),
              ),
              if (_draft.byBike) ...[
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(left: 32),
                  visualDensity: VisualDensity.compact,
                  title: Text(l10n.connectionBikeOnBoard),
                  // Most feeds say nothing about bike carriage, and requiring
                  // it then finds nothing at all — better said here than
                  // discovered as an empty screen.
                  subtitle: Text(l10n.connectionBikeOnBoardHint),
                  value: _draft.bikeOnBoard,
                  onChanged: (on) =>
                      setState(() => _draft = _draft.copyWith(bikeOnBoard: on)),
                ),
                const SizedBox(height: 8),
                _SliderRow(
                  label: l10n.connectionCyclingSpeed,
                  value: l10n.connectionSpeedValue(
                    formatWalkingSpeed(_draft.cyclingSpeedKmh),
                  ),
                  hint: l10n.connectionCyclingSpeedHint,
                  hintStyle: hintStyle,
                  slider: Slider(
                    value: _draft.cyclingSpeedKmh,
                    min: kMinCyclingSpeedKmh,
                    max: kMaxCyclingSpeedKmh,
                    divisions:
                        ((kMaxCyclingSpeedKmh - kMinCyclingSpeedKmh) /
                                kCyclingSpeedStepKmh)
                            .round(),
                    label: formatWalkingSpeed(_draft.cyclingSpeedKmh),
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(cyclingSpeedKmh: v),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                l10n.connectionBudgetsTitle,
                style: theme.textTheme.titleSmall,
              ),
              Text(l10n.connectionBudgetsHint, style: hintStyle),
              const SizedBox(height: 4),
              _MinutesRow(
                label: l10n.connectionBudgetPre,
                value: _draft.maxPreTransitMinutes,
                options: kPrePostTransitMinuteOptions,
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(
                    maxPreTransitMinutes: v,
                    clearBudgets: v == null,
                  ),
                ),
              ),
              _MinutesRow(
                label: l10n.connectionBudgetPost,
                value: _draft.maxPostTransitMinutes,
                options: kPrePostTransitMinuteOptions,
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(
                    maxPostTransitMinutes: v,
                    clearBudgets: v == null,
                  ),
                ),
              ),
              _MinutesRow(
                label: l10n.connectionBudgetDirect,
                value: _draft.maxDirectMinutes,
                options: kDirectMinuteOptions,
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(
                    maxDirectMinutes: v,
                    clearBudgets: v == null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.connectionMaxTransfers,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: _noLimit,
                      label: Text(l10n.connectionMaxTransfersAny),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text(l10n.connectionMaxTransfersAtMost(2)),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text(l10n.connectionMaxTransfersAtMost(1)),
                    ),
                    ButtonSegment(
                      value: 0,
                      label: Text(l10n.connectionMaxTransfersDirect),
                    ),
                  ],
                  selected: {_draft.maxTransfers ?? _noLimit},
                  onSelectionChanged: (s) => setState(() {
                    final picked = s.first;
                    _draft = _draft.copyWith(
                      maxTransfers: picked == _noLimit ? null : picked,
                      clearMaxTransfers: picked == _noLimit,
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _draft.isDefault ? null : _reset,
                    child: Text(l10n.connectionOptionsReset),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    // Nothing ticked can only ever find nothing.
                    onPressed: _modes.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_draft),
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

/// Stands in for "no limit" inside the segmented button, which needs a value
/// for every segment. The options object keeps it as the null it is.
const int _noLimit = -1;

/// One time budget: a label and a menu of minutes, where the first entry is
/// "automatic" rather than a number — the setting has a sensible answer of its
/// own, and a user who has not thought about it should not have to.
class _MinutesRow extends StatelessWidget {
  const _MinutesRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final List<int?> options;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: 8),
          DropdownButton<int?>(
            value: value,
            underline: const SizedBox.shrink(),
            items: [
              for (final minutes in options)
                DropdownMenuItem(
                  value: minutes,
                  child: Text(
                    minutes == null
                        ? l10n.connectionBudgetAuto
                        : l10n.connectionMinutesShort(minutes),
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// A labelled slider: the name on the left, the value it stands at on the right
/// (a thumb position alone does not say a number), and the line that keeps it
/// from being read as the setting above it.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.slider,
    required this.hint,
    required this.hintStyle,
  });

  final String label;
  final String value;
  final Widget slider;
  final String hint;
  final TextStyle? hintStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.titleSmall),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        Text(hint, style: hintStyle),
        slider,
      ],
    );
  }
}
