import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/itinerary/day_blocks.dart';

/// Covers [buildDayBlocks]: a day reads as an ordered list of blocks — its loose
/// items and its decisions, which share one ordering space.
void main() {
  final day = DateTime(2026, 7, 5);
  final otherDay = DateTime(2026, 7, 6);

  ItineraryItem item(
    int id, {
    required String title,
    required int sortOrder,
    int? alternativeId,
    DateTime? date,
  }) => ItineraryItem(
    id: id,
    tripId: 1,
    date: date ?? day,
    sortOrder: sortOrder,
    kind: ItemKind.place,
    title: title,
    alternativeId: alternativeId,
  );

  AlternativeSet set(int id, {required int sortOrder, DateTime? date}) =>
      AlternativeSet(
        id: id,
        tripId: 1,
        date: date ?? day,
        sortOrder: sortOrder,
      );

  Alternative branch(
    int id, {
    required int setId,
    required int sortOrder,
    bool chosen = false,
  }) => Alternative(id: id, setId: setId, sortOrder: sortOrder, chosen: chosen);

  test('a decision takes its slot among the day\'s loose items', () {
    final blocks = buildDayBlocks(
      day: day,
      items: [
        item(1, title: 'Breakfast', sortOrder: 0),
        item(2, title: 'Museum', sortOrder: 0, alternativeId: 10),
        item(3, title: 'Beach', sortOrder: 0, alternativeId: 11),
        item(4, title: 'Dinner', sortOrder: 2),
      ],
      sets: {5: set(5, sortOrder: 1)},
      branchesBySet: {
        5: [
          branch(10, setId: 5, sortOrder: 0, chosen: true),
          branch(11, setId: 5, sortOrder: 1),
        ],
      },
    );

    // Breakfast -> the choice -> dinner: the decision is one block in between.
    expect(blocks, hasLength(3));
    expect((blocks[0] as ItemBlock).item.title, 'Breakfast');
    expect((blocks[2] as ItemBlock).item.title, 'Dinner');

    final decision = blocks[1] as DecisionBlock;
    expect(decision.set.id, 5);
    expect(decision.chosen.id, 10);
    // Every option carries its own items — including the one not chosen, which
    // the card needs to draw when it is swiped to.
    expect(decision.itemsByBranch[10]!.map((i) => i.title), ['Museum']);
    expect(decision.itemsByBranch[11]!.map((i) => i.title), ['Beach']);
  });

  test('an option with nothing planned yet is present but empty', () {
    final blocks = buildDayBlocks(
      day: day,
      items: [item(2, title: 'Museum', sortOrder: 0, alternativeId: 10)],
      sets: {5: set(5, sortOrder: 0)},
      branchesBySet: {
        5: [
          branch(10, setId: 5, sortOrder: 0, chosen: true),
          branch(11, setId: 5, sortOrder: 1),
        ],
      },
    );

    final decision = blocks.single as DecisionBlock;
    expect(decision.branches, hasLength(2));
    expect(decision.itemsByBranch[11], isEmpty);
  });

  test('another day\'s items and decisions are left out', () {
    final blocks = buildDayBlocks(
      day: day,
      items: [
        item(1, title: 'Today', sortOrder: 0),
        item(2, title: 'Tomorrow', sortOrder: 0, date: otherDay),
        item(
          3,
          title: 'In tomorrow\'s option',
          sortOrder: 0,
          alternativeId: 20,
        ),
      ],
      sets: {
        5: set(5, sortOrder: 1),
        6: set(6, sortOrder: 0, date: otherDay),
      },
      branchesBySet: {
        5: [
          branch(10, setId: 5, sortOrder: 0, chosen: true),
          branch(11, setId: 5, sortOrder: 1),
        ],
        6: [
          branch(20, setId: 6, sortOrder: 0, chosen: true),
          branch(21, setId: 6, sortOrder: 1),
        ],
      },
    );

    expect(blocks, hasLength(2));
    expect((blocks[0] as ItemBlock).item.title, 'Today');
    expect((blocks[1] as DecisionBlock).set.id, 5);
  });

  test('a decision falls back to its first option when none is chosen', () {
    final blocks = buildDayBlocks(
      day: day,
      items: const [],
      sets: {5: set(5, sortOrder: 0)},
      branchesBySet: {
        5: [
          branch(10, setId: 5, sortOrder: 0),
          branch(11, setId: 5, sortOrder: 1),
        ],
      },
    );

    // The DAO keeps exactly one chosen, but a malformed set must still render.
    expect((blocks.single as DecisionBlock).chosen.id, 10);
  });

  test('a set with no options is skipped rather than drawn empty', () {
    final blocks = buildDayBlocks(
      day: day,
      items: [item(1, title: 'Breakfast', sortOrder: 0)],
      sets: {5: set(5, sortOrder: 1)},
      branchesBySet: const {},
    );

    expect(blocks.single, isA<ItemBlock>());
  });
}
