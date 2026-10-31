import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/format/date_format.dart';
import '../../../core/format/distance_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../trips/application/trip_providers.dart';
import '../location/track_recorder.dart';
import '../track_import_flow.dart';
import 'device_location_overlay.dart';
import 'map_overlays.dart';

/// Whether [state] holds a recording this trip's map offers: one started from
/// [tripId], or one whose trip is gone, which every trip may take in.
bool recordingIsFor(TrackRecorderState state, int tripId) =>
    state.recordingId != null &&
    (state.tripId == null || state.tripId == tripId);

/// Says why a start or a continue came to nothing, or why a running recording
/// stopped by itself — once, the way the locate button reports its own.
///
/// Call from `build`.
void reportRecordingProblems(BuildContext context, WidgetRef ref) {
  ref.listen(trackRecorderProvider, (previous, next) {
    final problem = next.problem;
    if (problem == null || problem == previous?.problem) return;
    showLocationProblem(context, problem);
  });
}

/// The recording as it is being made, drawn over the plan.
///
/// In the device's own blue, because it is the device's own: where the receiver
/// has been, as the mark is where it is. Neither the trip's accent, which would
/// make it look like part of the plan before anybody has said which part, nor
/// the red reserved for an entry under way. Each segment is its own line, so a
/// pause stays a gap, and while it runs its newest point carries a dot, which is
/// where the next stretch will be drawn from.
class RecordingLayer extends ConsumerWidget {
  const RecordingLayer({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackRecorderProvider);
    if (!recordingIsFor(state, tripId)) return const SizedBox.shrink();
    final casing = Theme.of(context).colorScheme.surface;
    final head = state.running
        ? state.lines
              .lastWhere((l) => l.isNotEmpty, orElse: () => [])
              .lastOrNull
        : null;
    // Two layers in one widget, so the map lists one child for the recording;
    // expanded as the map's own layers are.
    return Stack(
      fit: StackFit.expand,
      children: [
        PolylineLayer(
          polylines: [
            for (final line in state.lines)
              if (line.length > 1)
                Polyline(
                  points: line,
                  strokeWidth: 4,
                  color: kLocationBlue,
                  borderStrokeWidth: 2,
                  borderColor: casing,
                ),
          ],
        ),
        if (head != null)
          MarkerLayer(
            markers: [
              Marker(point: head, width: 14, height: 14, child: const _Head()),
            ],
          ),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: kLocationBlue,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
    ),
  );
}

/// What the record press means right now, read off the recorder.
///
/// One press and four meanings: start when there is no recording, stop while
/// this trip's runs (or withdraw a start still waiting for its permission),
/// continue one this trip holds — the press that started it, made again — and,
/// while another trip holds one, say where it is. There is one recording at a
/// time, and a second would only be filed into the wrong trip by whoever forgot
/// the first. Shared by the round button over a map and the labelled one an
/// empty map offers instead, so the two cannot come to mean different things.
({IconData icon, String label, bool on, bool busy, VoidCallback onPressed})
recordAction(BuildContext context, WidgetRef ref, int tripId) {
  final l10n = AppLocalizations.of(context);
  final state = ref.watch(trackRecorderProvider);
  final recorder = ref.read(trackRecorderProvider.notifier);
  final ours = recordingIsFor(state, tripId);

  if (state.starting || (ours && state.running)) {
    return (
      icon: Icons.stop,
      label: l10n.mapRecordStop,
      on: true,
      busy: state.starting,
      onPressed: recorder.stop,
    );
  }
  // Watched rather than read on the press: the trip is an autoDispose stream,
  // and nothing else here holds it open long enough to answer.
  final elsewhere = !ours && state.recordingId != null && state.tripId != null
      ? ref.watch(tripProvider(state.tripId!)).value?.title
      : null;
  return (
    icon: Icons.fiber_manual_record_outlined,
    label: ours ? l10n.recordingContinue : l10n.mapRecordStart,
    on: false,
    busy: false,
    onPressed: () {
      if (ours) {
        recorder.resume();
      } else if (state.recordingId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.mapRecordElsewhere(elsewhere ?? ''))),
        );
      } else {
        recorder.start(tripId: tripId);
      }
    },
  );
}

/// The record button over a trip's map, in the column with the locate button.
class MapRecordButton extends ConsumerWidget {
  const MapRecordButton({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = recordAction(context, ref, tripId);
    return MapRoundButton(
      icon: action.icon,
      foreground: action.on ? kLocationBlue : null,
      tooltip: action.label,
      onPressed: action.onPressed,
      busy: action.busy,
    );
  }
}

/// The same press, with its words on it, for a map that has nothing to draw
/// yet — where a recording is the one way to get something onto it.
class RecordTrackButton extends ConsumerWidget {
  const RecordTrackButton({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = recordAction(context, ref, tripId);
    return FilledButton.tonalIcon(
      icon: Icon(action.icon),
      label: Text(action.label),
      onPressed: action.onPressed,
    );
  }
}

/// What the recording is doing, under the map, with what can be done about it.
///
/// Always on screen while this trip's map offers a recording, because a
/// recording is the one thing on this screen that goes on without being
/// looked at — a held one is still taking up the only slot there is. Running,
/// it says how far and since when, and stops; held, it says why it is held
/// and offers the three ways on: continue, attach it to the trip's entries (the
/// track import, with the line already in hand), or throw it away.
class RecordingBand extends ConsumerWidget {
  const RecordingBand({super.key, required this.tripId});

  final int tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackRecorderProvider);
    if (!recordingIsFor(state, tripId)) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final recorder = ref.read(trackRecorderProvider.notifier);
    final distance = formatDistance(state.meters);
    final onColor = theme.colorScheme.onSecondaryContainer;

    final text = state.running
        ? l10n.recordingRunning(distance, _since(state.startedAt))
        : state.interrupted
        ? l10n.recordingInterrupted(distance)
        : l10n.recordingStopped(distance);
    final label = Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: onColor,
        fontWeight: FontWeight.w600,
      ),
    );
    final icon = Icon(
      state.running ? Icons.fiber_manual_record : Icons.pause_circle_outline,
      size: 20,
      color: state.running ? kLocationBlue : onColor,
    );

    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: state.running
              ? Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: label),
                    TextButton(
                      onPressed: recorder.stop,
                      child: Text(l10n.mapRecordStop),
                    ),
                  ],
                )
              : Column(
                  // A bottom bar is handed loose constraints; see `_HoldingBar`.
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        icon,
                        const SizedBox(width: 12),
                        Expanded(child: label),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: onColor,
                          tooltip: l10n.recordingDiscard,
                          onPressed: () => _discard(context, ref),
                        ),
                      ],
                    ),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: recorder.resume,
                          child: Text(l10n.recordingContinue),
                        ),
                        FilledButton.tonal(
                          onPressed: () =>
                              fileRecording(context, ref, tripId: tripId),
                          child: Text(l10n.recordingFile),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// The local time of day the recording started, as the rest of the app
  /// writes a time.
  static String _since(DateTime? startedAt) {
    if (startedAt == null) return '';
    final local = startedAt.toLocal();
    return formatMinutes(local.hour * 60 + local.minute);
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.recordingDiscardQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.recordingDiscard),
          ),
        ],
      ),
    );
    if (sure == true) await ref.read(trackRecorderProvider.notifier).discard();
  }
}

/// Every point the recording has kept so far, for framing a map on it.
List<LatLng> recordingPoints(TrackRecorderState state) => [
  for (final line in state.lines) ...line,
];
