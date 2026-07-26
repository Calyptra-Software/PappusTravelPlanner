import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';

/// The reusable transport modes in display order — the built-ins plus any the
/// user added. Feeds the item form's mode dropdown and the settings list.
final transportModesProvider =
    StreamProvider.autoDispose<List<TransportModeRow>>((ref) {
      return ref.watch(repositoryProvider).watchTransportModes();
    });

/// The same modes keyed by id, so a leg (which stores its mode as a row id) can
/// resolve the icon and label to show. Empty until the modes stream first
/// resolves.
final transportModesByIdProvider =
    Provider.autoDispose<Map<int, TransportModeRow>>((ref) {
      final modes = ref.watch(transportModesProvider).value ?? const [];
      return {for (final m in modes) m.id: m};
    });

final transportModeControllerProvider = Provider<TransportModeController>(
  (ref) => TransportModeController(ref),
);

/// Add/rename/re-icon/reorder/delete for the transport modes managed in
/// settings — the transport counterpart to the reason management on
/// `CostController`.
class TransportModeController {
  TransportModeController(this._ref);
  final Ref _ref;

  Future<int> addMode(String name, {int? iconId}) =>
      _ref.read(repositoryProvider).addTransportMode(name, iconId: iconId);

  Future<void> renameMode(int id, String name) =>
      _ref.read(repositoryProvider).renameTransportMode(id, name);

  Future<void> setModeIcon(int id, int? iconId) =>
      _ref.read(repositoryProvider).setTransportModeIcon(id, iconId);

  Future<void> deleteMode(int id) =>
      _ref.read(repositoryProvider).deleteTransportMode(id);

  Future<void> reorderModes(List<int> orderedIds) =>
      _ref.read(repositoryProvider).reorderTransportModes(orderedIds);

  /// Re-adds a built-in the user deleted, restoring its identity (and the
  /// connection-search mapping) rather than creating a same-named custom mode.
  Future<void> restoreBuiltinMode(TransportMode mode) =>
      _ref.read(repositoryProvider).restoreBuiltinTransportMode(mode);
}
