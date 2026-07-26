import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/settings/locale_provider.dart';
import 'package:travelplanner/features/transport_search/application/search_language_provider.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// The language the connection search asks the routing service to answer in.
/// It decides which translation of a name comes back — the areas beside a
/// geocoded stop, and the stop names on a routed leg — so it has to be the
/// language the app is actually showing, not the raw system one.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() => binding.platformDispatcher.clearLocalesTestValue());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('follows the locale the user chose', () async {
    binding.platformDispatcher.localesTestValue = const [Locale('en')];
    final c = container();
    await c.read(localeProvider.notifier).setLocale(const Locale('de'));

    expect(c.read(searchLanguageProvider), 'de');
  });

  test('follows the system language when the app does', () {
    binding.platformDispatcher.localesTestValue = const [
      Locale('de'),
      Locale('en'),
    ];

    expect(container().read(searchLanguageProvider), 'de');
  });

  test('a system language the app cannot speak falls back to English', () {
    // Czech isn't translated, so Flutter falls the *whole app* back to the
    // first supported locale — English, which `l10n.yaml`'s
    // `preferred-supported-locales` puts there (the generator would otherwise
    // order them alphabetically and hand everyone German). The place names have
    // to follow the UI there: asking the service for `cs` would put Czech area
    // names under a screen that isn't Czech.
    binding.platformDispatcher.localesTestValue = const [Locale('cs')];

    expect(container().read(searchLanguageProvider), 'en');
    expect(AppLocalizations.supportedLocales.first, const Locale('en'));
  });

  test('changing the language rebuilds the backend', () async {
    binding.platformDispatcher.localesTestValue = const [Locale('en')];
    final c = container();
    final before = c.read(searchLanguageProvider);
    await c.read(localeProvider.notifier).setLocale(const Locale('de'));

    expect(before, 'en');
    expect(c.read(searchLanguageProvider), 'de');
  });
}
