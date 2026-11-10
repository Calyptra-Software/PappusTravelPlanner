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
  group('the list of styles', () {
    test('ids are unique, because the choice is stored by id', () {
      expect(kBasemaps.map((b) => b.id).toSet(), hasLength(kBasemaps.length));
    });

    test('every tile URL is https and addresses a tile', () {
      final urls = [
        for (final basemap in kBasemaps.cast<RasterBasemap>())
          basemap.urlTemplate,
        for (final overlay in kMapOverlays) overlay.urlTemplate,
      ];
      for (final url in urls) {
        expect(url, startsWith('https://'));
        expect(url, allOf(contains('{z}'), contains('{x}'), contains('{y}')));
      }
    });

    // A condition of use on every one of these servers.
    test('every source credits OpenStreetMap, with a link', () {
      final sources = [
        ...kBasemaps.map((b) => (b.id, b.attributions)),
        ...kMapOverlays.map((o) => (o.id, o.attributions)),
      ];
      for (final (id, attributions) in sources) {
        expect(
          attributions.map((a) => a.url),
          contains(kOsmCopyrightUrl),
          reason: id,
        );
        for (final attribution in attributions) {
          expect(attribution.url, startsWith('https://'));
        }
      }
    });

    test('nothing may be downloaded ahead of being looked at', () {
      for (final basemap in kBasemaps) {
        expect(basemap.offlineDownload, OfflineDownload.forbidden);
      }
      for (final overlay in kMapOverlays) {
        expect(overlay.offlineDownload, OfflineDownload.forbidden);
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

  group('overlays', () {
    test('ids are unique', () {
      expect(
        kMapOverlays.map((o) => o.id).toSet(),
        hasLength(kMapOverlays.length),
      );
    });

    test('by id, in drawing order, without the ones this build lacks', () {
      expect(mapOverlaysByIds(['seamarks', 'railways', 'gone', 'ski-slopes']), [
        skiSlopesOverlay,
        railwaysOverlay,
        seamarksOverlay,
      ]);
    });

    test('a source shared with the ground is credited once', () {
      final attributions = combinedAttributions(
        humanitarianBasemap,
        kMapOverlays,
      );
      expect(
        attributions.where((a) => a.url == kOsmCopyrightUrl),
        hasLength(1),
      );
      expect(
        attributions.map((a) => a.url),
        contains('https://www.opensnowmap.org/'),
      );
      expect(
        attributions.map((a) => a.url),
        contains('https://map.openseamap.org/'),
      );
      expect(
        attributions.map((a) => a.url),
        contains('https://www.openrailwaymap.org/'),
      );
    });
  });

  group('basemapTileLayers', () {
    test('a style alone is one layer, limited to its native zoom', () {
      final layers = basemapTileLayers(openTopoMapBasemap, const [], '1.0.0');
      expect(layers, hasLength(1));
      expect(layers.single.maxNativeZoom, 17);
      expect(layers.single.maxZoom, kBasemapMaxZoom);
    });

    test('overlays go above any style, with their own limits', () {
      final layers = basemapTileLayers(osmStandardBasemap, const [
        skiSlopesOverlay,
        railwaysOverlay,
      ], '1.0.0');
      expect(layers, hasLength(3));
      expect(layers.first.urlTemplate, osmStandardBasemap.urlTemplate);
      expect(layers[1].urlTemplate, contains('opensnowmap.org/pistes'));
      expect(layers[1].minZoom, skiSlopesOverlay.minZoom);
      expect(layers[1].maxNativeZoom, 18);
      expect(layers[2].urlTemplate, contains('openrailwaymap.org'));
      expect(layers[2].maxZoom, kBasemapMaxZoom);
    });

    test('no two sources share a key', () {
      final keys = {
        for (final basemap in kBasemaps)
          for (final layer in basemapTileLayers(basemap, kMapOverlays, '1.0.0'))
            layer.key,
      };
      expect(keys, hasLength(kBasemaps.length + kMapOverlays.length));
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
      final (container, _) = await open({'map_basemap': 'cyclosm'});
      expect(container.read(basemapProvider), same(cyclOsmBasemap));
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

    test('overlays start off', () async {
      final (container, _) = await open({});
      expect(container.read(mapOverlaysProvider), isEmpty);
    });

    test('overlays are read back, unknown ones dropped', () async {
      final (container, _) = await open({
        'map_overlays': ['gone', 'railways'],
      });
      expect(container.read(mapOverlaysProvider), [railwaysOverlay]);
    });

    test('an overlay is switched on and off and stored', () async {
      final (container, prefs) = await open({});
      final overlays = container.read(mapOverlaysProvider.notifier);

      await overlays.set(railwaysOverlay, on: true);
      await overlays.set(skiSlopesOverlay, on: true);
      expect(container.read(mapOverlaysProvider), [
        skiSlopesOverlay,
        railwaysOverlay,
      ]);
      expect(prefs.getStringList('map_overlays'), ['ski-slopes', 'railways']);

      await overlays.set(skiSlopesOverlay, on: false);
      expect(container.read(mapOverlaysProvider), [railwaysOverlay]);
      expect(prefs.getStringList('map_overlays'), ['railways']);
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

  testWidgets('the sheet stores a style and overlays, and stays open', (
    tester,
  ) async {
    await tester.pumpWidget(app(const Center(child: MapStyleButton())));

    await tester.tap(find.byIcon(Icons.layers_outlined));
    await tester.pumpAndSettle();
    for (final basemap in kBasemaps) {
      expect(find.text(basemap.name), findsOneWidget);
    }
    for (final overlay in kMapOverlays) {
      expect(find.text(overlay.source), findsOneWidget);
    }

    await tester.tap(find.text('OpenTopoMap'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenRailwayMap'));
    await tester.pumpAndSettle();

    expect(find.text('CyclOSM'), findsOneWidget);
    expect(prefs.getString('map_basemap'), 'opentopomap');
    expect(prefs.getStringList('map_overlays'), ['railways']);
  });

  testWidgets('the button says when an overlay is on', (tester) async {
    Color? foreground() =>
        tester.widget<MapRoundButton>(find.byType(MapRoundButton)).foreground;

    await tester.pumpWidget(app(const Center(child: MapStyleButton())));
    expect(foreground(), isNull);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapStyleButton)),
    );
    await container
        .read(mapOverlaysProvider.notifier)
        .set(skiSlopesOverlay, on: true);
    await tester.pump();
    expect(foreground(), isNotNull);
  });

  testWidgets('the attribution bar prints each label as it stands', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const MapAttributionBar(
          basemap: openTopoMapBasemap,
          overlays: [skiSlopesOverlay],
        ),
      ),
    );

    expect(find.text('© OpenStreetMap'), findsOneWidget);
    // Credited, not claimed.
    expect(find.text('SRTM'), findsOneWidget);
    expect(find.text('© OpenTopoMap (CC-BY-SA)'), findsOneWidget);
    expect(find.text('© opensnowmap.org (CC-BY-SA)'), findsOneWidget);
  });
}
