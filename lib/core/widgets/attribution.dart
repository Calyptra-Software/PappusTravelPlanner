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

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';

/// OpenStreetMap's own copyright and attribution page.
const String kOsmCopyrightUrl = 'https://www.openstreetmap.org/copyright';

/// Transitous' list of the timetable feeds it serves, which its usage policy
/// asks applications to link.
const String kTransitousSourcesUrl = 'https://transitous.org/sources/';

/// Opens [url] in the platform's browser, telling the user when that fails
/// rather than leaving a tap that does nothing.
///
/// A link that silently refuses is worse than none here: the attribution is
/// only discharged if the source page can actually be reached.
Future<void> openAttributionLink(BuildContext context, String url) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (opened) return;
  messenger?.showSnackBar(SnackBar(content: Text(l10n.linkOpenFailed(url))));
}

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
      onTap: () => openAttributionLink(context, url),
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

/// The same two sources as settings rows, where they stay reachable whether or
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
          onTap: () => openAttributionLink(context, kOsmCopyrightUrl),
        ),
        ListTile(
          leading: const Icon(Icons.directions_transit_outlined),
          title: Text(l10n.attributionTransitous),
          subtitle: Text(
            kTransitousSourcesUrl,
            style: theme.textTheme.bodySmall,
          ),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => openAttributionLink(context, kTransitousSourcesUrl),
        ),
      ],
    );
  }
}
