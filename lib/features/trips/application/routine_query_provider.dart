import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import '../routine_filter.dart';

/// How the routine list is filtered and sorted, remembered across launches.
///
/// The same rule the overview follows (`tripQueryProvider`): *how a list is
/// read* is a setting, *what is being looked for* is one act — so every facet is
/// persisted **except [RoutineQuery.text]**, which the app bar's close button
/// throws away. Stored under its own keys, so filtering the routines never
/// moves the overview and the other way round: they are two lists asked two
/// questions.
///
/// Each field has its own key and a missing key falls back to that field's
/// default, so a build that learns a new facet reads an older install without a
/// migration. [RoutineSort] is stored **by index** — append-only, like every
/// other persisted enum here — and an index this build cannot name falls back
/// to the default rather than being guessed at. The tag and participant ids
/// name rows in *this* database; point the app at another file and they may
/// name nothing, which the filter badge and "clear" are the way back out of.
final routineQueryProvider =
    NotifierProvider<RoutineQueryController, RoutineQuery>(
      RoutineQueryController.new,
    );

class RoutineQueryController extends Notifier<RoutineQuery> {
  static const _tagsKey = 'routines_filter_tag_ids';
  static const _participantsKey = 'routines_filter_participant_ids';
  static const _sortKey = 'routines_sort';

  @override
  RoutineQuery build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return RoutineQuery(
      tagIds: _ids(prefs.getStringList(_tagsKey)),
      participantIds: _ids(prefs.getStringList(_participantsKey)),
      sort: _sort(prefs.getInt(_sortKey)),
    );
  }

  /// Sets the search text, which is deliberately **not** persisted — and so is
  /// also the one control that writes nothing on a keystroke.
  void setText(String text) {
    if (text == state.text) return;
    state = state.copyWith(text: text);
  }

  /// Replaces the filters and sort, remembering them for the next launch. The
  /// query's [RoutineQuery.text] rides along into the state but is not stored.
  Future<void> setQuery(RoutineQuery query) async {
    state = query;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(_tagsKey, _idStrings(query.tagIds));
    await prefs.setStringList(
      _participantsKey,
      _idStrings(query.participantIds),
    );
    await prefs.setInt(_sortKey, query.sort.index);
  }

  Set<int> _ids(List<String>? stored) {
    if (stored == null) return const {};
    return {for (final entry in stored) ?int.tryParse(entry)};
  }

  List<String> _idStrings(Set<int> ids) => [for (final id in ids) '$id'];

  RoutineSort _sort(int? index) {
    if (index == null || index < 0 || index >= RoutineSort.values.length) {
      return const RoutineQuery().sort;
    }
    return RoutineSort.values[index];
  }
}
