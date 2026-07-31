import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import '../domain/journey_options.dart';
import '../domain/transit_filter.dart';

/// How the user last searched, remembered across launches: "no flights", "never
/// a change under ten minutes", "I walk slowly" are traits of how someone
/// travels, not of one search, and re-setting them every time is the friction
/// that makes a control go unused.
///
/// Each field is stored under its own key, and a missing key falls back to that
/// field's default — so a build that learns a new setting reads an older
/// install without a migration. The modes are a **bitmask** of [TransitFilter]
/// indices, so — like every other persisted enum here — values may only be
/// appended to the enum, never reordered.
final journeySearchOptionsProvider =
    NotifierProvider<JourneySearchOptionsController, JourneySearchOptions>(
      JourneySearchOptionsController.new,
    );

class JourneySearchOptionsController extends Notifier<JourneySearchOptions> {
  static const _modesKey = 'connection_transit_modes';
  static const _minTransferKey = 'connection_min_transfer_minutes';
  static const _speedKey = 'connection_walking_speed_kmh';
  static const _wheelchairKey = 'connection_wheelchair';
  static const _maxTransfersKey = 'connection_max_transfers';
  static const _byBikeKey = 'connection_by_bike';
  static const _bikeOnBoardKey = 'connection_bike_on_board';
  static const _cyclingSpeedKey = 'connection_cycling_speed_kmh';
  static const _preTransitKey = 'connection_max_pre_transit_minutes';
  static const _postTransitKey = 'connection_max_post_transit_minutes';
  static const _directKey = 'connection_max_direct_minutes';

  @override
  JourneySearchOptions build() {
    final prefs = ref.read(sharedPreferencesProvider);
    const defaults = JourneySearchOptions();
    return JourneySearchOptions(
      modes: _modes(prefs.getInt(_modesKey)),
      minTransferMinutes:
          prefs.getInt(_minTransferKey) ?? defaults.minTransferMinutes,
      walkingSpeedKmh: prefs.getDouble(_speedKey) ?? defaults.walkingSpeedKmh,
      wheelchair: prefs.getBool(_wheelchairKey) ?? defaults.wheelchair,
      maxTransfers: prefs.getInt(_maxTransfersKey),
      byBike: prefs.getBool(_byBikeKey) ?? defaults.byBike,
      bikeOnBoard: prefs.getBool(_bikeOnBoardKey) ?? defaults.bikeOnBoard,
      cyclingSpeedKmh:
          prefs.getDouble(_cyclingSpeedKey) ?? defaults.cyclingSpeedKmh,
      // Absent means automatic here, which is also the default — so a missing
      // key needs no fallback of its own.
      maxPreTransitMinutes: prefs.getInt(_preTransitKey),
      maxPostTransitMinutes: prefs.getInt(_postTransitKey),
      maxDirectMinutes: prefs.getInt(_directKey),
    );
  }

  Set<TransitFilter> _modes(int? mask) {
    if (mask == null) return kAllTransitFilters;
    final stored = {
      for (final filter in TransitFilter.values)
        if (mask & (1 << filter.index) != 0) filter,
    };
    // An empty mask can only come from a build that knew categories this one
    // doesn't; searching with nothing allowed finds nothing, so fall back to
    // everything rather than to a screen that can only say "no connections".
    return stored.isEmpty ? kAllTransitFilters : stored;
  }

  Future<void> setOptions(JourneySearchOptions options) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_modesKey, options.modeMask);
    await prefs.setInt(_minTransferKey, options.minTransferMinutes);
    await prefs.setDouble(_speedKey, options.walkingSpeedKmh);
    await prefs.setBool(_wheelchairKey, options.wheelchair);
    await prefs.setBool(_byBikeKey, options.byBike);
    await prefs.setBool(_bikeOnBoardKey, options.bikeOnBoard);
    await prefs.setDouble(_cyclingSpeedKey, options.cyclingSpeedKmh);
    // "No limit" and "automatic" are the absence of a value, not numbers
    // standing in for one.
    await _setOrRemove(prefs, _maxTransfersKey, options.maxTransfers);
    await _setOrRemove(prefs, _preTransitKey, options.maxPreTransitMinutes);
    await _setOrRemove(prefs, _postTransitKey, options.maxPostTransitMinutes);
    await _setOrRemove(prefs, _directKey, options.maxDirectMinutes);
    state = options;
  }

  Future<void> _setOrRemove(SharedPreferences prefs, String key, int? value) =>
      value == null ? prefs.remove(key) : prefs.setInt(key, value);
}
