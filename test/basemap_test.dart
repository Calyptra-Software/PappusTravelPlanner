import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'package:travelplanner/core/widgets/attribution.dart';
import 'package:travelplanner/features/map/basemap.dart';
import 'package:travelplanner/features/map/basemap_provider.dart';
import 'package:travelplanner/features/map/widgets/map_overlays.dart';
import 'package:travelplanner/features/map/widgets/map_style_button.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

void main() {
  final rasters = kBasemaps.cast<RasterBasemap>();

  group('the list of styles', () {
    test('ids are unique, because the choice is stored by id', () {
      expect(kBasemaps.map((b) => b.id).toSet(), hasLength(kBasemaps.length));
    });

    test('every tile URL is https and addresses a tile', () {
      final urls = [
        for (final basemap in rasters) ...[
          basemap.urlTemplate,
          ...basemap.overlays.map((overlay) => overlay.urlTemplate),
        ],
      ];
      for (final url in urls) {
        expect(url, startsWith('https://'));
        expect(url, allOf(contains('{z}'), contains('{x}'), contains('{y}')));
      }
    });

    // A condition of use on every one of these servers.
    test('every style credits OpenStreetMap, with a link', () {
      for (final basemap in kBasemaps) {
        expect(
          basemap.attributions.map((a) => a.url),
          contains(kOsmCopyrightUrl),
          reason: basemap.id,
        );
        for (final attribution in basemap.attributions) {
          expect(attribution.url, startsWith('https://'));
        }
      }
    });

    test('nothing may be downloaded ahead of being looked at', () {
      for (final basemap in kBasemaps) {
        expect(basemap.offlineDownload, OfflineDownload.forbidden);
      }
    });

    // Otherwise changing the style would move the camera.
    test('the camera may zoom equally far on every style', () {
      expect(kBasemaps.map(maxZoomOf).toSet(), {kBasemapMaxZoom});
    });

    test('OpenStreetMap is the default', () {
      expect(kDefaultBasemap, same(osmStandardBasemap));
    });

    test('an id this build cannot name falls back to the default', () {
      expect(basemapById(null), same(kDefaultBasemap));
      expect(basemapById('from-a-newer-version'), same(kDefaultBasemap));
      expect(basemapById('cyclosm'), same(cyclOsmBasemap));
    });
  });

  group('basemapTileLayers', () {
    test('a plain style is one layer, limited to its native zoom', () {
      final layers = basemapTileLayers(openTopoMapBasemap, '1.0.0');
      expect(layers, hasLength(1));
      expect(layers.single.maxNativeZoom, 17);
      expect(layers.single.maxZoom, kBasemapMaxZoom);
    });

    test('an overlay is drawn above the ground, with its own limit', () {
      final layers = basemapTileLayers(openSnowMapBasemap, '1.0.0');
      expect(layers, hasLength(2));
      expect(layers.first.urlTemplate, openTopoMapBasemap.urlTemplate);
      expect(layers.first.maxNativeZoom, 17);
      expect(layers.last.urlTemplate, contains('opensnowmap.org/pistes'));
      expect(layers.last.maxNativeZoom, 18);
    });

    test('layers of different styles do not share a key', () {
      final keys = {
        for (final basemap in kBasemaps)
          for (final layer in basemapTileLayers(basemap, '1.0.0')) layer.key,
      };
      final count = rasters.fold<int>(0, (n, b) => n + 1 + b.overlays.length);
      expect(keys, hasLength(count));
    });
  });

  group('the remembered choice', () {
    Future<(ProviderContainer, SharedPreferences)> open(
      Map<String, Object> stored,
    ) async {
      SharedPreferences.setMockInitialValues(stored);
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      return (container, prefs);
    }

    test('starts on the default', () async {
      final (container, _) = await open({});
      expect(container.read(basemapProvider), same(kDefaultBasemap));
    });

    test('is read back from the preferences', () async {
      final (container, _) = await open({'map_basemap': 'opensnowmap'});
      expect(container.read(basemapProvider), same(openSnowMapBasemap));
    });

    test('a stored style that no longer exists is the default', () async {
      final (container, _) = await open({'map_basemap': 'gone'});
      expect(container.read(basemapProvider), same(kDefaultBasemap));
    });

    test('is stored by id when set', () async {
      final (container, prefs) = await open({});
      await container.read(basemapProvider.notifier).set(humanitarianBasemap);
      expect(container.read(basemapProvider), same(humanitarianBasemap));
      expect(prefs.getString('map_basemap'), 'hot');
    });
  });

  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget app(Widget body) => ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: body),
    ),
  );

  testWidgets('the sheet lists every style and stores the one tapped', (
    tester,
  ) async {
    await tester.pumpWidget(app(const Center(child: MapStyleButton())));

    await tester.tap(find.byIcon(Icons.layers_outlined));
    await tester.pumpAndSettle();
    for (final basemap in kBasemaps) {
      expect(find.text(basemap.name), findsOneWidget);
    }

    await tester.tap(find.text('OpenTopoMap'));
    await tester.pumpAndSettle();

    expect(find.text('CyclOSM'), findsNothing);
    expect(prefs.getString('map_basemap'), 'opentopomap');
  });

  testWidgets('the attribution bar prints each label as it stands', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(const MapAttributionBar(basemap: openSnowMapBasemap)),
    );

    expect(find.text('© OpenStreetMap'), findsOneWidget);
    // Credited, not claimed.
    expect(find.text('SRTM'), findsOneWidget);
    expect(find.text('© OpenTopoMap (CC-BY-SA)'), findsOneWidget);
    expect(find.text('© opensnowmap.org (CC-BY-SA)'), findsOneWidget);
  });
}
