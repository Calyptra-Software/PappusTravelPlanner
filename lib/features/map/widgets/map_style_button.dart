import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../basemap.dart';
import '../basemap_provider.dart';
import 'map_overlays.dart';

/// The round button that opens the list of map styles.
class MapStyleButton extends ConsumerWidget {
  const MapStyleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MapRoundButton(
      icon: Icons.layers_outlined,
      tooltip: AppLocalizations.of(context).mapStyle,
      onPressed: () =>
          showAppSheet<void>(context, builder: (_) => const _MapStyleSheet()),
    );
  }
}

class _MapStyleSheet extends ConsumerWidget {
  const _MapStyleSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 12),
        child: RadioGroup<Basemap>(
          groupValue: ref.watch(basemapProvider),
          onChanged: (selected) {
            if (selected != null) {
              ref.read(basemapProvider.notifier).set(selected);
            }
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  l10n.mapStyle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final basemap in kBasemaps)
                RadioListTile<Basemap>(
                  value: basemap,
                  title: Text(basemap.name),
                  subtitle: Text(switch (basemap.purpose) {
                    BasemapPurpose.everyday => l10n.mapStyleEveryday,
                    BasemapPurpose.topographic => l10n.mapStyleTopographic,
                    BasemapPurpose.cycling => l10n.mapStyleCycling,
                    BasemapPurpose.muted => l10n.mapStyleMuted,
                    BasemapPurpose.ski => l10n.mapStyleSki,
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
