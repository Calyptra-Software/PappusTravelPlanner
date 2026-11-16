import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/text_prompt_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../application/routing_server_provider.dart';

/// The settings row for the BRouter server the route planner asks: the
/// address it uses, a tap to set another, and a way back to the default.
class RoutingServerSettings extends ConsumerWidget {
  const RoutingServerSettings({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(routingServerProvider.notifier);
    final typed = await showTextPromptDialog(
      context,
      title: l10n.routingServer,
      label: l10n.routingServerAddress,
      hint: l10n.routingServerHint,
      initial: ref.read(routingServerProvider).toString(),
      confirmLabel: l10n.save,
      textCapitalization: TextCapitalization.none,
    );
    if (typed == null) return;
    // A field cleared is the way back to the default, as for a label.
    if (typed.trim().isEmpty) {
      await controller.set(null);
      return;
    }
    final server = parseRoutingServer(typed);
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
    final server = ref.watch(routingServerProvider);
    final isDefault = ref.read(routingServerProvider.notifier).isDefault;
    return ListTile(
      leading: const Icon(Icons.dns_outlined),
      title: Text(l10n.routingServer),
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
              onPressed: () =>
                  ref.read(routingServerProvider.notifier).set(null),
            ),
    );
  }
}
