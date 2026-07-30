import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../../itinerary/application/transport_mode_providers.dart';
import '../data/journey_view_items.dart';
import 'journey_sheet.dart';

/// Reads a journey the trip already holds — the sheet the connection was
/// imported through, opened again on what the import wrote.
///
/// Its unit is the **group**: importing a connection bundles each day's run of
/// legs into one (they share a ticket), so a group already *is* a journey, and
/// asking for one by [groupId] asks for exactly the run that was added. A leg
/// standing on its own is asked for by [itemId] instead. Nothing else is a
/// journey: a decision's option is a plan, and a day is a day.
///
/// It watches the trip's items rather than taking a snapshot, so a leg refreshed
/// from inside the sheet redraws in place — the refresh writes to the database
/// and the sheet is reading it.
Future<void> showJourneyDetailsSheet(
  BuildContext context, {
  required int tripId,
  int? groupId,
  int? itemId,
  String? title,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => JourneyDetailsSheet(
    tripId: tripId,
    groupId: groupId,
    itemId: itemId,
    title: title,
  ),
);

class JourneyDetailsSheet extends ConsumerWidget {
  const JourneyDetailsSheet({
    super.key,
    required this.tripId,
    this.groupId,
    this.itemId,
    this.title,
  });

  final int tripId;
  final int? groupId;
  final int? itemId;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itineraryProvider(tripId)).value ?? const [];
    final modesById = ref.watch(transportModesByIdProvider);
    final journey = [
      for (final item in items)
        if (groupId != null ? item.groupId == groupId : item.id == itemId) item,
    ];
    return JourneySheet(
      view: journeyViewFromItems(journey, modesById),
      title: title,
      modesById: modesById,
      itemsById: {for (final item in journey) item.id: item},
    );
  }
}

/// Whether [item] has a journey worth reading on its own — i.e. whether the
/// timeline should offer the sheet on the tile rather than only on its group.
///
/// A grouped leg is covered by its group's own button, and a hand-entered leg
/// has nothing the tile does not already show. What is left is a leg the
/// **search** put there, which is asked in the same terms the refresh button
/// asks it (`sourceTripId`) rather than by whether stops came back: a service
/// the feed lists no intermediate stops for is still an imported journey, with
/// its platforms, its direction and its delays to read — and a run of them that
/// is later ungrouped must not leave some legs with a way in and others without.
bool hasStandaloneJourney(ItineraryItem item) =>
    item.groupId == null &&
    item.kind == ItemKind.transport &&
    (item.sourceTripId != null ||
        (item.stopovers != null && item.stopovers!.isNotEmpty));

/// Whether the group [groupId] reads as a journey: it has to be got somewhere by
/// something. A group of places — several museums on one ticket — is a bundle of
/// entries, not a journey, and is offered nothing.
bool groupHasJourney(Iterable<ItineraryItem> members, int groupId) => members
    .any((item) => item.groupId == groupId && item.kind == ItemKind.transport);
