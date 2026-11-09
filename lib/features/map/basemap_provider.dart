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
