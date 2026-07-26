import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import '../domain/transit_filter.dart';

/// The kinds of transport the user last searched with, remembered across
/// launches: "no flights" or "trains only" is a trait of how someone travels,
/// not of one search, and re-ticking it every time is the friction that makes a
/// filter go unused.
///
/// Stored as a **bitmask** of [TransitFilter] indices, so — like every other
/// persisted enum here — values may only be appended to the enum, never
/// reordered. Mirrors `PdfSectionsController`.
final transitFilterProvider =
    NotifierProvider<TransitFilterController, Set<TransitFilter>>(
      TransitFilterController.new,
    );

class TransitFilterController extends Notifier<Set<TransitFilter>> {
  static const _key = 'connection_transit_modes';

  @override
  Set<TransitFilter> build() {
    final mask = ref.read(sharedPreferencesProvider).getInt(_key);
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

  Future<void> setFilters(Set<TransitFilter> filters) async {
    var mask = 0;
    for (final filter in filters) {
      mask |= 1 << filter.index;
    }
    await ref.read(sharedPreferencesProvider).setInt(_key, mask);
    state = {...filters};
  }
}
