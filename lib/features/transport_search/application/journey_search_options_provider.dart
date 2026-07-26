import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  static const _maxTransfersKey = 'connection_max_transfers';

  @override
  JourneySearchOptions build() {
    final prefs = ref.read(sharedPreferencesProvider);
    const defaults = JourneySearchOptions();
    return JourneySearchOptions(
      modes: _modes(prefs.getInt(_modesKey)),
      minTransferMinutes:
          prefs.getInt(_minTransferKey) ?? defaults.minTransferMinutes,
      walkingSpeedKmh: prefs.getDouble(_speedKey) ?? defaults.walkingSpeedKmh,
      maxTransfers: prefs.getInt(_maxTransfersKey),
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
    // "No limit" is the absence of a value, not a number standing in for one.
    final maxTransfers = options.maxTransfers;
    if (maxTransfers == null) {
      await prefs.remove(_maxTransfersKey);
    } else {
      await prefs.setInt(_maxTransfersKey, maxTransfers);
    }
    state = options;
  }
}
