import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/server_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../application/routing_server_provider.dart';

/// The settings row for the BRouter server the route planner asks.
class RoutingServerSettings extends StatelessWidget {
  const RoutingServerSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ServerSettings(
      provider: routingServerProvider,
      icon: Icons.dns_outlined,
      title: l10n.routingServer,
      hint: l10n.routingServerHint,
    );
  }
}

/// The settings row for the Overpass server ski runs load their map data
/// from.
class OverpassServerSettings extends StatelessWidget {
  const OverpassServerSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ServerSettings(
      provider: overpassServerProvider,
      icon: Icons.downhill_skiing,
      title: l10n.overpassServer,
      hint: l10n.overpassServerHint,
    );
  }
}

/// The settings row for the server ski runs take their heights from.
class TerrainServerSettings extends StatelessWidget {
  const TerrainServerSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ServerSettings(
      provider: terrainServerProvider,
      icon: Icons.terrain_outlined,
      title: l10n.terrainServer,
      hint: l10n.terrainServerHint,
    );
  }
}
