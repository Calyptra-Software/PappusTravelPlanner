import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/locale_provider.dart'
    show sharedPreferencesProvider;

/// The three ways the overview can draw the same trips.
///
/// Stored **by index**, append-only like every other persisted enum here: a
/// value may be added at the end, never reordered, or an old install reads its
/// stored number as a different view.
enum TripView { list, calendar, map }

/// Which of them is showing, remembered across launches.
///
/// The list/calendar switch used to be a `bool` in the screen's `State`, which
/// sat oddly beside the rule the rest of the overview follows: *how the overview
/// is read* is a setting, and every facet of `TripQuery` is persisted for
/// exactly that reason. Landing on the list again after every launch is the same
/// friction that stops a filter being used.
///
/// It matters more with three views than with two, because one of them costs
/// something: the map fetches tiles, so being dropped onto it unasked spends
/// somebody's mobile data. Remembering the choice means that only ever happens
/// to someone who chose it.
final tripViewProvider = NotifierProvider<TripViewController, TripView>(
  TripViewController.new,
);

class TripViewController extends Notifier<TripView> {
  static const _key = 'trips_view';

  @override
  TripView build() {
    final stored = ref.read(sharedPreferencesProvider).getInt(_key);
    // Anything this build cannot name — a view from a newer version — falls
    // back to the list rather than being guessed at.
    if (stored == null || stored < 0 || stored >= TripView.values.length) {
      return TripView.list;
    }
    return TripView.values[stored];
  }

  Future<void> set(TripView view) async {
    if (view == state) return;
    state = view;
    await ref.read(sharedPreferencesProvider).setInt(_key, view.index);
  }
}
