/// Turning a file the user picked into the row that will hold it.
///
/// Pure (like `gpx.dart`, which this is the counterpart of), so the rules below
/// are unit-testable without a widget tree, a database, or a file system — and
/// so the one place that decides what is stored is the one place that can be
/// read to find out.
///
/// Three rules decide what comes out:
///
/// **Which of the two a file becomes is the caller's answer** — the door it came
/// through — never the decoder's. A train ticket saved as a `.png` belongs under
/// documents if that is where its owner wants it, and the app has no business
/// overruling that; see [prepareAttachment].
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
/// * **A picture the decoder cannot read is refused at the photo door**, and
///   only there. HEIC/HEIF is the case that matters — the format an iPhone
///   writes by default, which no pure-Dart decoder reads. Filed as a
///   *photograph* it would break all three rules above at once and silently:
///   unbounded, no thumbnail, EXIF intact. So that door turns it away with the
///   format named. Through *Add file* the same picture is welcome: a document is
///   kept as it arrived by definition, and the app is then storing and handing
///   on a file rather than claiming to be able to show it.
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
    this.locationRedacted = false,
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

  /// Whether the platform took the coordinates out of this photograph before
  /// the app ever saw it — see [exifLocationRedacted]. Not stored: it is a fact
  /// about this import, not about the row, and the row simply has no position.
  /// It exists so the flow can say what happened instead of attaching a
  /// photograph that silently lost its place.
  final bool locationRedacted;

  int get byteSize => bytes.length;

  /// The same photograph, with the place its own EXIF gave up only on a second
  /// reading.
  ///
  /// Android hands a picked picture over with its coordinates zeroed unless the
  /// app holds `ACCESS_MEDIA_LOCATION`, and even then only the *original* behind
  /// the picker's copy carries them — see `media_location.dart`. So the position
  /// can arrive after the bytes have been read, from the platform rather than
  /// from them, and it is still [AttachmentPositionSource.exif]: it is the same
  /// number the same file was written with, fetched by a different route.
  ///
  /// [locationRedacted] goes false with it. The flag exists to explain a missing
  /// position, and there is no longer one to explain.
  PreparedAttachment withExifPosition(LatLng position) => PreparedAttachment(
    kind: kind,
    mimeType: mimeType,
    bytes: bytes,
    name: name,
    thumbnail: thumbnail,
    width: width,
    height: height,
    position: position,
    positionSource: AttachmentPositionSource.exif,
  );

  /// The same photograph with no place on it.
  ///
  /// Not a refusal to *look* — by the time this is called the bytes have been
  /// read and the position is either in them or it is not. It is a refusal to
  /// **keep**, and that is where the switch in settings has to act: an Android
  /// permission cannot be handed back from inside an app, so once it has been
  /// granted a photograph arrives unredacted whether the app still wants it to
  /// or not. Dropping it here is the only place a user's "no" can be honoured.
  ///
  /// [locationRedacted] is left alone: it records what the *platform* did on
  /// the way in, which is still true, and the app declining to keep a position
  /// does not make one having been withheld untrue.
  PreparedAttachment withoutPosition() => PreparedAttachment(
    kind: kind,
    mimeType: mimeType,
    bytes: bytes,
    name: name,
    thumbnail: thumbnail,
    width: width,
    height: height,
    locationRedacted: locationRedacted,
  );
}

/// Reads [bytes] into the form they are stored in.
///
/// **[kind] is the caller's answer, not the decoder's** — which door the file
/// came through, *Add photo* or *Add file*. It used to be read off the bytes:
/// whatever decoded was a photograph, so a train ticket saved as a `.png` could
/// not be filed as a document however much the user wanted it there. Deciding
/// it here would be the app ruling on what a file *means*, which is the one
/// thing it declines to do about tags, about trip length and about a position.
///
/// [name] is the file's own name, kept as it arrived (it is also what the
/// extension is read off when the decoder cannot identify the data). [mimeType]
/// is what the picker claimed, used only for a document — a photo's type is
/// ours, because we wrote it.
///
/// Runs the decoder, two resizes and two encodes for a photograph, so it belongs
/// in an isolate for anything but a test; see `attachment_flow.dart`.
///
/// Throws [AttachmentTooLargeException] for a file over [kMaxAttachmentBytes]
/// and [UnreadableImageException] for a picture that will not decode. Both are
/// clean refusals with something to say, which is what a file from outside is
/// owed.
PreparedAttachment prepareAttachment(
  Uint8List bytes, {
  String? name,
  String? mimeType,
  AttachmentKind kind = AttachmentKind.photo,
}) {
  final decoded = _decodeOrNull(bytes);
  if (kind == AttachmentKind.photo) {
    // At this door everything is a picture, so anything that will not decode is
    // a refusal — no quiet demotion to "some file", which would put a thing the
    // user asked to see among the things they asked to keep.
    if (decoded == null) throw UnreadableImageException(_extensionOf(name));
    return _photo(decoded, name: name);
  }
  return _document(bytes, decoded, name: name, mimeType: mimeType);
}

/// A file kept exactly as it arrived.
///
/// **Byte for byte, even when it is a picture**, because that is what filing
/// something as a document means: the ticket you show at the barrier is the
/// file you were sent, at its own resolution, with its own QR code, ready to be
/// handed on unchanged. Two things follow and are meant to:
///
/// * It is **not** bounded like a photograph, only by [kMaxAttachmentBytes].
/// * Its metadata is **not** stripped. A photograph is re-encoded and loses
///   everything but the position lifted out of it; a document is not touched at
///   all, so whatever EXIF it carries travels with it. `SECURITY.md` says so.
///
/// What is added rather than changed is a **thumbnail**, when the bytes happen
/// to be a picture — a list of files with one blank row among them is a list
/// that looks broken. The stored bytes are untouched by making it. There is no
/// position and no map marker: a document is a file, not a place, whatever it
/// is a picture of.
PreparedAttachment _document(
  Uint8List bytes,
  img.Image? decoded, {
  String? name,
  String? mimeType,
}) {
  if (bytes.length > kMaxAttachmentBytes) {
    throw AttachmentTooLargeException(bytes.length, kMaxAttachmentBytes);
  }
  final extension = _extensionOf(name);
  final format = decoded == null ? null : _mimeForImage(bytes);
  final thumbnail = decoded == null
      ? null
      : img.encodeJpg(
          _resizedToFit(img.bakeOrientation(decoded), kThumbnailEdge)
            ..exif = img.ExifData(),
          quality: kThumbnailQuality,
        );
  return PreparedAttachment(
    kind: AttachmentKind.document,
    // What the bytes *are* outranks what the picker said and what the name
    // suggests: a decoder that read the file knows its format, and the media
    // type is what the operating system is handed when the file is opened
    // again. Only when nothing could read it does the extension get a say.
    mimeType: format ?? mimeType ?? _mimeForExtension(extension),
    bytes: bytes,
    name: name,
    thumbnail: thumbnail,
    // Recorded only when the bytes really are a picture, which is what makes
    // this the app's answer to "can this document be looked at?" — a stored
    // fact rather than a guess from a media type the picker supplied.
    width: decoded?.width,
    height: decoded?.height,
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
  final redacted = position == null && exifLocationRedacted(decoded.exif);

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
    locationRedacted: redacted,
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

/// Whether the coordinates were taken out of this photograph on the way in.
///
/// Android has done this since version 10: a photograph handed to an app that
/// does not hold `ACCESS_MEDIA_LOCATION` arrives without its position. What it
/// does *not* do is rewrite the file — measured on a real one, the redacted
/// copy is byte-for-byte the same length as the original and differs in exactly
/// **32 bytes**. The GPS tags all survive; their values are overwritten with
/// zeros in place, which for a coordinate means three rationals of `0/0`.
///
/// So the state to recognize is not an absence but a **zero that is too
/// complete**: coordinates that are there and read as `0, 0`, next to
/// hemisphere refs that are there and say nothing. A camera writes the letter
/// even when it has nothing else — see [_blankRef], which is the part of the
/// signature that survives the decoder.
///
/// Distinguishing this from "this photograph never knew" is the whole point.
/// Both end with no position, but one is a fact about the picture and the other
/// is the system declining to say — and only the second is worth telling the
/// user, who otherwise watches a holiday photograph attach itself with no place
/// and no reason given, and goes looking for the bug in the app.
bool exifLocationRedacted(img.ExifData exif) {
  final gps = exif.gpsIfd;
  final latitude = _degrees(gps['GPSLatitude']);
  final longitude = _degrees(gps['GPSLongitude']);
  // No coordinates at all is a photograph that never knew, not one that was
  // emptied: redaction overwrites what is there and adds nothing.
  if (latitude == null || longitude == null) return false;
  if (latitude != 0 || longitude != 0) return false;
  return _blankRef(gps['GPSLatitudeRef']) && _blankRef(gps['GPSLongitudeRef']);
}

/// Whether a hemisphere reference has been emptied.
///
/// This is what separates redaction from a camera that really did stand on
/// Null Island: the coordinates read as zero either way — `exifPosition`
/// refuses both, and rightly — but a camera always writes `N` or `S`, and the
/// zeroing leaves a NUL byte where the letter was.
///
/// The letter is read rather than the rationals' denominators, which would say
/// it more directly (`0/0` against `0/1`): the decoder hands GPS coordinates
/// back as `IfdValueSRational`, which does not override `toRational`, so the
/// base class answers a flat `0/1` for every part and the distinction is gone
/// before it can be read. `toDouble` flattens it the same way. What survives
/// the decoder intact is the ref.
bool _blankRef(img.IfdValue? ref) {
  final text = ref?.toString().replaceAll('\u0000', '').trim();
  return text == null || text.isEmpty;
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

/// The media type of a picture, from the format the decoder recognised.
///
/// A fact about the bytes rather than a guess from a name, which is why it wins
/// over both. Null for a format with no media type worth naming.
String? _mimeForImage(Uint8List bytes) =>
    switch (img.findFormatForData(bytes)) {
      img.ImageFormat.jpg => 'image/jpeg',
      img.ImageFormat.png => 'image/png',
      img.ImageFormat.gif => 'image/gif',
      img.ImageFormat.webp => 'image/webp',
      img.ImageFormat.bmp => 'image/bmp',
      img.ImageFormat.tiff => 'image/tiff',
      _ => null,
    };

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
