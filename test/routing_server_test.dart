import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/providers.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/features/route_planner/application/route_planner_providers.dart';
import 'package:travelplanner/features/route_planner/application/routing_server_provider.dart';
import 'package:travelplanner/features/route_planner/data/brouter_client.dart';
import 'package:travelplanner/features/route_planner/domain/route_profile.dart';
import 'package:travelplanner/features/route_planner/presentation/routing_server_settings.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

void main() {
  group('parseRoutingServer', () {
    test('takes an address with a path as it is', () {
      expect(
        parseRoutingServer(' https://routing.example.org/brouter '),
        Uri.parse('https://routing.example.org/brouter'),
      );
      expect(
        parseRoutingServer('http://192.168.1.5:17777/proxy/brouter/'),
        Uri.parse('http://192.168.1.5:17777/proxy/brouter'),
      );
    });

    test('gives a bare server the path BRouter answers under', () {
      expect(
        parseRoutingServer('https://routing.example.org'),
        Uri.parse('https://routing.example.org/brouter'),
      );
      expect(
        parseRoutingServer('http://localhost:17777/'),
        Uri.parse('http://localhost:17777/brouter'),
      );
    });

    test('refuses what is not a server address', () {
      for (final text in [
        '',
        'brouter.de',
        'ftp://brouter.de/brouter',
        'https://',
        'https://brouter.de/brouter?profile=car',
        'https://brouter.de/brouter#x',
        'not a url at all',
      ]) {
        expect(parseRoutingServer(text), isNull, reason: text);
      }
    });
  });

  group('the routing server', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('is brouter.de until another is set', () {
      final c = container();

      expect(c.read(routingServerProvider), kBrouterBaseUrl);
      expect(c.read(routingServerProvider.notifier).isDefault, isTrue);
    });

    test('is remembered across launches, and forgotten on reset', () async {
      final own = Uri.parse('https://routing.example.org/brouter');
      await container().read(routingServerProvider.notifier).set(own);

      expect(container().read(routingServerProvider), own);

      await container().read(routingServerProvider.notifier).set(null);
      expect(container().read(routingServerProvider), kBrouterBaseUrl);
      expect(prefs.getKeys(), isEmpty);
    });

    test('an unreadable stored address falls back to the default', () async {
      await prefs.setString('route_planner_server', 'garbage');

      expect(container().read(routingServerProvider), kBrouterBaseUrl);
    });

    test(
      'the planner\'s router is built for it, and anew when it changes',
      () async {
        final c = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            appVersionProvider.overrideWithValue('1.2.3'),
          ],
        );
        final first = c.read(routeEngineProvider);
        expect(first, isA<BrouterRouteEngine>());

        await c
            .read(routingServerProvider.notifier)
            .set(Uri.parse('https://routing.example.org/brouter'));

        expect(identical(c.read(routeEngineProvider), first), isFalse);
        // Closing the container closes the client the router holds.
        c.dispose();
      },
    );

    test('is where the router sends its requests', () async {
      late Uri asked;
      final engine = BrouterRouteEngine(
        baseUrl: Uri.parse('http://localhost:17777/brouter'),
        httpClient: MockClient((request) async {
          asked = request.url;
          return http.Response('', 500);
        }),
      );
      try {
        await engine.route(
          waypoints: const [LatLng(47, 11), LatLng(47.1, 11)],
          profile: RouteProfile.foot,
        );
      } on Exception {
        // The answer does not matter here, only where the question went.
      }
      expect(asked.host, 'localhost');
      expect(asked.port, 17777);
      expect(asked.path, '/brouter');
      expect(asked.queryParameters['profile'], 'hiking-mountain');
    });
  });

  group('the settings row', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

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
          home: Scaffold(body: RoutingServerSettings()),
        ),
      ),
    );

    Future<void> enter(WidgetTester tester, String text) async {
      await tester.tap(find.text('Routing server'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    testWidgets('says which server is used, and that it is the default', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('https://brouter.de/brouter (default)'), findsOneWidget);
      expect(find.byTooltip('Use the default server'), findsNothing);
    });

    testWidgets('takes another server, and gives the default back', (
      tester,
    ) async {
      await pump(tester);

      await enter(tester, 'https://routing.example.org');
      expect(find.text('https://routing.example.org/brouter'), findsOneWidget);
      expect(prefs.getString('route_planner_server'), isNotNull);

      await tester.tap(find.byTooltip('Use the default server'));
      await tester.pumpAndSettle();
      expect(find.text('https://brouter.de/brouter (default)'), findsOneWidget);
    });

    testWidgets('a cleared field goes back to the default', (tester) async {
      await prefs.setString(
        'route_planner_server',
        'https://routing.example.org/brouter',
      );
      await pump(tester);

      await enter(tester, '');

      expect(find.text('https://brouter.de/brouter (default)'), findsOneWidget);
      expect(prefs.getString('route_planner_server'), isNull);
    });

    testWidgets('says so when what was typed is not an address', (
      tester,
    ) async {
      await pump(tester);

      await enter(tester, 'brouter.example.org');

      expect(
        find.textContaining("isn't the address of a server"),
        findsOneWidget,
      );
      expect(prefs.getString('route_planner_server'), isNull);
    });
  });
}
