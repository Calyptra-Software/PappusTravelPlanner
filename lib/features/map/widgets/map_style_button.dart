import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../basemap.dart';
import '../basemap_provider.dart';
import 'map_overlays.dart';

/// The round button that opens the list of map styles and overlays.
///
/// Tinted while an overlay is on: it goes on fetching from a further server on
/// every map until it is switched off, which should not be easy to forget.
class MapStyleButton extends ConsumerWidget {
  const MapStyleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlaysOn = ref.watch(mapOverlaysProvider).isNotEmpty;
    return MapRoundButton(
      icon: Icons.layers_outlined,
      foreground: overlaysOn ? Theme.of(context).colorScheme.primary : null,
      tooltip: AppLocalizations.of(context).mapStyle,
      onPressed: () =>
          showAppSheet<void>(context, builder: (_) => const _MapStyleSheet()),
    );
  }
}

/// Stays open when something is picked, since overlays are often picked in
/// twos and a style together with one.
class _MapStyleSheet extends ConsumerWidget {
  const _MapStyleSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final overlaysOn = ref.watch(mapOverlaysProvider);

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading(l10n.mapStyle),
            RadioGroup<Basemap>(
              groupValue: ref.watch(basemapProvider),
              onChanged: (selected) {
                if (selected != null) {
                  ref.read(basemapProvider.notifier).set(selected);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final basemap in kBasemaps)
                    RadioListTile<Basemap>(
                      value: basemap,
                      title: Text(basemap.name),
                      subtitle: Text(switch (basemap.purpose) {
                        BasemapPurpose.everyday => l10n.mapStyleEveryday,
                        BasemapPurpose.topographic => l10n.mapStyleTopographic,
                        BasemapPurpose.cycling => l10n.mapStyleCycling,
                        BasemapPurpose.muted => l10n.mapStyleMuted,
                      }),
                    ),
                ],
              ),
            ),
            heading(l10n.mapOverlays),
            for (final overlay in kMapOverlays)
              CheckboxListTile(
                value: overlaysOn.contains(overlay),
                title: Text(switch (overlay.content) {
                  MapOverlayContent.skiSlopes => l10n.mapOverlaySkiSlopes,
                  MapOverlayContent.railways => l10n.mapOverlayRailways,
                  MapOverlayContent.seamarks => l10n.mapOverlaySeamarks,
                }),
                subtitle: Text(overlay.source),
                onChanged: (on) => ref
                    .read(mapOverlaysProvider.notifier)
                    .set(overlay, on: on ?? false),
              ),
          ],
        ),
      ),
    );
  }
}
