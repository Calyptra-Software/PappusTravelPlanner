import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'theme_mode_provider.dart';

/// Human label for the currently selected theme mode.
String currentThemeModeLabel(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  switch (ref.watch(themeModeProvider)) {
    case ThemeMode.light:
      return l10n.themeLight;
    case ThemeMode.dark:
      return l10n.themeDark;
    case ThemeMode.system:
      return l10n.themeSystem;
  }
}

/// Shows the theme picker and applies the choice (persisted via the provider).
Future<void> showThemeModeDialog(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  final current = ref.read(themeModeProvider);

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(l10n.theme),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: RadioGroup<ThemeMode>(
          groupValue: current,
          onChanged: (selected) {
            if (selected != null) {
              ref.read(themeModeProvider.notifier).setThemeMode(selected);
            }
            Navigator.of(dialogContext).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: Text(l10n.themeSystem),
                value: ThemeMode.system,
              ),
              RadioListTile<ThemeMode>(
                title: Text(l10n.themeLight),
                value: ThemeMode.light,
              ),
              RadioListTile<ThemeMode>(
                title: Text(l10n.themeDark),
                value: ThemeMode.dark,
              ),
            ],
          ),
        ),
      );
    },
  );
}
