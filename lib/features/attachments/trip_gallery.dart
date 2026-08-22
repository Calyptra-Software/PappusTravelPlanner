/// Which photographs a trip has, in the order they belong in.
///
/// Pure (like `map_features.dart`, which this is the sibling of), so the two
/// rules below are testable without a widget tree — and so the gallery reads the
/// plan through the same definition of "live" the map, the PDF and the calendar
/// export use, rather than a fourth one of its own.
library;

import '../../data/database/app_database.dart';

/// One page of the gallery: the picture, and what it is of.
///
/// The label is the whole reason this type exists rather than a bare list of
/// rows. A single photograph, opened from the entry it hangs on, needs no
/// caption — you were already looking at that entry. Twenty of them in a row do:
/// without one they are a pile of pictures with a trip somewhere behind them.
final class GalleryPhoto {
  const GalleryPhoto({required this.attachment, this.label});

  final Attachment attachment;

  /// The entry or run the picture hangs on, as it reads in the timeline, or
  /// null for one that belongs to the trip itself — which needs no label,
  /// since "this trip" is what the screen is already about.
  final String? label;
}

/// The trip's photographs, in the order a gallery should walk them.
///
/// [items] are the trip's **live** entries in timeline order — the same list the
/// map is handed, applied here for the same reason: a picture attached to an
/// option nobody chose is no more part of the trip than the option is, and it
/// leaves in no export either.
///
/// [photos] are the trip's pictures as the database holds them, unfiltered.
/// [groupLabels] names each run, so a shared ticket's photograph can say which
/// journey it is of.
///
/// The trip's own come **first**, then everything else in plan order: the
/// insurance and the printed map are about the journey rather than about a day
/// of it, which is the order the PDF already prints in.
List<GalleryPhoto> tripGallery(
  List<ItineraryItem> items, {
  required List<Attachment> photos,
  Map<int, String> groupLabels = const {},
}) {
  if (photos.isEmpty) return const [];

  final byItem = <int, List<Attachment>>{};
  final byGroup = <int, List<Attachment>>{};
  final onTrip = <Attachment>[];
  for (final photo in photos) {
    if (photo.itemId case final id?) {
      byItem.putIfAbsent(id, () => []).add(photo);
    } else if (photo.groupId case final id?) {
      byGroup.putIfAbsent(id, () => []).add(photo);
    } else {
      onTrip.add(photo);
    }
  }

  final gallery = [for (final photo in onTrip) GalleryPhoto(attachment: photo)];

  // Walked in the order the timeline reads, so the gallery runs through the
  // trip rather than through whatever order the rows came back in. A run's own
  // photographs sit at its first member, which is where the run begins.
  final seenGroups = <int>{};
  for (final item in items) {
    if (item.groupId case final groupId?) {
      if (seenGroups.add(groupId)) {
        for (final photo in byGroup[groupId] ?? const <Attachment>[]) {
          gallery.add(
            GalleryPhoto(attachment: photo, label: groupLabels[groupId]),
          );
        }
      }
    }
    for (final photo in byItem[item.id] ?? const <Attachment>[]) {
      gallery.add(GalleryPhoto(attachment: photo, label: itemLabel(item)));
    }
  }
  return gallery;
}

/// What an entry is called, for a caption. The title it was given, else where
/// it goes — a leg reads "Hamburg → Berlin", which is what names it when nobody
/// typed anything.
String? itemLabel(ItineraryItem item) {
  final title = item.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  final place = item.location?.trim();
  if (place != null && place.isNotEmpty) return place;
  final from = item.fromLocation?.trim();
  final to = item.toLocation?.trim();
  if ((from ?? '').isEmpty && (to ?? '').isEmpty) return null;
  return '${from ?? '?'} → ${to ?? '?'}';
}
