import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the entry being carried is on its way somewhere else, or about to be
/// duplicated there.
enum HoldMode { move, copy }

/// An itinerary entry that has been picked up and is waiting to be put down.
///
/// Dragging can only reorder *within* one list — the day's blocks, or one
/// option's items — because that is the only thing a `ReorderableListView` can
/// express. Crossing a boundary (to another day, into an option, back out of
/// one) is instead a two-step act: pick the entry up here, put it down there.
/// The destination names itself by being the place you navigated to, which a
/// picker listing every day × every option never could.
class HeldItem {
  const HeldItem({
    required this.tripId,
    required this.itemId,
    required this.mode,
  });

  /// The trip the entry came from. Putting it down elsewhere is offered only
  /// within that trip: an entry carries costs, a group and beneficiaries that
  /// all hang off its trip, so crossing trips is a bigger move than this one.
  final int tripId;
  final int itemId;
  final HoldMode mode;
}

/// The entry currently held, or null when hands are empty.
///
/// Nothing is persisted: coming back to the app tomorrow to find a half-finished
/// move waiting would be a puzzle, not a convenience. `autoDispose` is what
/// enforces that — the trip screen watches this, so leaving the trip drops the
/// last listener and the hold with it, and there is never an invisible pending
/// move in a place that offers nowhere to put it down.
class ItemClipboard extends Notifier<HeldItem?> {
  @override
  HeldItem? build() => null;

  void hold(HeldItem item) => state = item;

  void clear() => state = null;
}

final itemClipboardProvider =
    NotifierProvider.autoDispose<ItemClipboard, HeldItem?>(ItemClipboard.new);
