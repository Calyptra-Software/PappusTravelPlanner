import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/features/route_planner/application/routing_server_provider.dart';
import 'package:travelplanner/features/route_planner/data/brouter_client.dart';
import 'package:travelplanner/features/transport_search/application/transport_search_providers.dart';
import 'package:travelplanner/features/transport_search/data/motis_client.dart';
import 'package:travelplanner/features/transport_search/presentation/transit_server_settings.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appVersionProvider.overrideWithValue('1.2.3'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('the connection server', () {
    test('is Transitous until another is set, kept apart', () async {
      final c = container();
      expect(c.read(transitServerProvider), kTransitousBaseUrl);
      expect(c.read(transitServerProvider.notifier).isDefault, isTrue);

      final own = Uri.parse('https://motis.example.org');
      await c.read(transitServerProvider.notifier).set(own);

      expect(container().read(transitServerProvider), own);
      expect(c.read(routingServerProvider), kBrouterBaseUrl);
      expect(prefs.getString('transit_server'), own.toString());
    });

    test('refuses the hosts their operators keep from apps', () {
      final controller = container().read(transitServerProvider.notifier);

      for (final text in [
        'https://staging.api.transitous.org',
        'https://europe.motis-project.de',
        'https://MOTIS-PROJECT.example.org/api',
      ]) {
        expect(controller.parse(text), isNull, reason: text);
      }
      expect(
        controller.parse('https://motis.example.org/'),
        Uri.parse('https://motis.example.org'),
      );
      // Only a whole label counts: a host merely containing the words is not
      // the project's.
      expect(
        controller.parse('https://my-motis-project.example.org'),
        isNotNull,
      );
    });

    test('a refused address stored somehow falls back to Transitous', () async {
      await prefs.setString(
        'transit_server',
        'https://staging.api.transitous.org',
      );

      expect(container().read(transitServerProvider), kTransitousBaseUrl);
    });

    test('the search is built for it, and anew when it changes', () async {
      final c = container();
      final first = c.read(transportSearchProvider) as MotisTransportSearch;
      expect(first.baseUrl, kTransitousBaseUrl);

      await c
          .read(transitServerProvider.notifier)
          .set(Uri.parse('https://motis.example.org'));

      final second = c.read(transportSearchProvider) as MotisTransportSearch;
      expect(identical(second, first), isFalse);
      expect(second.baseUrl, Uri.parse('https://motis.example.org'));
    });

    test('is where the search sends its requests', () async {
      late Uri asked;
      final search = MotisTransportSearch(
        baseUrl: Uri.parse('http://localhost:8080'),
        httpClient: MockClient((request) async {
          asked = request.url;
          return http.Response('[]', 200);
        }),
      );

      await search.searchPlaces('Hamburg');

      expect(asked.host, 'localhost');
      expect(asked.port, 8080);
      expect(asked.path, '/api/v1/geocode');
    });
  });

  group('the settings row', () {
    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appVersionProvider.overrideWithValue('0.0.0-test'),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TransitServerSettings()),
        ),
      ),
    );

    Future<void> enter(WidgetTester tester, String text) async {
      await tester.tap(find.text('Connection server'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    testWidgets('takes another server, and gives the default back', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('https://api.transitous.org (default)'), findsOneWidget);

      await enter(tester, 'https://motis.example.org');
      expect(find.text('https://motis.example.org'), findsOneWidget);

      await tester.tap(find.byTooltip('Use the default server'));
      await tester.pumpAndSettle();
      expect(find.text('https://api.transitous.org (default)'), findsOneWidget);
      expect(prefs.getString('transit_server'), isNull);
    });

    testWidgets('says why a host off limits is not taken', (tester) async {
      await pump(tester);

      await enter(tester, 'https://staging.api.transitous.org');

      expect(
        find.text("Its operator doesn't allow apps to use that server."),
        findsOneWidget,
      );
      expect(prefs.getString('transit_server'), isNull);
    });
  });
}
