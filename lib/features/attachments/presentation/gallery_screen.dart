import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../application/attachment_providers.dart';
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
Future<void> showGallery(
  BuildContext context, {
  required List<GalleryPhoto> photos,
  int initialIndex = 0,
}) {
  if (photos.isEmpty) return Future.value();
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => GalleryScreen(photos: photos, initialIndex: initialIndex),
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
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, required this.photos, this.initialIndex = 0});

  final List<GalleryPhoto> photos;
  final int initialIndex;

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
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
