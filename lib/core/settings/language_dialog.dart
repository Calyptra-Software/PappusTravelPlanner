import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'locale_provider.dart';

/// Human label for the currently selected language ('System default' when the
/// app follows the device language).
String currentLanguageLabel(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  switch (ref.watch(localeProvider)?.languageCode) {
    case 'en':
      return l10n.languageEnglish;
    case 'de':
      return l10n.languageGerman;
    default:
      return l10n.languageSystem;
  }
}

/// Shows the language picker and applies the choice (persisted via the provider).
Future<void> showLanguageDialog(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  final current = ref.read(localeProvider)?.languageCode;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(l10n.language),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: RadioGroup<String?>(
          groupValue: current,
          onChanged: (selected) {
            ref
                .read(localeProvider.notifier)
                .setLocale(selected == null ? null : Locale(selected));
            Navigator.of(dialogContext).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String?>(
                title: Text(l10n.languageSystem),
                value: null,
              ),
              RadioListTile<String?>(
                title: Text(l10n.languageEnglish),
                value: 'en',
              ),
              RadioListTile<String?>(
                title: Text(l10n.languageGerman),
                value: 'de',
              ),
            ],
          ),
        ),
      );
    },
  );
}
