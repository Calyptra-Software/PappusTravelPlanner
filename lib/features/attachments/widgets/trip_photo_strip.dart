import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../itinerary/application/itinerary_providers.dart';
import '../../itinerary/live_items.dart';
import '../application/attachment_providers.dart';
import '../cover_star.dart';
import '../presentation/gallery_screen.dart';
import '../trip_gallery.dart';

/// The trip's photographs, as a band of thumbnails that opens the gallery.
///
/// The way *in*, and the reason it is a strip rather than a menu entry: the
/// trip's app bar is already three icons and an overflow — its own comment says
/// a fourth leaves no room for the title — and the overflow is for what a trip
/// is *done to*, not for a way of looking at it. A strip costs no bar space, is
/// visibly there, and hands the gallery the picture that was tapped.
///
/// Absent when the trip has no photographs, which is most routines and many
/// trips: an empty band would be a permanent advertisement for a feature this
/// trip is not using.
///
/// **Collapsible**, and remembered, the way a checklist and a day already are.
/// A band of thumbnails is the heaviest thing on this screen, and a trip with
/// two hundred photographs should not have to be scrolled past every time
/// somebody opens it to read the plan. The state lives on the trip's own row
/// ([Trips.photosCollapsed]) rather than in preferences, because it is per-trip
/// state and that is where the other two keep theirs — it belongs to the file
/// the trip lives in.
///
/// Not to be confused with the rule against thumbnails *in the timeline*: there
/// a picture would displace the entry it hangs on, while here the trip's
/// photographs are the subject.
class TripPhotoStrip extends ConsumerWidget {
  const TripPhotoStrip({
    super.key,
    required this.tripId,
    this.collapsed = false,
    this.coverAttachmentId,
    this.coverHidden = false,
  });

  final int tripId;

  /// Which picture wears the mark, and whether the trip wants one at all —
  /// handed in with [collapsed], from the trip row the screen already holds.
  final int? coverAttachmentId;
  final bool coverHidden;

  /// Handed in rather than watched: the screen around this already holds the
  /// trip row, and a second stream for one boolean is a query nobody needs.
  final bool collapsed;

  static const double _height = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final photos = ref.watch(tripPhotosProvider(tripId)).value;
    if (photos == null || photos.isEmpty) return const SizedBox.shrink();

    // The same reading the map makes: live entries only, so a picture in an
    // option nobody chose is no more here than the option is.
    final items = ref.watch(itineraryProvider(tripId)).value ?? const [];
    final chosen = ref.watch(chosenBranchIdsProvider(tripId));
    final groups = ref.watch(groupsProvider(tripId)).value ?? const {};
    final gallery = tripGallery(
      liveItems(items, chosen),
      photos: photos,
      // Only the runs the user has named: one going by the default label has
      // nothing to add to a caption the picture does not already carry.
      groupLabels: {
        for (final entry in groups.entries)
          if ((entry.value.label ?? '').isNotEmpty)
            entry.key: entry.value.label!,
      },
    );
    if (gallery.isEmpty) return const SizedBox.shrink();

    final expanded = !collapsed;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => ref
                .read(repositoryProvider)
                .setTripPhotosCollapsed(tripId, expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    l10n.galleryTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Kept in the header rather than only above the strip: a
                  // collapsed section that said nothing about what is inside it
                  // would be a row with no reason to be tapped.
                  Text(
                    l10n.attachmentsCount(gallery.length),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  // The third state, and the only one that is about the trip
                  // rather than about a photograph: a trip whose pictures are
                  // all of receipts has photos and wants no cover, and deriving
                  // one anyway would be the app overruling that. The other two
                  // — derived, and a named one — are the star in the gallery.
                  PopupMenuButton<bool>(
                    tooltip: l10n.coverNone,
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (hide) => ref
                        .read(repositoryProvider)
                        .setTripCoverHidden(tripId, hide),
                    itemBuilder: (context) => [
                      CheckedPopupMenuItem(
                        value: !coverHidden,
                        checked: coverHidden,
                        child: Text(l10n.coverNone),
                      ),
                    ],
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            secondChild: const SizedBox(width: double.infinity),
            firstChild: SizedBox(
              height: _height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: gallery.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final thumbnail = gallery[index].attachment.thumbnail;
                  final isCover =
                      !coverHidden &&
                      gallery[index].attachment.id == coverAttachmentId;
                  return InkWell(
                    onTap: () => showGallery(
                      context,
                      photos: gallery,
                      initialIndex: index,
                      tripId: tripId,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: _height,
                      height: _height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: thumbnail == null
                                ? ColoredBox(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: Icon(
                                      Icons.image_outlined,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  )
                                : Image.memory(
                                    thumbnail,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  ),
                          ),
                          // The mark, and only on the one that carries it — not
                          // a control. A tappable star on every tile would need
                          // a 48dp target inside a 72dp thumbnail, taking half
                          // of it and stealing the taps that open the gallery;
                          // and nineteen empty stars would answer a question
                          // nobody asked. Choosing happens where the picture is
                          // big enough to judge.
                          if (isCover)
                            const Positioned(
                              right: 2,
                              bottom: 2,
                              child: _CoverMark(),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The star on the thumbnail that is the trip's cover.
///
/// Ink on a halo, the way the map's own marker is drawn: a photograph can be
/// any colour, so a bare glyph is legible over some of them and gone over the
/// rest.
class _CoverMark extends StatelessWidget {
  const _CoverMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Color(0x99000000),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.star, size: 14, color: kCoverStarColor),
    );
  }
}
