import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
