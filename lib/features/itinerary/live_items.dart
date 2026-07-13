import '../../data/database/app_database.dart';

/// The plan as it currently stands, as opposed to everything that was ever
/// considered. Split out as pure functions (like `trip_stats.dart`) so the rule
/// can be unit-tested without a database, and so the one definition of "live" is
/// shared by everything that must not see the roads not taken: the timeline's
/// day totals, the home-screen widget, and the trip's expense statistics.

/// An item is **live** when it sits directly on its day, or when it belongs to
/// the chosen branch of its decision. Items in the branches not chosen are part
/// of the plan's history, not of the plan.
bool isLiveItem(ItineraryItem item, Set<int> chosenBranchIds) =>
    item.alternativeId == null || chosenBranchIds.contains(item.alternativeId);

/// The subset of [items] that is live, in the order given.
List<ItineraryItem> liveItems(
  List<ItineraryItem> items,
  Set<int> chosenBranchIds,
) => [
  for (final item in items)
    if (isLiveItem(item, chosenBranchIds)) item,
];

/// The chosen branch of every decision in a trip, from the branches keyed by set
/// id that `TripRepository.watchAlternativeBranches` yields. A set always has
/// exactly one chosen branch (`AlternativeDao` guarantees it), so this is one id
/// per set.
Set<int> chosenBranchIds(Map<int, List<Alternative>> branchesBySet) => {
  for (final branches in branchesBySet.values)
    for (final branch in branches)
      if (branch.chosen) branch.id,
};
