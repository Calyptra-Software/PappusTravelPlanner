import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../application/attachment_providers.dart';
import '../application/cover_providers.dart';
import '../cover_star.dart';
import '../trip_gallery.dart';
import 'attachment_sheet.dart';

/// Opens the gallery on [photos], starting at [initialIndex].
///
/// A **full-screen route**, pushed directly rather than named: what the gallery
/// shows is a *list*, decided by whoever opened it — the whole trip from the
/// strip on its screen, one entry's own from that entry's field — and a list is
/// not a thing to put in a URL. The same shape `pickPointOnMap` has, and for a
/// related reason: both are screens that answer with something rather than
/// places one navigates to.
///
/// [tripId] is the trip these photographs belong to, when the caller knows it —
/// which both callers do, the strip from its own screen and an entry's field
/// from the entry. It is what the cover star writes to; without it the star is
/// simply not offered, since there is no trip to be the cover *of*.
Future<void> showGallery(
  BuildContext context, {
  required List<GalleryPhoto> photos,
  int initialIndex = 0,
  int? tripId,
}) {
  if (photos.isEmpty) return Future.value();
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => GalleryScreen(
        photos: photos,
        initialIndex: initialIndex,
        tripId: tripId,
      ),
    ),
  );
}

/// The trip's photographs, one to a screen, swiped between.
///
/// Deliberately a **reading**. Swiping browses and never changes anything —
/// the rule an `AlternativeCard` already follows — and the four things that can
/// be done to a picture stay in `AttachmentSheet`, one tap away behind the ⋮.
/// Copying them here would mean two places holding the delete confirmation, and
/// one of them going stale.
///
/// Each page is decoded only as it comes into view, through the `autoDispose`
/// [attachmentBytesProvider]: a `PageView` builds lazily, so a gallery of two
/// hundred photographs holds three of them.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.tripId,
  });

  final List<GalleryPhoto> photos;
  final int initialIndex;

  /// The trip whose cover the star sets, or null when the opener did not say —
  /// in which case there is no star.
  final int? tripId;

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  /// Whether the picture on screen is zoomed in.
  ///
  /// Zooming and turning the page are the *same gesture* — a horizontal drag —
  /// so one of them has to give way: while a picture is magnified the drag pans
  /// it, and the page does not turn. Without this, moving a zoomed photograph
  /// sideways skips to the next one, which is the kind of thing that reads as
  /// the app fighting the finger.
  bool _zoomed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final photo = widget.photos[_index];
    final caption = photo.label ?? photo.attachment.name;

    return Scaffold(
      // Black, as every photo viewer is: a picture is judged against what
      // surrounds it, and a surface color would tint everything shown here.
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              // The entry it hangs on, which is what one of twenty pictures
              // cannot say for itself. A trip-level one has no label and falls
              // back to its file name.
              caption ?? l10n.attachmentsLabel,
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.photos.length > 1)
              Text(
                '${_index + 1} / ${widget.photos.length}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          // A cover is chosen against the picture, at the size it is actually
          // looked at — the argument that put `ItemColorField` on the map
          // rather than in a form. Here rather than on the thumbnails in the
          // strip, where a real 48dp target would cover half a 72dp tile and
          // steal the taps meant to open this screen.
          if (widget.tripId case final tripId?)
            _CoverStar(tripId: tripId, attachmentId: photo.attachment.id),
          IconButton(
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            icon: const Icon(Icons.more_vert),
            // Hands the acts to the sheet that already owns them, the way
            // `MapItemSheet` hands editing to the item form.
            onPressed: () => showAttachmentSheet(context, photo.attachment),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        physics: _zoomed
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        itemCount: widget.photos.length,
        onPageChanged: (index) => setState(() {
          _index = index;
          // A new page starts unzoomed, so the lock cannot survive the picture
          // it was about.
          _zoomed = false;
        }),
        itemBuilder: (context, index) => _GalleryPage(
          key: ValueKey(widget.photos[index].attachment.id),
          photo: widget.photos[index],
          onZoomChanged: (zoomed) {
            if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
          },
        ),
      ),
    );
  }
}

/// Amber when this picture is the one the overview card shows, an outline when
/// it is not.
///
/// **Filled for the derived cover too**, not only for a named one. That is what
/// makes the star honest: a card showing a photograph while no star exists
/// anywhere would look like the app had picked one behind the user's back, and
/// the question "why that one?" would have no answer on screen.
///
/// Two taps, three states, and no third control. Starring an unstarred picture
/// makes it the cover; **unstarring the cover means the trip wants none** — the
/// card then shows nothing, even though there are photographs. Deriving is not
/// a state anyone has to name: it is where a trip starts, and it looks exactly
/// like having chosen that picture, which is the point.
///
/// Amber because red is the app's one reserved colour ("this is happening") and
/// the trip's accent would be invisible against half the photographs it is
/// drawn on. A star that is gold when set is read without a legend.
class _CoverStar extends ConsumerWidget {
  const _CoverStar({required this.tripId, required this.attachmentId});

  final int tripId;
  final int attachmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isCover = ref.watch(tripCoverIdProvider(tripId)) == attachmentId;

    return IconButton(
      tooltip: isCover ? l10n.coverRemove : l10n.coverSet,
      icon: Icon(
        isCover ? Icons.star : Icons.star_border,
        color: isCover ? kCoverStarColor : Colors.white,
      ),
      // Taking the star off the cover is how a trip says it wants none: there
      // is nothing else the act could mean, since the picture on screen is the
      // one being shown.
      onPressed: () => isCover
          ? ref.read(repositoryProvider).setTripCoverHidden(tripId, true)
          : ref.read(repositoryProvider).setTripCover(tripId, attachmentId),
    );
  }
}

/// One picture, zoomable.
class _GalleryPage extends ConsumerStatefulWidget {
  const _GalleryPage({
    super.key,
    required this.photo,
    required this.onZoomChanged,
  });

  final GalleryPhoto photo;
  final ValueChanged<bool> onZoomChanged;

  @override
  ConsumerState<_GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<_GalleryPage> {
  final TransformationController _transform = TransformationController();

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransform);
    _transform.dispose();
    super.dispose();
  }

  void _onTransform() {
    // A hair above 1 rather than exactly it: the scale settles on values like
    // 1.0000001 after a pinch back out, and comparing for equality would leave
    // the page permanently locked.
    widget.onZoomChanged(_transform.value.getMaxScaleOnAxis() > 1.01);
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.photo.attachment;
    final bytes = ref.watch(attachmentBytesProvider(attachment.id));
    final thumbnail = attachment.thumbnail;

    return InteractiveViewer(
      transformationController: _transform,
      maxScale: 5,
      child: Center(
        child: bytes.when(
          data: (data) => data == null
              ? const Icon(Icons.broken_image_outlined, color: Colors.white54)
              : Image.memory(data, fit: BoxFit.contain),
          // The thumbnail is already in hand, so the picture arrives as a
          // sharpening rather than as a blank waiting to be filled.
          loading: () => thumbnail == null
              ? const CircularProgressIndicator()
              : Image.memory(thumbnail, fit: BoxFit.contain),
          error: (_, _) =>
              const Icon(Icons.broken_image_outlined, color: Colors.white54),
        ),
      ),
    );
  }
}
