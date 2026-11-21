import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/text_prompt_dialog.dart';
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

/// A settings row for a server the planner asks: the address it uses, a tap
/// to set another, and a way back to the default.
class ServerSettings extends ConsumerWidget {
  const ServerSettings({
    super.key,
    required this.provider,
    required this.icon,
    required this.title,
    required this.hint,
  });

  final NotifierProvider<ServerSettingController, Uri> provider;
  final IconData icon;
  final String title;

  /// What the address field suggests: which kind of server, with an example.
  final String hint;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(provider.notifier);
    final typed = await showTextPromptDialog(
      context,
      title: title,
      label: l10n.routingServerAddress,
      hint: hint,
      initial: ref.read(provider).toString(),
      confirmLabel: l10n.save,
      textCapitalization: TextCapitalization.none,
    );
    if (typed == null) return;
    // A field cleared is the way back to the default, as for a label.
    if (typed.trim().isEmpty) {
      await controller.set(null);
      return;
    }
    final server = parseServer(typed, defaultPath: controller.defaultPath);
    if (server == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.routingServerInvalid)),
      );
      return;
    }
    await controller.set(server);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final server = ref.watch(provider);
    final isDefault = ref.read(provider.notifier).isDefault;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        isDefault ? l10n.routingServerDefault(server.toString()) : '$server',
        style: theme.textTheme.bodySmall,
      ),
      onTap: () => _edit(context, ref),
      trailing: isDefault
          ? null
          : IconButton(
              icon: const Icon(Icons.settings_backup_restore),
              tooltip: l10n.routingServerReset,
              onPressed: () => ref.read(provider.notifier).set(null),
            ),
    );
  }
}
