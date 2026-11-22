import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../settings/server_setting.dart';
import 'text_prompt_dialog.dart';

/// A settings row for a server the app asks: the address it uses, a tap
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
    final server = controller.parse(typed);
    if (server == null) {
      // An address, but one the operator put off limits, is not a typo.
      final offLimits =
          parseServer(typed, defaultPath: controller.defaultPath) != null;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            offLimits ? l10n.serverOffLimits : l10n.routingServerInvalid,
          ),
        ),
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
