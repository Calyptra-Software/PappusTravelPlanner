/// Where the connection search's data comes from, and — the part that makes it
/// attribution rather than a credit — how to get there.
///
/// Transitous asks that its sources page be *linked* somewhere visible, and the
/// OpenStreetMap data underneath it carries the same condition, so both are
/// real links wherever they appear: under the search itself, where the data is
/// being used, and in settings, where an entry survives the sheet being closed
/// (an imported connection outlives the search that found it — it sits in the
/// timeline, the PDF and the calendar export).
library;

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import 'external_link.dart';

/// OpenStreetMap's own copyright and attribution page.
const String kOsmCopyrightUrl = 'https://www.openstreetmap.org/copyright';

/// Transitous' list of the timetable feeds it serves, which its usage policy
/// asks applications to link.
const String kTransitousSourcesUrl = 'https://transitous.org/sources/';

/// BRouter, which computes the route planner's routes on OpenStreetMap data.
const String kBrouterUrl = 'https://brouter.de/';

/// The Overpass API, which the route planner loads pistes and lifts from.
const String kOverpassSiteUrl = 'https://overpass-api.de/';

/// OpenStreetMap's page for reporting an error in the map data. The terms of
/// overpass-api.de ask apps using it to link there, so that someone who finds
/// a piste or lift wrong can have it put right.
const String kOsmFixTheMapUrl = 'https://www.openstreetmap.org/fixthemap';

/// The one-line attribution shown under the connection search: both sources,
/// both tappable.
class AttributionFooter extends StatelessWidget {
  const AttributionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 2,
      children: [
        _AttributionLink(
          label: l10n.attributionOsm,
          url: kOsmCopyrightUrl,
          style: style,
        ),
        _AttributionLink(
          label: l10n.attributionTransitous,
          url: kTransitousSourcesUrl,
          style: style,
        ),
      ],
    );
  }
}

class _AttributionLink extends StatelessWidget {
  const _AttributionLink({
    required this.label,
    required this.url,
    required this.style,
  });

  final String label;
  final String url;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openExternalLink(context, url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          label,
          style: style?.copyWith(decoration: TextDecoration.underline),
        ),
      ),
    );
  }
}

/// The same sources as settings rows, the route planner's router among them, where they stay reachable whether or
/// not a search is open.
class DataSourcesSettings extends StatelessWidget {
  const DataSourcesSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.dataSourcesNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.map_outlined),
          title: Text(l10n.attributionOsm),
          subtitle: Text(kOsmCopyrightUrl, style: theme.textTheme.bodySmall),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => openExternalLink(context, kOsmCopyrightUrl),
        ),
        ListTile(
          leading: const Icon(Icons.directions_transit_outlined),
          title: Text(l10n.attributionTransitous),
          subtitle: Text(
            kTransitousSourcesUrl,
            style: theme.textTheme.bodySmall,
          ),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => openExternalLink(context, kTransitousSourcesUrl),
        ),
        ListTile(
          leading: const Icon(Icons.alt_route),
          title: Text(l10n.attributionBrouter),
          subtitle: Text(kBrouterUrl, style: theme.textTheme.bodySmall),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => openExternalLink(context, kBrouterUrl),
        ),
        ListTile(
          leading: const Icon(Icons.downhill_skiing),
          title: Text(l10n.attributionOverpass),
          subtitle: Text(kOverpassSiteUrl, style: theme.textTheme.bodySmall),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => openExternalLink(context, kOverpassSiteUrl),
        ),
        ListTile(
          leading: const Icon(Icons.edit_location_alt_outlined),
          title: Text(l10n.attributionFixTheMap),
          subtitle: Text(kOsmFixTheMapUrl, style: theme.textTheme.bodySmall),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => openExternalLink(context, kOsmFixTheMapUrl),
        ),
      ],
    );
  }
}
