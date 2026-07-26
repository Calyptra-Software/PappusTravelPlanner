import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/locale_provider.dart';
import '../../../l10n/app_localizations.dart';

/// The language the routing service is asked to answer in.
///
/// It is **the language the app itself is showing**, not the raw system one: a
/// German UI listing "Czechia" under a Prague station, or an English one saying
/// "Tschechien", is the same mismatch either way. So this resolves exactly as
/// `MaterialApp` does — the user's chosen locale when they have set one,
/// otherwise the platform's list matched against what the app can speak.
///
/// The service uses it to pick *which translation of a name* to return: the
/// areas beside a geocoded stop (`Tschechien` / `Czechia` / `Česko`), and the
/// stop names on a routed leg wherever the timetable ships translations
/// (`Brussel-Zuid` / `Brux.-Midi/Brus.-Zuid`). Sending nothing is not neutral —
/// the geocoder then answers with the whole multilingual tag at once
/// ("België / Belgique / Belgien"). It does *not* affect which places a query
/// matches: "Vienna" finds places actually called that, never Wien.
final searchLanguageProvider = Provider<String>((ref) {
  final chosen = ref.watch(localeProvider);
  if (chosen != null) return chosen.languageCode;
  return basicLocaleListResolution(
    WidgetsBinding.instance.platformDispatcher.locales,
    AppLocalizations.supportedLocales,
  ).languageCode;
});
