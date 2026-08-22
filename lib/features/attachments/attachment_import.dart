/// Turning a file the user picked into the row that will hold it.
///
/// Pure (like `gpx.dart`, which this is the counterpart of), so the rules below
/// are unit-testable without a widget tree, a database, or a file system — and
/// so the one place that decides what is stored is the one place that can be
/// read to find out.
///
/// Three rules decide what comes out:
///
/// * **A photo is re-encoded, never stored as it arrived.** The bytes live in
///   the database (see [Attachments] for why), and the database is copied whole
///   to be exported — on Android and on the web it is read into memory to do
///   it, which is the real ceiling here. A picture bounded at [kMaxPhotoEdge]
///   and [kPhotoQuality] costs a few hundred kilobytes instead of a few
///   megabytes, and this app is a planner, not a photo library: the original
///   stays where it lives, and what is kept is a copy sized for what the app
///   does with it — a thumbnail in a list, a picture on a screen, a marker on
///   the map, an image in the PDF.
/// * **Everything except the position is dropped**, because re-encoding drops
///   it. What EXIF holds beyond where the camera stood — the body, the lens, the
///   serial number, the second it was taken — is not something this app reads,
///   and a photo that travels in a `.tpt` bundle or a PDF should not carry it to
///   whoever the trip is shared with. The position survives only by being lifted
///   into a column of its own, where it is visible and can be cleared.
/// * **A picture the decoder cannot read is refused, not stored raw.** HEIC/HEIF
///   is the case that matters — the format an iPhone writes by default, which no
///   pure-Dart decoder reads. Keeping it as an opaque document would mean an
///   unbounded size, no thumbnail, EXIF left intact, and a file that displays on
///   some platforms and not others: every one of the three rules above broken at
///   once, silently. So it is turned away with the format named. (Android's
///   picker usually hands back JPEG for a HEIC anyway; usually is not a rule.)
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';

import '../../data/database/tables.dart';

/// The longest edge a stored photo may have, in pixels. Enough to fill any
/// screen the app runs on and to print at a sensible size, and small enough
/// that a trip's worth of them does not make the database unexportable.
const int kMaxPhotoEdge = 2048;

/// JPEG quality for the stored photo. High enough that the re-encoding is not
/// what anyone notices about the picture.
const int kPhotoQuality = 82;

/// The longest edge of the thumbnail kept beside a photo, for lists and for the
/// map marker.
const int kThumbnailEdge = 256;

/// JPEG quality of that thumbnail. Lower than the photo's on purpose: it is
/// never seen larger than a fingertip, and it rides along in every stream that
/// reads what an entry carries.
const int kThumbnailQuality = 70;

/// The largest file the app will take, in bytes.
///
/// A cap on *documents*, in practice: a photo is re-encoded to a fraction of
/// this whatever it arrived as. It exists because the whole database is read
/// into memory to be exported, so a scan nobody looks at can cost the user the
/// ability to move their trips off the device — which is the thing the app is
/// built around.
const int kMaxAttachmentBytes = 20 * 1024 * 1024;

/// A file that will not fit, with both numbers so the message can say by how
/// much rather than only that it failed.
class AttachmentTooLargeException implements Exception {
  const AttachmentTooLargeException(this.byteSize, this.limit);

  final int byteSize;
  final int limit;

  @override
  String toString() =>
      'Attachment of $byteSize bytes exceeds the $limit byte limit';
}

/// A picture in a format nothing here can read — HEIC being the one that
/// happens. Carries the extension so the refusal can name it.
class UnreadableImageException implements Exception {
  const UnreadableImageException(this.extension);

  /// The lower-case extension the file arrived with, without a dot, or null
  /// when it had none.
  final String? extension;

  @override
  String toString() => 'Unreadable image format: ${extension ?? 'unknown'}';
}

/// What [prepareAttachment] produces: everything the two tables need, and
/// nothing that has to be worked out again at the call site.
final class PreparedAttachment {
  const PreparedAttachment({
    required this.kind,
    required this.mimeType,
    required this.bytes,
    this.name,
    this.thumbnail,
    this.width,
    this.height,
    this.position,
    this.positionSource,
  });

  final AttachmentKind kind;
  final String mimeType;

  /// What goes into `AttachmentBlobs` — the re-encoded photo, or the document
  /// byte for byte.
  final Uint8List bytes;
  final String? name;
  final Uint8List? thumbnail;
  final int? width;
  final int? height;

  /// Where the camera said it stood, when it said. Null for a document and for
  /// a photo with no GPS in it — the app does not guess one from the entry the
  /// attachment hangs on.
  final LatLng? position;
  final AttachmentPositionSource? positionSource;

  int get byteSize => bytes.length;
}

/// Reads [bytes] into the form they are stored in.
///
/// [name] is the file's own name, kept as it arrived (it is also what the
/// extension is read off when the decoder cannot identify the data). [mimeType]
/// is what the picker claimed, used only for a document — a photo's type is
/// ours, because we wrote it.
///
/// Runs the decoder, two resizes and two encodes, so it belongs in an isolate
/// for anything but a test; see `attachment_controller.dart`.
///
/// Throws [AttachmentTooLargeException] for a file over [kMaxAttachmentBytes]
/// and [UnreadableImageException] for a picture that will not decode. Both are
/// clean refusals with something to say, which is what a file from outside is
/// owed.
PreparedAttachment prepareAttachment(
  Uint8List bytes, {
  String? name,
  String? mimeType,
}) {
  final decoded = _decodeOrNull(bytes);
  if (decoded != null) return _photo(decoded, name: name);

  // Nothing here could read it. If it announced itself as a picture, that is a
  // refusal and not a document — see the library comment.
  final extension = _extensionOf(name);
  if (_looksLikeAPicture(extension, mimeType)) {
    throw UnreadableImageException(extension);
  }

  if (bytes.length > kMaxAttachmentBytes) {
    throw AttachmentTooLargeException(bytes.length, kMaxAttachmentBytes);
  }
  return PreparedAttachment(
    kind: AttachmentKind.document,
    mimeType: mimeType ?? _mimeForExtension(extension),
    bytes: bytes,
    name: name,
  );
}

/// Whether these bytes are a picture, and the picture if they are.
///
/// Wrapped in a catch-all because identifying a format means offering the data
/// to every decoder in turn, and not all of them check the length before reading
/// a header: four bytes of nothing is enough to walk one off the end of the
/// buffer. A file the app did not write must produce an answer, never an
/// exception from three layers down — the same standard `parseGpx` is held to.
img.Image? _decodeOrNull(Uint8List bytes) {
  try {
    if (img.findFormatForData(bytes) == img.ImageFormat.invalid) return null;
    return img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
}

PreparedAttachment _photo(img.Image decoded, {String? name}) {
  // Read before anything else touches the image: the resize below rewrites it,
  // and the position is the one thing that has to survive the re-encoding.
  final position = exifPosition(decoded.exif);

  // `copyResize` bakes the orientation tag into the pixels, which matters
  // because the re-encoded photo carries no tag for a viewer to apply. A
  // picture already small enough is baked explicitly for the same reason —
  // skipping that step is how a portrait photo comes back on its side.
  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  final full = longest > kMaxPhotoEdge
      ? _resizedToFit(decoded, kMaxPhotoEdge)
      : img.bakeOrientation(decoded);
  final thumbnail = _resizedToFit(full, kThumbnailEdge);

  // Everything the file said about itself goes here, and this is the line that
  // makes the library comment above true: the resize *copies* the metadata, so
  // without this the camera body, the lens, the serial number, the second it
  // was taken and the GPS reading would all be written straight back out and
  // travel with the photo into a `.tpt` bundle or a PDF. The orientation is
  // already baked into the pixels above, so dropping the tag is also what stops
  // a viewer applying it a second time. The position survives because it was
  // read before this and is kept in a column, where it is visible and can be
  // cleared.
  full.exif = img.ExifData();
  thumbnail.exif = img.ExifData();

  return PreparedAttachment(
    kind: AttachmentKind.photo,
    mimeType: 'image/jpeg',
    bytes: img.encodeJpg(full, quality: kPhotoQuality),
    name: name,
    thumbnail: img.encodeJpg(thumbnail, quality: kThumbnailQuality),
    width: full.width,
    height: full.height,
    position: position,
    positionSource: position == null ? null : AttachmentPositionSource.exif,
  );
}

/// Scales [source] down so its longest edge is [edge], keeping the aspect ratio.
img.Image _resizedToFit(img.Image source, int edge) {
  final landscape = source.width >= source.height;
  return img.copyResize(
    source,
    width: landscape ? edge : null,
    height: landscape ? null : edge,
    interpolation: img.Interpolation.average,
  );
}

/// The position a picture's own EXIF claims, or null when it claims none.
///
/// A **measurement**, and treated as one: this is where the camera stood, which
/// is near the subject rather than on it, and may be a fix taken minutes
/// earlier. That is why it is recorded with its provenance
/// ([AttachmentPositionSource.exif]) instead of being presented as the same kind
/// of fact as a position the user pointed at. It does not conflict with the
/// app's rule that a position is pointed at and never derived: that rule is
/// about turning a *name* into a place, and nothing is being inferred here — the
/// file says where it was taken.
///
/// Exposed for its tests. Two readings are refused rather than stored: one
/// outside the world, and exactly 0,0 — a camera with no fix writes zeros often
/// enough that the Gulf of Guinea would otherwise fill up with other people's
/// holidays.
LatLng? exifPosition(img.ExifData exif) {
  final gps = exif.gpsIfd;
  final latitude = _degrees(gps['GPSLatitude']);
  final longitude = _degrees(gps['GPSLongitude']);
  if (latitude == null || longitude == null) return null;

  final lat = _negated(gps['GPSLatitudeRef'], 'S') ? -latitude : latitude;
  final lon = _negated(gps['GPSLongitudeRef'], 'W') ? -longitude : longitude;
  if (lat.abs() > 90 || lon.abs() > 180) return null;
  if (lat == 0 && lon == 0) return null;
  return LatLng(lat, lon);
}

/// Degrees, minutes and seconds as EXIF stores them — three rationals — folded
/// into one number. Anything shorter is not a coordinate.
double? _degrees(img.IfdValue? value) {
  if (value == null || value.length < 3) return null;
  final degrees = value.toDouble(0);
  final minutes = value.toDouble(1);
  final seconds = value.toDouble(2);
  if (degrees.isNaN || minutes.isNaN || seconds.isNaN) return null;
  return degrees + minutes / 60 + seconds / 3600;
}

bool _negated(img.IfdValue? ref, String negative) =>
    ref?.toString().trim().toUpperCase().startsWith(negative) ?? false;

String? _extensionOf(String? name) {
  if (name == null) return null;
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return null;
  return name.substring(dot + 1).toLowerCase();
}

/// Whether something that would not decode was nonetheless offered as a
/// picture. Kept deliberately narrow: only what is positively known to be an
/// image format may cost a file its place as a document.
bool _looksLikeAPicture(String? extension, String? mimeType) =>
    (mimeType != null && mimeType.startsWith('image/')) ||
    const {
      'heic',
      'heif',
      'avif',
      'jxl',
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'tif',
      'tiff',
    }.contains(extension);

/// A media type for a document, from its extension.
///
/// Only the handful worth naming — a ticket, a booking, a scan, a note. Anything
/// else is `application/octet-stream`, which is an honest "a file", and is what
/// the platform falls back to reading the extension itself.
String _mimeForExtension(String? extension) => switch (extension) {
  'pdf' => 'application/pdf',
  'txt' => 'text/plain',
  'md' => 'text/markdown',
  'csv' => 'text/csv',
  'html' || 'htm' => 'text/html',
  'json' => 'application/json',
  'ics' => 'text/calendar',
  'zip' => 'application/zip',
  _ => 'application/octet-stream',
};
