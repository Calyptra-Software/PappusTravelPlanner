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

/// A JPEG as **Android** hands one over to an app without
/// `ACCESS_MEDIA_LOCATION`: every GPS tag still in place, every value zeroed.
///
/// Built from the real thing. `IMG_20260823_151148.jpg` off a SHIFTphone 8
/// reached the Linux build with its position and the Android build without it;
/// the copy that came back through the app is byte-for-byte the same length as
/// the original and differs in exactly 32 bytes. `exiftool` reads the GPS
/// group as present and empty: the coordinates read as `0, 0` and the
/// hemisphere refs are a NUL byte where the letter was. That pair is what this
/// reproduces, and what tells it from a camera that really stood on Null
/// Island — which writes the letter.
Uint8List _photoWithLocationRedacted() {
  final image = _canvas(40, 30);
  final gps = image.exif.gpsIfd;
  gps['GPSLatitudeRef'] = img.IfdValueAscii('\u0000');
  gps['GPSLatitude'] = _zeroed();
  gps['GPSLongitudeRef'] = img.IfdValueAscii('\u0000');
  gps['GPSLongitude'] = _zeroed();
  gps['GPSTimeStamp'] = _zeroed();
  return img.encodeJpg(image);
}

/// Three rationals of `0/0` — eight zero bytes each, which is all redaction
/// leaves behind and something no camera writes.
img.IfdValueRational _zeroed() => _rationals([
  [0, 0],
  [0, 0],
  [0, 0],
]);

/// The other door: *Add file*, which keeps what it is given.
PreparedAttachment document(
  Uint8List bytes, {
  String? name,
  String? mimeType,
}) => prepareAttachment(
  bytes,
  name: name,
  mimeType: mimeType,
  kind: AttachmentKind.document,
);

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

    group('taken out on the way in', () {
      test('is told apart from a photograph that never had one', () {
        // Android since 10 removes `GPSLatitude` and `GPSLongitude` from a
        // photograph handed to an app without `ACCESS_MEDIA_LOCATION` — and
        // only those two, which is what makes the state recognizable instead
        // of merely absent.
        final prepared = prepareAttachment(_photoWithLocationRedacted());

        expect(prepared.position, isNull);
        expect(prepared.locationRedacted, isTrue);
      });

      test('a photograph with no GPS at all is not redaction', () {
        final prepared = prepareAttachment(img.encodeJpg(_canvas(40, 30)));

        expect(prepared.position, isNull);
        // Nothing was withheld: this camera had no fix, and saying otherwise
        // would send the user after a permission that would change nothing.
        expect(prepared.locationRedacted, isFalse);
      });

      test('nor is a photograph that has one', () {
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

        expect(prepared.locationRedacted, isFalse);
      });

      test('nor is a genuine reading of zero, which is a different zero', () {
        // `0/1` is a real coordinate that happens to be a lie, and
        // `exifPosition` refuses it on its own account. Redaction leaves `0/0`
        // — not a number at all — which is what tells the two apart.
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
        expect(prepared.locationRedacted, isFalse);
      });

      test('one ref on its own says nothing', () {
        final image = _canvas(40, 30);
        image.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');

        final prepared = prepareAttachment(img.encodeJpg(image));

        expect(prepared.locationRedacted, isFalse);
      });
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
      final prepared = document(bytes, name: 'ticket.pdf');

      expect(prepared.kind, AttachmentKind.document);
      expect(prepared.mimeType, 'application/pdf');
      expect(prepared.bytes, bytes);
      expect(prepared.thumbnail, isNull);
      expect(prepared.position, isNull);
    });

    test('fall back to a type that claims nothing', () {
      final prepared = document(
        Uint8List.fromList([1, 2, 3]),
        name: 'booking.xyz',
      );

      expect(prepared.mimeType, 'application/octet-stream');
    });

    test('keep the type the picker claimed when it gave one', () {
      final prepared = document(
        Uint8List.fromList([1, 2, 3]),
        name: 'note',
        mimeType: 'text/plain',
      );

      expect(prepared.mimeType, 'text/plain');
    });

    test('over the limit are refused, with both numbers', () {
      final bytes = Uint8List(kMaxAttachmentBytes + 1);

      expect(
        () => document(bytes, name: 'scan.pdf'),
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

    test('is refused whatever it is called, since the door said photo', () {
      // No sniffing of names or media types any more: at this door everything
      // is meant to be a picture, so anything that will not decode is refused.
      expect(
        () => prepareAttachment(
          Uint8List.fromList([0, 1, 2, 3]),
          name: 'itinerary.docx',
        ),
        throwsA(isA<UnreadableImageException>()),
      );
    });

    test('is welcome at the other door, kept exactly as it arrived', () {
      // The refusal is about calling something a photograph, not about the
      // file: through *Add file* a HEIC is stored byte for byte, which is what
      // filing something as a document means anyway.
      final bytes = Uint8List.fromList([0, 1, 2, 3]);
      final prepared = document(bytes, name: 'IMG_0042.HEIC');

      expect(prepared.kind, AttachmentKind.document);
      expect(prepared.bytes, bytes);
      // Nothing here could decode it, so there is nothing to show and nothing
      // claiming otherwise.
      expect(prepared.thumbnail, isNull);
      expect(prepared.width, isNull);
    });
  });

  group('a picture filed as a document', () {
    test('is kept byte for byte, metadata and all', () {
      // GPS as the witness, because it is the one tag these tests have proven
      // survives an encode: the photo cases above read it back out.
      final bytes = _photoAt(
        latDeg: 53,
        latMin: 33,
        latSec: 0,
        latRef: 'N',
        lonDeg: 10,
        lonMin: 0,
        lonSec: 0,
        lonRef: 'E',
      );

      final prepared = document(bytes, name: 'ticket.jpg');

      // The point of filing it here: the ticket you show at the barrier is the
      // file you were sent, at its own resolution, ready to hand on unchanged.
      expect(prepared.kind, AttachmentKind.document);
      expect(prepared.bytes, bytes);
      // Which is also why its metadata is still in it — a photograph would have
      // been re-encoded and stripped of everything but its position.
      expect(
        img.decodeJpg(prepared.bytes)!.exif.gpsIfd['GPSLatitude'],
        isNotNull,
      );
    });

    test('gets a thumbnail anyway, so a list of files is not blank', () {
      final prepared = document(
        img.encodePng(_canvas(64, 48)),
        name: 'ticket.png',
      );

      expect(prepared.thumbnail, isNotNull);
      // Recorded because the bytes really are a picture — the stored fact that
      // says this document can be looked at.
      expect(prepared.width, 64);
      expect(prepared.height, 48);
    });

    test('never carries a position, whatever its EXIF says', () {
      final prepared = document(
        _photoAt(
          latDeg: 53,
          latMin: 33,
          latSec: 0,
          latRef: 'N',
          lonDeg: 10,
          lonMin: 0,
          lonSec: 0,
          lonRef: 'E',
        ),
        name: 'ticket.jpg',
      );

      // A document is a file, not a place, whatever it is a picture of.
      expect(prepared.position, isNull);
      expect(prepared.positionSource, isNull);
    });

    test('the same file through the other door is a photograph', () {
      final bytes = img.encodePng(_canvas(64, 48));

      expect(document(bytes, name: 't.png').kind, AttachmentKind.document);
      expect(
        prepareAttachment(bytes, name: 't.png').kind,
        AttachmentKind.photo,
      );
      // Which is the whole change: the door decides, not the decoder.
    });
  });
}
