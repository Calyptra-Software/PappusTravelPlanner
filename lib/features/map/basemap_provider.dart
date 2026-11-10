import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import 'basemap.dart';

/// The style every map is drawn in, remembered across launches.
///
/// One answer for the whole app, like the theme: it says how this person likes
/// their maps, and belongs to the device rather than to a trip, so it stays out
/// of the database and out of a `.tpt`. Stored by [Basemap.id].
final basemapProvider = NotifierProvider<BasemapController, Basemap>(
  BasemapController.new,
);

class BasemapController extends Notifier<Basemap> {
  static const _key = 'map_basemap';

  @override
  Basemap build() =>
      basemapById(ref.read(sharedPreferencesProvider).getString(_key));

  Future<void> set(Basemap basemap) async {
    if (basemap == state) return;
    state = basemap;
    await ref.read(sharedPreferencesProvider).setString(_key, basemap.id);
  }
}

/// The overlays drawn on every map, in drawing order, remembered like the style.
final mapOverlaysProvider =
    NotifierProvider<MapOverlaysController, List<MapOverlay>>(
      MapOverlaysController.new,
    );

class MapOverlaysController extends Notifier<List<MapOverlay>> {
  static const _key = 'map_overlays';

  @override
  List<MapOverlay> build() => mapOverlaysByIds(
    ref.read(sharedPreferencesProvider).getStringList(_key) ?? const [],
  );

  Future<void> set(MapOverlay overlay, {required bool on}) async {
    final ids = {for (final current in state) current.id};
    on ? ids.add(overlay.id) : ids.remove(overlay.id);
    state = mapOverlaysByIds(ids);
    await ref.read(sharedPreferencesProvider).setStringList(_key, [
      for (final current in state) current.id,
    ]);
  }
}
