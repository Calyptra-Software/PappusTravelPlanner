import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/attachments/attachment_import.dart';

/// A plain image of [width] x [height], with no metadata of its own.
img.Image _canvas(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(120, 160, 200));
  return image;
}

/// EXIF's degrees/minutes/seconds triple.
///
/// Built as an [img.IfdValueRational] rather than handed to the directory as
/// plain numbers, because `IfdDirectory`'s convenience setter resolves a GPS tag
/// name against the *image* tag table — where 0x0002 is `InteropVersion` — and
/// silently drops the value. Reading is by id and unaffected; this is only how
/// a file with GPS in it gets built here.
img.IfdValueRational _dms(int degrees, int minutes, double seconds) =>
    _rationals([
      [degrees, 1],
      [minutes, 1],
      [(seconds * 1000).round(), 1000],
    ]);

img.IfdValueRational _rationals(List<List<int>> pairs) {
  final data = ByteData(pairs.length * 8);
  for (var i = 0; i < pairs.length; i++) {
    data.setUint32(i * 8, pairs[i][0], Endian.little);
    data.setUint32(i * 8 + 4, pairs[i][1], Endian.little);
  }
  return img.IfdValueRational.data(
    img.InputBuffer(data.buffer.asUint8List()),
    pairs.length,
  );
}

/// A JPEG carrying a GPS position, as a camera writes one.
Uint8List _photoAt({
  required int latDeg,
  required int latMin,
  required double latSec,
  required String latRef,
  required int lonDeg,
  required int lonMin,
  required double lonSec,
  required String lonRef,
}) {
  final image = _canvas(40, 30);
  final gps = image.exif.gpsIfd;
  gps['GPSLatitude'] = _dms(latDeg, latMin, latSec);
  gps['GPSLatitudeRef'] = img.IfdValueAscii(latRef);
  gps['GPSLongitude'] = _dms(lonDeg, lonMin, lonSec);
  gps['GPSLongitudeRef'] = img.IfdValueAscii(lonRef);
  return img.encodeJpg(image);
}

void main() {
  group('photos', () {
    test('are re-encoded as JPEG with a thumbnail beside them', () {
      final prepared = prepareAttachment(
        img.encodePng(_canvas(64, 48)),
        name: 'view.png',
      );

      expect(prepared.kind, AttachmentKind.photo);
      // Ours, not the picker's: we wrote these bytes, so we know what they are.
      expect(prepared.mimeType, 'image/jpeg');
      expect(img.findFormatForData(prepared.bytes), img.ImageFormat.jpg);
      expect(prepared.thumbnail, isNotNull);
      expect(img.findFormatForData(prepared.thumbnail!), img.ImageFormat.jpg);
      expect(prepared.width, 64);
      expect(prepared.height, 48);
      expect(prepared.name, 'view.png');
    });

    test('are bounded on their longest edge, keeping the aspect ratio', () {
      final prepared = prepareAttachment(
        img.encodeJpg(_canvas(kMaxPhotoEdge * 2, kMaxPhotoEdge)),
      );

      expect(prepared.width, kMaxPhotoEdge);
      expect(prepared.height, kMaxPhotoEdge ~/ 2);
      final thumbnail = img.decodeJpg(prepared.thumbnail!)!;
      expect(thumbnail.width, kThumbnailEdge);
    });

    test('smaller than the bound are kept at their own size', () {
      final prepared = prepareAttachment(img.encodeJpg(_canvas(300, 200)));

      expect(prepared.width, 300);
      expect(prepared.height, 200);
    });

    test('carry no position when the file holds none', () {
      final prepared = prepareAttachment(img.encodeJpg(_canvas(20, 20)));

      expect(prepared.position, isNull);
      expect(prepared.positionSource, isNull);
      // Deliberately not inherited from the entry it will hang on: that is the
      // app claiming to know where a picture was taken.
    });

    test('lose everything in their EXIF except the position', () {
      final image = _canvas(30, 30);
      image.exif.imageIfd['Model'] = img.IfdValueAscii('A Camera');
      image.exif.gpsIfd['GPSLatitude'] = _dms(53, 33, 0);
      image.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
      image.exif.gpsIfd['GPSLongitude'] = _dms(10, 0, 0);
      image.exif.gpsIfd['GPSLongitudeRef'] = img.IfdValueAscii('E');

      final prepared = prepareAttachment(img.encodeJpg(image));
      final stored = img.decodeJpg(prepared.bytes)!;

      expect(prepared.position, isNotNull);
      expect(stored.exif.imageIfd['Model'], isNull);
      expect(stored.exif.gpsIfd['GPSLatitude'], isNull);
    });
  });

  group('EXIF position', () {
    test('is read as degrees, minutes and seconds', () {
      final prepared = prepareAttachment(
        _photoAt(
          latDeg: 53,
          latMin: 33,
          latSec: 3.6,
          latRef: 'N',
          lonDeg: 10,
          lonMin: 0,
          lonSec: 21.6,
          lonRef: 'E',
        ),
      );

      expect(prepared.positionSource, AttachmentPositionSource.exif);
      expect(prepared.position!.latitude, closeTo(53.5510, 0.0001));
      expect(prepared.position!.longitude, closeTo(10.0060, 0.0001));
    });

    test('is negated by the south and west references', () {
      final prepared = prepareAttachment(
        _photoAt(
          latDeg: 33,
          latMin: 55,
          latSec: 0,
          latRef: 'S',
          lonDeg: 18,
          lonMin: 25,
          lonSec: 0,
          lonRef: 'W',
        ),
      );

      expect(prepared.position!.latitude, closeTo(-33.9167, 0.0001));
      expect(prepared.position!.longitude, closeTo(-18.4167, 0.0001));
    });

    test('is refused at exactly 0,0 — a camera with no fix writes zeros', () {
      final prepared = prepareAttachment(
        _photoAt(
          latDeg: 0,
          latMin: 0,
          latSec: 0,
          latRef: 'N',
          lonDeg: 0,
          lonMin: 0,
          lonSec: 0,
          lonRef: 'E',
        ),
      );

      expect(prepared.position, isNull);
      expect(prepared.positionSource, isNull);
    });

    test('is refused outside the world', () {
      final prepared = prepareAttachment(
        _photoAt(
          latDeg: 100,
          latMin: 0,
          latSec: 0,
          latRef: 'N',
          lonDeg: 10,
          lonMin: 0,
          lonSec: 0,
          lonRef: 'E',
        ),
      );

      expect(prepared.position, isNull);
    });
  });

  group('documents', () {
    test('are stored byte for byte, typed from their extension', () {
      final bytes = Uint8List.fromList('%PDF-1.4 not really'.codeUnits);
      final prepared = prepareAttachment(bytes, name: 'ticket.pdf');

      expect(prepared.kind, AttachmentKind.document);
      expect(prepared.mimeType, 'application/pdf');
      expect(prepared.bytes, bytes);
      expect(prepared.thumbnail, isNull);
      expect(prepared.position, isNull);
    });

    test('fall back to a type that claims nothing', () {
      final prepared = prepareAttachment(
        Uint8List.fromList([1, 2, 3]),
        name: 'booking.xyz',
      );

      expect(prepared.mimeType, 'application/octet-stream');
    });

    test('keep the type the picker claimed when it gave one', () {
      final prepared = prepareAttachment(
        Uint8List.fromList([1, 2, 3]),
        name: 'note',
        mimeType: 'text/plain',
      );

      expect(prepared.mimeType, 'text/plain');
    });

    test('over the limit are refused, with both numbers', () {
      final bytes = Uint8List(kMaxAttachmentBytes + 1);

      expect(
        () => prepareAttachment(bytes, name: 'scan.pdf'),
        throwsA(
          isA<AttachmentTooLargeException>()
              .having((e) => e.byteSize, 'byteSize', kMaxAttachmentBytes + 1)
              .having((e) => e.limit, 'limit', kMaxAttachmentBytes),
        ),
      );
    });
  });

  group('a picture nothing here can read', () {
    test('is refused rather than kept as an opaque document', () {
      // Not a HEIC, but named as one: it is the extension that says a refusal
      // is owed, since the decoder has already failed on the bytes.
      expect(
        () => prepareAttachment(
          Uint8List.fromList([0, 1, 2, 3]),
          name: 'IMG_0042.HEIC',
        ),
        throwsA(
          isA<UnreadableImageException>().having(
            (e) => e.extension,
            'extension',
            'heic',
          ),
        ),
      );
    });

    test('is refused on the picker\'s media type too', () {
      expect(
        () => prepareAttachment(
          Uint8List.fromList([0, 1, 2, 3]),
          name: 'photo',
          mimeType: 'image/heif',
        ),
        throwsA(isA<UnreadableImageException>()),
      );
    });

    test('does not turn an ordinary file away', () {
      // Only what is positively known to be a picture may cost a file its place
      // as a document.
      final prepared = prepareAttachment(
        Uint8List.fromList([0, 1, 2, 3]),
        name: 'itinerary.docx',
      );

      expect(prepared.kind, AttachmentKind.document);
    });
  });
}
