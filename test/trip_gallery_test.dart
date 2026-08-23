import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/attachments/trip_gallery.dart';

/// Which photographs a trip has and in what order, without a widget tree.
void main() {
  var nextId = 0;

  ItineraryItem place({String? title, String? location, int? groupId}) =>
      ItineraryItem(
        id: ++nextId,
        tripId: 1,
        date: DateTime(2026, 5, 1),
        sortOrder: 0,
        kind: ItemKind.place,
        title: title,
        location: location,
        groupId: groupId,
        spansNextDay: false,
      );

  ItineraryItem leg({String? from, String? to, int? groupId}) => ItineraryItem(
    id: ++nextId,
    tripId: 1,
    date: DateTime(2026, 5, 1),
    sortOrder: 0,
    kind: ItemKind.transport,
    fromLocation: from,
    toLocation: to,
    groupId: groupId,
    spansNextDay: false,
  );

  Attachment photo({
    required String name,
    int? itemId,
    int? groupId,
    int sortOrder = 0,
  }) => Attachment(
    id: ++nextId,
    itemId: itemId,
    groupId: groupId,
    tripId: itemId == null && groupId == null ? 1 : null,
    kind: AttachmentKind.photo,
    mimeType: 'image/jpeg',
    name: name,
    byteSize: 1024,
    sortOrder: sortOrder,
    createdAt: DateTime(2026, 5, 1),
  );

  setUp(() => nextId = 0);

  test('nothing attached is an empty gallery', () {
    expect(tripGallery([place(title: 'Colosseum')], photos: const []), isEmpty);
  });

  test('runs through the trip in the order the timeline reads', () {
    final first = place(title: 'Colosseum');
    final second = place(title: 'Forum');
    final gallery = tripGallery(
      [first, second],
      photos: [
        // Deliberately handed over in the wrong order: the plan decides, not
        // whatever the rows came back as.
        photo(name: 'forum.jpg', itemId: second.id),
        photo(name: 'arena.jpg', itemId: first.id),
      ],
    );

    expect(gallery.map((p) => p.attachment.name), ['arena.jpg', 'forum.jpg']);
  });

  test("the trip's own come first, and carry no label", () {
    final entry = place(title: 'Colosseum');
    final gallery = tripGallery(
      [entry],
      photos: [
        photo(name: 'arena.jpg', itemId: entry.id),
        photo(name: 'the-trip.jpg'),
      ],
    );

    // About the journey rather than a day of it, which is the order the PDF
    // already prints in.
    expect(gallery.first.attachment.name, 'the-trip.jpg');
    expect(gallery.first.label, isNull);
  });

  test('each picture says which entry it hangs on', () {
    final museum = place(title: 'Kunsthalle');
    final walk = leg(from: 'Hamburg', to: 'Berlin');
    final gallery = tripGallery(
      [museum, walk],
      photos: [
        photo(name: 'a.jpg', itemId: museum.id),
        photo(name: 'b.jpg', itemId: walk.id),
      ],
    );

    expect(gallery.map((p) => p.label), ['Kunsthalle', 'Hamburg → Berlin']);
  });

  test('an untitled place falls back to where it is', () {
    final entry = place(location: 'Piazza del Colosseo');
    final gallery = tripGallery(
      [entry],
      photos: [photo(name: 'a.jpg', itemId: entry.id)],
    );

    expect(gallery.single.label, 'Piazza del Colosseo');
  });

  test("a run's photographs sit where the run begins, named after it", () {
    final loose = place(title: 'Breakfast');
    final first = leg(from: 'Hamburg', to: 'Hannover', groupId: 7);
    final second = leg(from: 'Hannover', to: 'Berlin', groupId: 7);
    final gallery = tripGallery(
      [loose, first, second],
      photos: [
        photo(name: 'ticket.jpg', groupId: 7),
        photo(name: 'breakfast.jpg', itemId: loose.id),
      ],
      groupLabels: const {7: 'To Berlin'},
    );

    expect(gallery.map((p) => p.attachment.name), [
      'breakfast.jpg',
      'ticket.jpg',
    ]);
    expect(gallery.last.label, 'To Berlin');
  });

  test("a run's photographs appear once, not once per member", () {
    final first = leg(from: 'A', to: 'B', groupId: 7);
    final second = leg(from: 'B', to: 'C', groupId: 7);
    final gallery = tripGallery(
      [first, second],
      photos: [photo(name: 'ticket.jpg', groupId: 7)],
      groupLabels: const {7: 'To Berlin'},
    );

    expect(gallery, hasLength(1));
  });

  test('a picture on an entry that is not in the plan is left out', () {
    final chosen = place(title: 'Colosseum');
    final gallery = tripGallery(
      // `liveItems` has already dropped the entry in the option nobody chose,
      // so it never reaches this list — the same arrangement the map has.
      [chosen],
      photos: [
        photo(name: 'taken.jpg', itemId: chosen.id),
        photo(name: 'not-taken.jpg', itemId: chosen.id + 100),
      ],
    );

    expect(gallery.map((p) => p.attachment.name), ['taken.jpg']);
  });

  test('several on one entry keep their own order', () {
    final entry = place(title: 'Colosseum');
    final gallery = tripGallery(
      [entry],
      photos: [
        photo(name: 'first.jpg', itemId: entry.id, sortOrder: 0),
        photo(name: 'second.jpg', itemId: entry.id, sortOrder: 1),
      ],
    );

    // The query hands them over sorted; nothing here reshuffles them.
    expect(gallery.map((p) => p.attachment.name), ['first.jpg', 'second.jpg']);
  });

  test('an unnamed, unplaced entry gives its picture no label', () {
    final entry = place();
    final gallery = tripGallery(
      [entry],
      photos: [photo(name: 'a.jpg', itemId: entry.id)],
    );

    // Better nothing than a made-up caption: the screen falls back to the file
    // name, which is at least something the user typed or the camera wrote.
    expect(gallery.single.label, isNull);
  });

  test('an unnamed run gives its picture no label either', () {
    final member = leg(from: 'A', to: 'B', groupId: 7);
    final gallery = tripGallery(
      [member],
      photos: [photo(name: 'ticket.jpg', groupId: 7)],
    );

    expect(gallery.single.label, isNull);
  });

  group('which one the overview card shows', () {
    Trip trip({int? coverAttachmentId, bool coverHidden = false}) => Trip(
      id: 1,
      title: 'Rome',
      destination: '',
      kind: TripKind.trip,
      colorValue: 0xFF00695C,
      coverAttachmentId: coverAttachmentId,
      coverHidden: coverHidden,
      photosCollapsed: false,
      createdAt: DateTime(2026, 1, 1),
    );

    List<GalleryPhoto> gallery() {
      final entry = place(title: 'Colosseum');
      return tripGallery(
        [entry],
        photos: [
          photo(name: 'first.jpg', itemId: entry.id, sortOrder: 0),
          photo(name: 'second.jpg', itemId: entry.id, sortOrder: 1),
        ],
      );
    }

    test('derives the first when nothing has been chosen', () {
      expect(coverPhoto(trip(), gallery())!.name, 'first.jpg');
    });

    test('shows the one the trip named', () {
      final photos = gallery();
      final chosen = photos.last.attachment.id;

      expect(
        coverPhoto(trip(coverAttachmentId: chosen), photos)!.name,
        'second.jpg',
      );
    });

    test('shows none when the trip says none, photos or not', () {
      // The third state, and the reason a nullable id cannot carry this alone:
      // "nothing chosen" and "nothing wanted" are different statements.
      expect(coverPhoto(trip(coverHidden: true), gallery()), isNull);
    });

    test('falls back when the named one has left the plan', () {
      // Deleted, or in an option nobody chose any more. Showing nothing would
      // be a statement this trip has not made.
      expect(
        coverPhoto(trip(coverAttachmentId: 9999), gallery())!.name,
        'first.jpg',
      );
    });

    test('a trip with no photographs shows none', () {
      expect(coverPhoto(trip(), const []), isNull);
    });
  });
}
