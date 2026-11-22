import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import '../domain/pace.dart';

/// The pace last set for each way of travel, by `paceKeyOf`: what a new tour
/// starts with, so nobody sets how fast they walk every time. A setting of the
/// device like the planner's servers, so it stays out of the database; a tour
/// keeps the paces it was saved with in its plans. Stored as the factor.
final rememberedPacesProvider =
    NotifierProvider<RememberedPaces, Map<String, Pace>>(RememberedPaces.new);

class RememberedPaces extends Notifier<Map<String, Pace>> {
  static const _prefix = 'route_pace_';

  @override
  Map<String, Pace> build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return {
      for (final key in prefs.getKeys())
        if (key.startsWith(_prefix))
          key.substring(_prefix.length): ?_read(prefs.getString(key)),
    };
  }

  /// Remembers [pace] for the way of travel [key]; the average one is
  /// forgotten rather than stored, being what an unset one is.
  Future<void> remember(String key, Pace pace) async {
    state = {...state, key: pace};
    final prefs = ref.read(sharedPreferencesProvider);
    if (pace == Pace.average) {
      await prefs.remove('$_prefix$key');
    } else {
      await prefs.setString('$_prefix$key', '${pace.factor}');
    }
  }

  static Pace? _read(String? stored) {
    final factor = stored == null ? null : double.tryParse(stored);
    return factor == null ? null : Pace.of(factor);
  }
}
