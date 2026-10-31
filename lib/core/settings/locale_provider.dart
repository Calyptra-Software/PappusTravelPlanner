import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';

/// Holds the [SharedPreferences] instance. Overridden in `main` with the
/// already-loaded instance so settings can be read synchronously.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

/// The user's chosen app locale. `null` means "follow the system language".
final localeProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale?> {
  static const _key = 'locale_code';

  @override
  Locale? build() {
    final code = ref.read(sharedPreferencesProvider).getString(_key);
    if (code == null || code.isEmpty) return null;
    return Locale(code);
  }

  /// Sets and persists the locale; pass `null` to fall back to the system.
  Future<void> setLocale(Locale? locale) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
    state = locale;
  }
}

/// The locale the app's texts are in, for code that has no widget to ask: the
/// one [chosen] in settings, else the system's, clamped to a language the app
/// ships and defaulting to English — so [lookupAppLocalizations] always has an
/// answer. Read by the home-screen widget and the recording notification.
Locale appLocaleFor(Locale? chosen) {
  final wanted = chosen ?? WidgetsBinding.instance.platformDispatcher.locale;
  return AppLocalizations.supportedLocales.any(
        (l) => l.languageCode == wanted.languageCode,
      )
      ? Locale(wanted.languageCode)
      : const Locale('en');
}
