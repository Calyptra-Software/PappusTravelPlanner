import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/itinerary/day_blocks.dart';
import 'package:travelplanner/features/itinerary/now_marker.dart';

/// Covers [nowMarker]: where the current time falls in a day that reads as an
/// ordered list of blocks rather than a time-scaled axis.
void main() {
  final day = DateTime(2026, 7, 5);

  ItineraryItem item(
    int id, {
    int? start,
    int? end,
    int? actualStart,
    int? actualEnd,
    int sortOrder = 0,
    int? alternativeId,
  }) => ItineraryItem(
    id: id,
    tripId: 1,
    date: day,
    sortOrder: sortOrder,
    kind: ItemKind.place,
    spansNextDay: false,
    title: 'Item $id',
    startMinutes: start,
    endMinutes: end,
    actualStartMinutes: actualStart,
    actualEndMinutes: actualEnd,
    alternativeId: alternativeId,
  );

  /// A decision whose two options both hold [chosenItems] / [otherItems].
  DecisionBlock decision({
    required List<ItineraryItem> chosenItems,
    required List<ItineraryItem> otherItems,
    int sortOrder = 0,
  }) {
    const chosenBranch = Alternative(
      id: 1,
      setId: 1,
      sortOrder: 0,
      chosen: true,
    );
    const otherBranch = Alternative(
      id: 2,
      setId: 1,
      sortOrder: 1,
      chosen: false,
    );
    return DecisionBlock(
      set: AlternativeSet(id: 1, tripId: 1, date: day, sortOrder: sortOrder),
      branches: const [chosenBranch, otherBranch],
      itemsByBranch: {1: chosenItems, 2: otherItems},
    );
  }

  const noon = 12 * 60;

  test('the entry under way is the mark; no line is drawn', () {
    final blocks = [
      ItemBlock(item(1, start: 9 * 60, end: 10 * 60)),
      ItemBlock(item(2, start: 11 * 60, end: 13 * 60)),
      ItemBlock(item(3, start: 15 * 60)),
    ];

    expect(nowMarker(blocks, noon), const NowMarker(index: 1, happening: true));
  });

  test('between two entries, the line goes above the next one', () {
    final blocks = [
      ItemBlock(item(1, start: 9 * 60, end: 10 * 60)),
      ItemBlock(item(2, start: 15 * 60, end: 16 * 60)),
    ];

    expect(
      nowMarker(blocks, noon),
      const NowMarker(index: 1, happening: false),
    );
  });

  test('before the day starts, the line goes at the top', () {
    final blocks = [ItemBlock(item(1, start: 15 * 60, end: 16 * 60))];

    expect(
      nowMarker(blocks, noon),
      const NowMarker(index: 0, happening: false),
    );
  });

  test('with the day behind us, the line goes below the last entry', () {
    final blocks = [
      ItemBlock(item(1, start: 9 * 60, end: 10 * 60)),
      ItemBlock(item(2, start: 10 * 60, end: 11 * 60)),
    ];

    expect(
      nowMarker(blocks, noon),
      const NowMarker(index: 2, happening: false),
    );
  });

  test('an entry with only a start time is passed, not inhabited', () {
    final blocks = [ItemBlock(item(1, start: 11 * 60))];

    expect(
      nowMarker(blocks, noon),
      const NowMarker(index: 1, happening: false),
    );
  });

  test('a day with no times at all carries no mark', () {
    final blocks = [ItemBlock(item(1)), ItemBlock(item(2))];

    expect(nowMarker(blocks, noon), isNull);
  });

  test('an entry that ran late is still under way past its planned end', () {
    // Planned 09:00–11:00, but it started an hour late and is not over yet.
    final blocks = [
      ItemBlock(item(1, start: 9 * 60, end: 11 * 60, actualStart: 10 * 60)),
      ItemBlock(item(2, start: 15 * 60, end: 16 * 60)),
    ];

    // On the plan alone, noon would be past the first entry. What happened wins.
    expect(
      nowMarker(blocks, 10 * 60 + 30),
      const NowMarker(index: 0, happening: true),
    );
  });

  test('an entry that ended early is behind us before it was due to end', () {
    final blocks = [
      ItemBlock(item(1, start: 9 * 60, end: 13 * 60, actualEnd: 11 * 60)),
    ];

    expect(
      nowMarker(blocks, noon),
      const NowMarker(index: 1, happening: false),
    );
  });

  test(
    'an untimed entry stays ahead of the line — we cannot know it is done',
    () {
      final blocks = [
        ItemBlock(item(1, start: 9 * 60, end: 10 * 60)),
        ItemBlock(item(2)),
        ItemBlock(item(3, start: 15 * 60, end: 16 * 60)),
      ];

      expect(
        nowMarker(blocks, noon),
        const NowMarker(index: 1, happening: false),
      );
    },
  );

  test('an untimed entry is behind the line once something after it is', () {
    final blocks = [
      ItemBlock(item(1)),
      ItemBlock(item(2, start: 9 * 60, end: 10 * 60)),
    ];

    expect(
      nowMarker(blocks, noon),
      const NowMarker(index: 2, happening: false),
    );
  });

  test('a decision is under way by its chosen option, never by another', () {
    final blocks = [
      decision(
        chosenItems: [item(1, start: 11 * 60, end: 13 * 60, alternativeId: 1)],
        otherItems: [item(2, start: 15 * 60, end: 16 * 60, alternativeId: 2)],
      ),
    ];

    expect(nowMarker(blocks, noon), const NowMarker(index: 0, happening: true));
  });

  test(
    "a decision the trip is not following can't pull the mark onto itself",
    () {
      final blocks = [
        decision(
          // The chosen option is over by 10:00; the option not taken would still
          // be running at noon — but it is not what the trip is doing.
          chosenItems: [item(1, start: 9 * 60, end: 10 * 60, alternativeId: 1)],
          otherItems: [item(2, start: 9 * 60, end: 18 * 60, alternativeId: 2)],
        ),
      ];

      expect(
        nowMarker(blocks, noon),
        const NowMarker(index: 1, happening: false),
      );
    },
  );

  test('a decision spans its chosen option from first start to last end', () {
    final blocks = [
      decision(
        chosenItems: [
          item(1, start: 9 * 60, end: 10 * 60, alternativeId: 1),
          // Nothing is under way at noon *within* the option, but the decision
          // as a block still is: it is the slot the day is currently in.
          item(2, start: 14 * 60, end: 15 * 60, sortOrder: 1, alternativeId: 1),
        ],
        otherItems: [],
      ),
    ];

    expect(nowMarker(blocks, noon), const NowMarker(index: 0, happening: true));
  });

  test('inside an option, the entry under way is marked', () {
    final items = [
      item(1, start: 9 * 60, end: 10 * 60, alternativeId: 1),
      item(2, start: 11 * 60, end: 13 * 60, sortOrder: 1, alternativeId: 1),
    ];

    expect(
      nowMarkerForItems(items, noon),
      const NowMarker(index: 1, happening: true),
    );
  });

  test('a run is under way from its first departure to its last arrival', () {
    final run = GroupBlock(
      groupId: 7,
      items: [
        item(1, start: 540, end: 600, sortOrder: 0),
        // The change in between is part of the journey, and so is the wait: the
        // run spans it whole.
        item(2, start: 640, end: 700, sortOrder: 1),
      ],
    );
    final blocks = [ItemBlock(item(3, start: 480, end: 500)), run];

    // In the gap between the two legs: the journey is still what is happening.
    expect(nowMarker(blocks, 620), const NowMarker(index: 1, happening: true));
    // Before it departs, the line sits above the run rather than inside it.
    expect(nowMarker(blocks, 510), const NowMarker(index: 1, happening: false));
    // Landed: the whole day is behind us.
    expect(nowMarker(blocks, 800), const NowMarker(index: 2, happening: false));
  });
}
