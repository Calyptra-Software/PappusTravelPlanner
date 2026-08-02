import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/format/civil_date.dart';
import '../../../core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import '../trip_filter.dart';

/// How the overview is filtered and sorted, remembered across launches.
///
/// "Only my walks, newest first" is a way of reading the list, not one act on
/// it: re-picking it after every launch is the friction that makes a control go
/// unused — and then the tags that feed it stop being kept up too. So every
/// facet is persisted **except [TripQuery.text]**: a search *is* one act, which
/// is why the app bar's close button already throws it away.
///
/// Each field has its own key and a missing key falls back to that field's
/// default, so a build that learns a new facet reads an older install without a
/// migration. [TripStatus] and [TripSort] are stored **by index** (a bitmask and
/// a plain int) — like every other persisted enum here, values may only be
/// appended, never reordered. Anything a stored value cannot name in this build
/// is dropped rather than guessed at.
///
/// The tag and participant selections are row ids, which name rows in *this*
/// database. Point the app at another file (settings → open/import) and they may
/// name nothing, leaving the overview filtered to an empty list — recoverable,
/// since the filter button still carries its badge and the sheet its "clear
/// filters", but worth knowing.
final tripQueryProvider = NotifierProvider<TripQueryController, TripQuery>(
  TripQueryController.new,
);

class TripQueryController extends Notifier<TripQuery> {
  static const _statusesKey = 'trips_filter_statuses';
  static const _tagsKey = 'trips_filter_tag_ids';
  static const _participantsKey = 'trips_filter_participant_ids';
  static const _fromKey = 'trips_filter_from';
  static const _toKey = 'trips_filter_to';
  static const _sortKey = 'trips_sort';

  @override
  TripQuery build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return TripQuery(
      statuses: _statuses(prefs.getInt(_statusesKey)),
      participantIds: _ids(prefs.getStringList(_participantsKey)),
      tagIds: _ids(prefs.getStringList(_tagsKey)),
      from: _day(prefs.getString(_fromKey)),
      to: _day(prefs.getString(_toKey)),
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
  /// query's [TripQuery.text] rides along into the state but is not stored.
  Future<void> setQuery(TripQuery query) async {
    state = query;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_statusesKey, _mask(query.statuses));
    await prefs.setStringList(
      _participantsKey,
      _idStrings(query.participantIds),
    );
    await prefs.setStringList(_tagsKey, _idStrings(query.tagIds));
    await _setOrRemoveDay(prefs, _fromKey, query.from);
    await _setOrRemoveDay(prefs, _toKey, query.to);
    await prefs.setInt(_sortKey, query.sort.index);
  }

  Set<TripStatus> _statuses(int? mask) {
    if (mask == null) return const {};
    // A bit this build has no status for comes from a newer one; dropping it
    // widens the filter, which is the harmless direction — the alternative is a
    // list filtered by something nothing on screen can name or switch off.
    return {
      for (final status in TripStatus.values)
        if (mask & (1 << status.index) != 0) status,
    };
  }

  int _mask(Set<TripStatus> statuses) {
    var mask = 0;
    for (final status in statuses) {
      mask |= 1 << status.index;
    }
    return mask;
  }

  Set<int> _ids(List<String>? stored) {
    if (stored == null) return const {};
    return {for (final entry in stored) ?int.tryParse(entry)};
  }

  List<String> _idStrings(Set<int> ids) => [for (final id in ids) '$id'];

  DateTime? _day(String? stored) {
    if (stored == null) return null;
    final parsed = DateTime.tryParse(stored);
    return parsed == null ? null : normalizeDay(parsed);
  }

  TripSort _sort(int? index) {
    if (index == null || index < 0 || index >= TripSort.values.length) {
      return const TripQuery().sort;
    }
    return TripSort.values[index];
  }

  /// "Any date" is the absence of a bound, not a date standing in for one.
  Future<void> _setOrRemoveDay(
    SharedPreferences prefs,
    String key,
    DateTime? day,
  ) => day == null
      ? prefs.remove(key)
      : prefs.setString(key, normalizeDay(day).toIso8601String());
}
