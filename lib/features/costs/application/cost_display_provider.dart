import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/locale_provider.dart' show sharedPreferencesProvider;

/// How a cost reason is shown on cost chips. The amount is always shown; this
/// only governs the reason portion. Stored by index in SharedPreferences, so
/// only append new values at the end.
enum CostReasonDisplay { icon, text, both }

/// The user's chosen cost-reason display mode, persisted across launches.
/// Mirrors [LocaleController] in `core/settings/locale_provider.dart`.
final costReasonDisplayProvider =
    NotifierProvider<CostReasonDisplayController, CostReasonDisplay>(
        CostReasonDisplayController.new);

class CostReasonDisplayController extends Notifier<CostReasonDisplay> {
  static const _key = 'cost_reason_display';

  @override
  CostReasonDisplay build() {
    final index = ref.read(sharedPreferencesProvider).getInt(_key);
    if (index == null || index < 0 || index >= CostReasonDisplay.values.length) {
      return CostReasonDisplay.both;
    }
    return CostReasonDisplay.values[index];
  }

  Future<void> setDisplay(CostReasonDisplay display) async {
    await ref.read(sharedPreferencesProvider).setInt(_key, display.index);
    state = display;
  }
}
