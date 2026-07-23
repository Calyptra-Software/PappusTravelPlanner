import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';

/// Whether the thing being carried is on its way somewhere else, or about to be
/// duplicated there.
enum HoldMode { move, copy }

/// Something picked up and waiting to be put down elsewhere.
///
/// Dragging can only reorder *within* one list — the day's blocks, or one
/// option's items — because that is the only thing a `ReorderableListView` can
/// express. Crossing a boundary (to another day, into an option, back out of
/// one) is instead a two-step act: pick the thing up here, put it down there.
/// The destination names itself by being the place you navigated to.
///
/// What can be carried is an [ItineraryItem] on its own ([HeldItem]) or a whole
/// group of them sharing one ticket ([HeldGroup]); both land at the end of the
/// day or option they are put down on.
sealed class Held {
  const Held({required this.tripId, required this.mode});

  /// The trip the thing came from. Putting it down elsewhere is offered only
  /// within that trip: entries carry costs and participants that all hang off
  /// their trip, so crossing trips is a bigger move than this one.
  final int tripId;
  final HoldMode mode;
}

/// A single itinerary entry, held.
class HeldItem extends Held {
  const HeldItem({
    required super.tripId,
    required this.itemId,
    required super.mode,
  });

  final int itemId;
}

/// A whole group (a shared-ticket run), held — every member travels together
/// and stays grouped.
class HeldGroup extends Held {
  const HeldGroup({
    required super.tripId,
    required this.groupId,
    required super.mode,
  });

  final int groupId;
}

/// Whether [item] is (part of) what is currently [held] — so the timeline can
/// dim it where it still sits. A held group dims every one of its members.
bool isHeldItem(Held? held, ItineraryItem item) => switch (held) {
  null => false,
  HeldItem(:final itemId) => item.id == itemId,
  HeldGroup(:final groupId) => item.groupId != null && item.groupId == groupId,
};

/// The thing currently held, or null when hands are empty.
///
/// Nothing is persisted: coming back to the app tomorrow to find a half-finished
/// move waiting would be a puzzle, not a convenience. `autoDispose` is what
/// enforces that — the trip screen watches this, so leaving the trip drops the
/// last listener and the hold with it, and there is never an invisible pending
/// move in a place that offers nowhere to put it down.
class ItemClipboard extends Notifier<Held?> {
  @override
  Held? build() => null;

  void hold(Held item) => state = item;

  void clear() => state = null;
}

final itemClipboardProvider =
    NotifierProvider.autoDispose<ItemClipboard, Held?>(ItemClipboard.new);
