import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/server_settings.dart';
import '../../../l10n/app_localizations.dart';
import '../application/transport_search_providers.dart';

/// The settings row for the MOTIS server the connection search asks.
class TransitServerSettings extends StatelessWidget {
  const TransitServerSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ServerSettings(
      provider: transitServerProvider,
      icon: Icons.directions_transit_outlined,
      title: l10n.transitServer,
      hint: l10n.transitServerHint,
    );
  }
}
