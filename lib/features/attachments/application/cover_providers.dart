import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../../itinerary/live_items.dart';
import '../../trips/application/trip_providers.dart';
import 'attachment_providers.dart';
import '../trip_gallery.dart';

/// The thumbnail every trip's overview card shows, keyed by trip id.
///
/// **One query for the whole list**, the rule `watchPositionedItems` and
/// `watchAllTracks` already follow: a family keyed by trip would open a query
/// per card, and the overview draws as many cards as the user has trips.
///
/// In two steps, because the thumbnail is a blob. The first asks only where
/// each photograph sits — no bytes — and picks one per trip through
/// `coverPhoto`, which is the trip's own answer where it has given one and the
/// first in gallery order where it has not. The second fetches the thumbnails
/// of exactly those, a handful of rows. Fetching every thumbnail to choose a
/// dozen would push megabytes through the stream on every tick.
///
/// The live rule is not applied here, and that is a stated cost: doing it
/// properly would mean holding every trip's entries, which is a second
/// all-trips query for a picture the size of a fingernail. A photograph
/// attached to an option nobody chose can therefore reach a card, where it
/// would reach no export and no map. If that turns out to matter, the fix is to
/// read `watchPositionedItems`' sibling rather than to loosen the rule
/// elsewhere.
final tripCoversProvider = StreamProvider.autoDispose<Map<int, Uint8List>>((
  ref,
) async* {
  final repo = ref.watch(repositoryProvider);
  final trips = ref.watch(tripListProvider).value;
  if (trips == null || trips.isEmpty) {
    yield const {};
    return;
  }
  final byId = {for (final trip in trips) trip.id: trip};

  await for (final candidates in repo.watchCoverCandidates()) {
    final byTrip = <int, List<GalleryPhoto>>{};
    for (final candidate in candidates) {
      if (!byId.containsKey(candidate.tripId)) continue;
      byTrip
          .putIfAbsent(candidate.tripId, () => [])
          .add(GalleryPhoto(attachment: candidate.attachment));
    }

    final chosen = <int, int>{};
    for (final entry in byTrip.entries) {
      final photo = coverPhoto(byId[entry.key]!, entry.value);
      if (photo != null) chosen[entry.key] = photo.id;
    }

    final thumbnails = await repo.thumbnailsFor(chosen.values.toList());
    yield {
      for (final entry in chosen.entries)
        if (thumbnails[entry.value] != null)
          entry.key: thumbnails[entry.value]!,
    };
  }
});

/// Which of one trip's photographs is its cover *right now* — the named one,
/// the derived one, or none.
///
/// Resolved in one place because two screens have to agree about it: the star
/// marks the picture the overview card shows, and that includes the picture the
/// app derived. A star that appeared only for a *named* cover would leave the
/// commonest case — a card showing a photograph with no star anywhere — looking
/// like the app had picked one behind the user's back.
///
/// Per trip, unlike [tripCoversProvider], and that is the right shape here: this
/// is read by the trip's own screen and by a gallery opened from it, never by a
/// list of every trip at once.
final tripCoverIdProvider = Provider.autoDispose.family<int?, int>((
  ref,
  tripId,
) {
  final trip = ref.watch(tripProvider(tripId)).value;
  if (trip == null) return null;
  final photos = ref.watch(tripPhotosProvider(tripId)).value ?? const [];
  final items = ref.watch(itineraryProvider(tripId)).value ?? const [];
  final chosen = ref.watch(chosenBranchIdsProvider(tripId));
  final groups = ref.watch(groupsProvider(tripId)).value ?? const {};
  final gallery = tripGallery(
    liveItems(items, chosen),
    photos: photos,
    groupLabels: {
      for (final entry in groups.entries)
        if ((entry.value.label ?? '').isNotEmpty) entry.key: entry.value.label!,
    },
  );
  return coverPhoto(trip, gallery)?.id;
});
