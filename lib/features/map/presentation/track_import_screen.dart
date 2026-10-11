import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/format/date_format.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../l10n/app_localizations.dart';
import '../basemap.dart';
import '../finite_camera.dart';
import '../track_import_plan.dart';
import '../track_split.dart';
import '../track_times.dart';
import '../widgets/map_overlays.dart';

/// Colours for the stretches, chosen here rather than taken from the theme.
///
/// The theme's primary, secondary and tertiary are three shades of one hue in
/// this app, which is right for a coherent screen and wrong for the one job
/// this screen has: saying which stretch is which. These are far apart in hue
/// and dark enough to hold their own on pale raster tiles, which are themselves
/// full of thin red and orange lines — so no red, and nothing pastel.
const List<Color> kTrackPieceColors = [
  Color(0xFF1565C0), // blue
  Color(0xFFEF6C00), // orange
  Color(0xFF6A1B9A), // purple
  Color(0xFF2E7D32), // green
  Color(0xFFC2185B), // magenta
  Color(0xFF00838F), // teal
];

/// What the part of the line nobody has divided yet is drawn in: present, but
/// visibly not yet anybody's.
const Color kTrackUndividedColor = Color(0xFF9E9E9E);

/// Spreads one recording over the entries it covered, with the division on
/// screen before anything is written.
///
/// A full-screen route rather than a sheet, for the reason the map picker is
/// one: a sheet answers a vertical drag by closing, and that is the same gesture
/// as panning the map under it.
///
/// The screen exists because of what it refuses to do. The line has to be cut
/// where one entry handed over to the next, and for entries that were never
/// given coordinates nobody knows where that is. So it asks — every handover,
/// no exceptions — and because the division is drawn while it is being decided,
/// the answer is visible before it is a fact. There is deliberately no way to
/// skip: an estimated cut is invisible, and an invisible guess is the kind that
/// turns into a wrong answer months later. It also means nothing downstream
/// needs a rule for dividing a line nobody has said anything about.
///
/// There is one rule: **a tap puts the selected handover where it landed.**
/// Which one is selected is on screen — a numbered chip under the map, and the
/// matching mark on it drawn larger — and a tap on a chip selects another. After
/// a handover is placed the selection moves on to the next one still open, so
/// the first pass is one tap per handover; once none is open it stays where it
/// is, so tapping again refines the one just placed. Re-placing an earlier one
/// before the rest are done is a tap on its chip, where it used to be
/// impossible: open ones always took the tap, and only a finished division let
/// the nearest one move — a second rule, and one that could pick the neighbour
/// of the handover you meant.
///
/// The selection is chosen in the panel and never on the map. An earlier
/// version made the marker itself tappable to "pick up" first — an invisible
/// state, and one that competed with the map for the same tap, so often neither
/// happened. The marks are inert on purpose, and the tap is the map's own
/// `onTap`: flutter_map's gesture handling wraps its children, so a
/// `GestureDetector` placed among them never wins the arena and no tap arrives
/// at all. Both of those were tried; neither is worth trying again.
///
/// Where the recording carries times ([times], parallel to [lines]) and
/// [readTimes] allows it, the panel says two more things: that the recording
/// was made on **other days** than the entries, if it was, and which **actual
/// times** it can write — a list behind one row, with the zone the UTC of the
/// file is read in beside it (`track_times.dart`). Times only fill what is
/// empty unless a row is ticked by hand, and are offered only once every
/// handover is placed, since a leg's times are read at its cuts.
Future<bool?> importTrackAcrossEntries(
  BuildContext context, {
  required List<List<LatLng>> lines,
  List<List<DateTime>?> times = const [],
  required String? name,
  required List<ItineraryItem> selection,
  bool readTimes = true,
}) => Navigator.of(context).push<bool>(
  MaterialPageRoute(
    builder: (_) => TrackImportScreen(
      lines: lines,
      times: times,
      name: name,
      selection: selection,
      readTimes: readTimes,
    ),
  ),
);

class TrackImportScreen extends ConsumerStatefulWidget {
  const TrackImportScreen({
    super.key,
    required this.lines,
    this.times = const [],
    required this.name,
    required this.selection,
    this.readTimes = true,
  });

  /// The recording, one list per `<trkseg>` — a pause is a hole that survives.
  final List<List<LatLng>> lines;

  /// When each point of [lines] was recorded, line by line, or null for a line
  /// without times (`GpxTrack.times`). Shorter than [lines], or empty, where
  /// nothing is known.
  final List<List<DateTime>?> times;

  /// Whether the times may be read at all — false for a routine, whose
  /// entries stand on no real day.
  final bool readTimes;
  final String? name;

  /// The contiguous run of entries the recording covers, in the order the day
  /// reads them.
  final List<ItineraryItem> selection;

  @override
  ConsumerState<TrackImportScreen> createState() => _TrackImportScreenState();
}

class _TrackImportScreenState extends ConsumerState<TrackImportScreen> {
  final MapController _controller = MapController();
  late TrackImportPlan _plan;

  /// What each handover is written as, onto entries that had no coordinate
  /// there: the entry's own position while untouched, the tapped point once
  /// moved.
  late List<LatLng?> _boundaries;

  /// Where each handover divides the line, as an index into [_flat] — the
  /// state the bounds, the preview and the written division all read.
  ///
  /// Kept beside [_boundaries] rather than derived from it, because a
  /// coordinate does not say where on the line it is: one taken from an entry
  /// lies beside the recording, and a walk that returns to its station puts
  /// the same spot at two places on it. Resolved once, so moving one handover
  /// never moves another.
  late List<int?> _cuts;

  /// The handover the next tap places, or null when there is none to place.
  int? _selected;

  /// Every point of the recording in one sequence — what a tap is snapped
  /// against, and the same order the cutting walks.
  late List<LatLng> _flat;

  /// When each point of [_flat] was recorded, null where its line has no
  /// times. Empty when the recording has none, or they are not to be read.
  late List<DateTime?> _flatTimes;

  /// The zone the recording's UTC is read in — see `track_times.dart`.
  Duration _offset = Duration.zero;

  /// Ticks the user changed on the actual-times sheet, by leg and end. A row
  /// not in here is at its default (`ActualTimeProposal.selectedByDefault`).
  Map<(int, TrackEnd), bool> _timeChoices = const {};

  @override
  void initState() {
    super.initState();
    _plan = trackImportPlan(widget.selection);
    _boundaries = [..._plan.boundaries];
    _flat = [for (final line in widget.lines) ...line];
    _cuts = trackCutIndices(_flat, _boundaries);
    _selected = _open ?? (_boundaries.isEmpty ? null : 0);
    _flatTimes = [
      for (var i = 0; i < widget.lines.length; i++)
        for (var j = 0; j < widget.lines[i].length; j++)
          (i < widget.times.length ? widget.times[i] : null)?[j],
    ];
    if (!widget.readTimes || _flatTimes.every((t) => t == null)) {
      _flatTimes = const [];
    }
    final firstTime = _flatTimes.nonNulls.firstOrNull;
    if (firstTime != null) _offset = defaultRecordingOffset(firstTime);
  }

  /// The actual times the recording can supply at the current division, or
  /// none while a handover is still open — a leg's times are read at its cuts.
  List<ActualTimeProposal> _proposalsAt(Duration offset) {
    if (_flatTimes.isEmpty || !_complete || _plan.legs.isEmpty) {
      return const [];
    }
    return actualTimeProposals(
      _plan.legs,
      legInstants(_flat, _flatTimes, [for (final cut in _cuts) cut!]),
      offset,
      selection: widget.selection,
    );
  }

  bool _isChosen(ActualTimeProposal p, Map<(int, TrackEnd), bool> choices) =>
      choices[(p.item.id, p.end)] ?? p.selectedByDefault;

  /// The warning, when the recording shares no day with the entries.
  String? _otherDayWarning(AppLocalizations l10n) {
    final recorded = recordingDays(
      _flatTimes.nonNulls.firstOrNull,
      _flatTimes.nonNulls.lastOrNull,
      _offset,
    );
    if (recorded == null || !recordingOnOtherDays(recorded, widget.selection)) {
      return null;
    }
    final locale = l10n.localeName;
    DateTime earlier(DateTime a, DateTime b) => daysBetween(a, b) < 0 ? b : a;
    DateTime later(DateTime a, DateTime b) => daysBetween(a, b) > 0 ? b : a;
    final plannedFrom = widget.selection.map((e) => e.date).reduce(earlier);
    final plannedTo = widget.selection
        .map((e) => addDays(e.date, e.endDayOffset))
        .reduce(later);
    return l10n.trackRecordedOtherDay(
      _days(l10n, locale, recorded.from, recorded.to),
      _days(l10n, locale, plannedFrom, plannedTo),
    );
  }

  String _days(
    AppLocalizations l10n,
    String locale,
    DateTime from,
    DateTime to,
  ) => daysBetween(from, to) == 0
      ? formatFullDate(from, locale)
      : formatDateRange(l10n, locale, from, to);

  /// When the recording ran, read at [offset]: "09:12 – 11:47", with the
  /// day mark the timeline uses when it ran past midnight.
  String _span(Duration offset) {
    final first = wallClock(_flatTimes.nonNulls.first, offset);
    final last = wallClock(_flatTimes.nonNulls.last, offset);
    return formatTimeRange(
      first.hour * 60 + first.minute,
      last.hour * 60 + last.minute,
      endDayOffset: daysBetween(first, last),
    );
  }

  Future<void> _showTimes(AppLocalizations l10n) => showAppSheet<void>(
    context,
    builder: (_) => _ActualTimesSheet(
      offset: _offset,
      choices: _timeChoices,
      proposalsAt: _proposalsAt,
      isChosen: _isChosen,
      span: _span,
      label: (item) => _label(item, l10n),
      onChanged: (offset, choices) => setState(() {
        _offset = offset;
        _timeChoices = choices;
      }),
    ),
  );

  /// The first handover nobody has said anything about, or null once they are
  /// all placed.
  int? get _open {
    for (var i = 0; i < _boundaries.length; i++) {
      if (_boundaries[i] == null) return i;
    }
    return null;
  }

  /// The handovers placed so far, as a prefix — everything up to the first one
  /// still open. That prefix is what can be drawn as divided; the rest of the
  /// line belongs to nobody yet.
  List<int> get _placedPrefix {
    final out = <int>[];
    for (final cut in _cuts) {
      if (cut == null) break;
      out.add(cut);
    }
    return out;
  }

  bool get _complete => _cuts.every((c) => c != null);

  /// A tap puts the selected handover where it landed. That is the whole
  /// interaction.
  ///
  /// There is deliberately no picking-up step on the map: a mode you cannot see
  /// is a mode you cannot use, and the selection is drawn in the panel and on
  /// the mark. Nothing here is written until *Import* anyway — so a tap in the
  /// wrong place costs another tap and is visible the moment it happens,
  /// because the division is redrawn under it.
  void _place(LatLng tap) {
    final index = _selected;
    if (index == null) return;

    // Between the nearest placed handovers on either side, because a stretch
    // cannot run backwards. Not merely the immediate neighbours: with the
    // selection free, the one next to it may still be open — and each open one
    // in between keeps a point of its own, as every stretch keeps two.
    int? previous;
    for (var i = index - 1; i >= 0 && previous == null; i--) {
      if (_cuts[i] != null) previous = i;
    }
    int? next;
    for (var i = index + 1; i < _cuts.length && next == null; i++) {
      if (_cuts[i] != null) next = i;
    }
    final after = previous == null
        ? index + 1
        : _cuts[previous]! + (index - previous);
    final before = next == null
        ? _flat.length - 1 - (_cuts.length - index)
        : _cuts[next]! - (next - index);
    final at = snapIndexOnTrack(_flat, tap, after: after, before: before);
    if (at == null) return;
    setState(() {
      _cuts[index] = at;
      _boundaries[index] = _flat[at];
      _selected = _nextOpen(index) ?? index;
    });
  }

  /// The first handover still open after [index], else the first one before
  /// it — or null when none is.
  int? _nextOpen(int index) {
    for (var i = index + 1; i < _boundaries.length; i++) {
      if (_boundaries[i] == null) return i;
    }
    return _open;
  }

  Future<void> _confirm() async {
    final navigator = Navigator.of(context);
    final stretches = splitTracksAt(widget.lines, [
      for (final cut in _cuts) cut!,
    ]);
    final ends = trackImportEnds(
      TrackImportPlan(
        legs: _plan.legs,
        boundaries: _boundaries,
        selection: widget.selection,
      ),
      first: _flat.first,
      last: _flat.last,
    );

    await ref
        .read(repositoryProvider)
        .importTrackAcross(
          name: widget.name,
          pieces: [
            for (var i = 0; i < _plan.legs.length; i++)
              for (final line in stretches[i])
                (itemId: _plan.legs[i].id, points: line),
          ],
          ends: ends,
          times: [
            for (final p in _proposalsAt(_offset))
              if (_isChosen(p, _timeChoices))
                (itemId: p.item.id, end: p.end, minutes: p.minutes),
          ],
        );
    navigator.pop(true);
  }

  /// A name for an entry in a question about it. The title is what the user
  /// wrote; failing that the route, which is what an imported leg carries.
  String _label(ItineraryItem leg, AppLocalizations l10n) {
    final title = leg.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    if (leg.kind == ItemKind.place) {
      final location = leg.location?.trim();
      return location == null || location.isEmpty
          ? l10n.untitledEntry
          : location;
    }
    final from = leg.fromLocation?.trim();
    final to = leg.toLocation?.trim();
    if (from != null && to != null && from.isNotEmpty && to.isNotEmpty) {
      return '$from → $to';
    }
    return from ?? to ?? l10n.transportLabelOptional;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const basemap = kDefaultBasemap;
    final selected = _selected;
    final placed = _placedPrefix;
    final stretches = splitTracksAt(widget.lines, placed);
    final proposals = _proposalsAt(_offset);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trackImportTitle)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    minZoom: kMinMapZoom,
                    maxZoom: maxZoomOf(basemap),
                    cameraConstraint: const FiniteCamera(),
                    initialCameraFit: _flat.length > 1
                        ? CameraFit.bounds(
                            bounds: LatLngBounds.fromPoints(_flat),
                            padding: const EdgeInsets.all(48),
                          )
                        : null,
                    initialCenter: _flat.first,
                    initialZoom: 13,
                    // The map's own tap, not a `GestureDetector` among its
                    // children: flutter_map's gesture handling wraps the
                    // children, so one placed there never wins the arena and no
                    // tap arrives at all. Nothing competes with it now — the
                    // handover marks are inert.
                    onTap: (_, point) => _place(point),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    basemapTileLayer(basemap, ref.watch(appVersionProvider)),
                    PolylineLayer(
                      polylines: [
                        for (var i = 0; i < stretches.length; i++)
                          for (final line in stretches[i])
                            Polyline(
                              points: line,
                              strokeWidth: 4,
                              // The last stretch is only *this* entry's once
                              // every handover after it has been placed.
                              color: i < placed.length || _complete
                                  ? kTrackPieceColors[i %
                                        kTrackPieceColors.length]
                                  : kTrackUndividedColor,
                              borderStrokeWidth: 2,
                              borderColor: theme.colorScheme.surface,
                            ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // On the line, where it divides it — not at the
                        // entry's coordinate it may have been read from,
                        // which can lie beside the line and so say nothing
                        // about which pass of it was taken.
                        for (var i = 0; i < _cuts.length; i++)
                          if (_cuts[i] case final cut?)
                            Marker(
                              point: _flat[cut],
                              width: 32,
                              height: 32,
                              // Ignoring pointers on purpose: the mark is a
                              // mark, not a control. Letting it take taps put it
                              // in competition with the layer that places
                              // handovers, and a tap that two widgets both want
                              // is a tap that does nothing.
                              child: IgnorePointer(
                                child: _Handover(
                                  number: i + 1,
                                  selected: i == selected,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
                // Placing a handover means finding a spot precisely, which is
                // exactly when a trackpad or a shaky finger needs a button.
                Positioned(
                  top: 12,
                  right: 12 + MediaQuery.paddingOf(context).right,
                  child: MapZoomButtons(
                    controller: _controller,
                    basemap: basemap,
                    zoomInTooltip: l10n.mapZoomIn,
                    zoomOutTooltip: l10n.mapZoomOut,
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: MapAttributionBar(basemap: basemap),
                ),
              ],
            ),
          ),
          _Panel(
            l10n: l10n,
            theme: theme,
            question: selected == null
                ? null
                : (_boundaries[selected] == null
                      ? l10n.trackTapBoundary
                      : l10n.trackMoveBoundary)(
                    _label(_plan.legs[selected], l10n),
                    _label(_plan.legs[selected + 1], l10n),
                  ),
            warning: _otherDayWarning(l10n),
            // Offered once the division is complete: before that there is no
            // stretch to read a leg's times off.
            times: _flatTimes.isEmpty || !_complete || _plan.legs.isEmpty
                ? null
                : (
                    l10n.trackActualTimesSummary(
                      proposals.where((p) => _isChosen(p, _timeChoices)).length,
                    ),
                    () => _showTimes(l10n),
                  ),
            handovers: [for (final cut in _cuts) cut != null],
            selected: selected,
            onSelect: (index) => setState(() => _selected = index),
            legend: [
              for (var i = 0; i < _plan.legs.length; i++)
                (
                  _label(_plan.legs[i], l10n),
                  kTrackPieceColors[i % kTrackPieceColors.length],
                ),
            ],
            // Says what it will do, because this import changes entries and not
            // only the map.
            summary: l10n.trackImportSummary(
              _plan.legs.length,
              trackImportEnds(
                TrackImportPlan(
                  legs: _plan.legs,
                  boundaries: _boundaries,
                  selection: widget.selection,
                ),
                first: _flat.first,
                last: _flat.last,
              ).length,
            ),
            // Nothing is written until every handover has been pointed at.
            onConfirm: _plan.legs.isEmpty || !_complete ? null : _confirm,
          ),
        ],
      ),
    );
  }
}

/// The strip under the map: which colour is which entry, what is being asked,
/// and the one button.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.l10n,
    required this.theme,
    required this.question,
    this.warning,
    this.times,
    required this.handovers,
    required this.selected,
    required this.onSelect,
    required this.legend,
    required this.summary,
    required this.onConfirm,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final String? question;

  /// The recording was made on other days than the entries — said, not
  /// refused.
  final String? warning;

  /// The row opening the actual-times sheet: what it says, and the tap.
  final (String, VoidCallback)? times;

  /// One per handover, saying whether it has been placed.
  final List<bool> handovers;
  final int? selected;
  final ValueChanged<int> onSelect;
  final List<(String, Color)> legend;
  final String summary;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final (label, colour) in legend)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 14, height: 4, color: colour),
                      const SizedBox(width: 6),
                      Text(label, style: theme.textTheme.labelSmall),
                    ],
                  ),
              ],
            ),
            if (handovers.isNotEmpty) ...[
              const SizedBox(height: 8),
              // Scrolls rather than wraps: a long run must not eat the map.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < handovers.length; i++)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          avatar: Icon(
                            handovers[i]
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 18,
                          ),
                          showCheckmark: false,
                          label: Text(l10n.trackHandoverChip(i + 1)),
                          selected: i == selected,
                          onSelected: (_) => onSelect(i),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (question case final question?) ...[
              const SizedBox(height: 8),
              Text(
                question,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
            if (warning case final warning?) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (times case (final text, final onTap)) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(text, style: theme.textTheme.bodyMedium),
                      ),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: onConfirm,
                  child: Text(l10n.trackImportConfirm),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A handover already placed.
///
/// Ink on a halo, in its own colours rather than the theme's — raster tiles are
/// pale in both themes and full of thin lines, so a mark tinted by the theme
/// reads as a road.
///
/// Numbered, so it can be matched to its chip in the panel; the selected one is
/// drawn larger, which is the map's half of saying which one a tap will move.
class _Handover extends StatelessWidget {
  const _Handover({required this.number, required this.selected});

  final int number;
  final bool selected;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: selected ? 30 : 22,
      height: selected ? 30 : 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF212121),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: selected ? 4 : 2),
      ),
      child: Text(
        '$number',
        style: TextStyle(
          color: Colors.white,
          fontSize: selected ? 13 : 11,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    ),
  );
}

/// The actual times a recording can write, and the zone it is read in.
///
/// Its own state rather than the screen's, since a sheet is a route of its own
/// and does not rebuild with the screen; every change is reported back through
/// [onChanged], so closing it however it is closed keeps what was set.
class _ActualTimesSheet extends StatefulWidget {
  const _ActualTimesSheet({
    required this.offset,
    required this.choices,
    required this.proposalsAt,
    required this.isChosen,
    required this.span,
    required this.label,
    required this.onChanged,
  });

  final Duration offset;
  final Map<(int, TrackEnd), bool> choices;
  final List<ActualTimeProposal> Function(Duration offset) proposalsAt;
  final bool Function(ActualTimeProposal, Map<(int, TrackEnd), bool>) isChosen;
  final String Function(Duration offset) span;
  final String Function(ItineraryItem) label;
  final void Function(Duration offset, Map<(int, TrackEnd), bool> choices)
  onChanged;

  @override
  State<_ActualTimesSheet> createState() => _ActualTimesSheetState();
}

class _ActualTimesSheetState extends State<_ActualTimesSheet> {
  late Duration _offset = widget.offset;
  late Map<(int, TrackEnd), bool> _choices = {...widget.choices};

  void _changed() => widget.onChanged(_offset, {..._choices});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final proposals = widget.proposalsAt(_offset);
    // Every quarter hour from UTC−12 to UTC+14, which covers every zone in
    // use — plus the device's own, should it ever not fall on one.
    final offsets = {
      for (var m = -12 * 60; m <= 14 * 60; m += 15) m,
      _offset.inMinutes,
    }.toList()..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.trackActualTimesTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            l10n.trackRecordingSpan(widget.span(_offset)),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(l10n.trackRecordingZone),
              const SizedBox(width: 16),
              DropdownButton<int>(
                value: _offset.inMinutes,
                items: [
                  for (final m in offsets)
                    DropdownMenuItem(value: m, child: Text(formatUtcOffset(m))),
                ],
                onChanged: (m) {
                  if (m == null) return;
                  setState(() => _offset = Duration(minutes: m));
                  _changed();
                },
              ),
            ],
          ),
          Text(
            l10n.trackRecordingZoneHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: 24),
          if (proposals.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.trackActualNone,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in proposals)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: widget.isChosen(p, _choices),
                      // The words the item form uses for the same two fields.
                      title: Text(
                        (switch ((p.item.kind, p.end)) {
                          (ItemKind.place, TrackEnd.from) =>
                            l10n.trackActualStart,
                          (ItemKind.place, _) => l10n.trackActualEnd,
                          (_, TrackEnd.from) => l10n.trackActualDeparture,
                          _ => l10n.trackActualArrival,
                        })(widget.label(p.item)),
                      ),
                      subtitle: Text(
                        p.existing == null
                            ? formatMinutes(p.minutes)
                            : l10n.trackActualReplaces(
                                formatMinutes(p.minutes),
                                formatMinutes(p.existing),
                              ),
                      ),
                      onChanged: (value) {
                        setState(
                          () => _choices = {
                            ..._choices,
                            (p.item.id, p.end): value ?? false,
                          },
                        );
                        _changed();
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// An offset from UTC as the picker names it: "UTC+02:00", "UTC−03:30", "UTC".
@visibleForTesting
String formatUtcOffset(int minutes) {
  if (minutes == 0) return 'UTC';
  final sign = minutes > 0 ? '+' : '\u2212';
  final abs = minutes.abs();
  final h = (abs ~/ 60).toString().padLeft(2, '0');
  final m = (abs % 60).toString().padLeft(2, '0');
  return 'UTC$sign$h:$m';
}
