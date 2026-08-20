import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/map/track_entry_path.dart';

/// One path through the plan — what a recording can have covered.
///
/// Two rules are under test, and the first is the one that made this file
/// necessary: the path reads in **timeline order**. A branch item's `sortOrder`
/// counts within its branch, so a plan read flat puts an option's first entry
/// ahead of the loose entries it actually comes after — and the recording is
/// divided between the picked entries in the order they are handed over, so a
/// mis-ordered path cuts the line in the wrong places.
///
/// The second is that a fork contributes **one** option, never two.
void main() {
  ItineraryItem item(
    int id, {
    int sortOrder = 0,
    int? branchId,
    int? groupId,
    int day = 1,
    ItemKind kind = ItemKind.transport,
  }) => ItineraryItem(
    id: id,
    tripId: 1,
    date: DateTime(2026, 5, day),
    sortOrder: sortOrder,
    kind: kind,
    alternativeId: branchId,
    groupId: groupId,
    spansNextDay: false,
  );

  AlternativeSet aSet(int id, int sortOrder, {int day = 1}) => AlternativeSet(
    id: id,
    tripId: 1,
    date: DateTime(2026, 5, day),
    sortOrder: sortOrder,
  );

  Alternative branch(int id, int setId, int sortOrder, {bool chosen = false}) =>
      Alternative(id: id, setId: setId, sortOrder: sortOrder, chosen: chosen);

  List<int> ids(List<TrackPathRow> rows) =>
      pathEntries(rows).map((i) => i.id).toList();

  /// A loose leg, a fork, a loose leg. The options' entries sit at sortOrder 0
  /// and 1 — ahead of everything, read flat.
  final items = [
    item(1, sortOrder: 1),
    item(20, sortOrder: 0, branchId: 101),
    item(21, sortOrder: 1, branchId: 101),
    item(30, sortOrder: 0, branchId: 102),
    item(3, sortOrder: 3),
  ];
  final sets = {1: aSet(1, 2)};
  final branches = {
    1: [branch(101, 1, 0, chosen: true), branch(102, 1, 1)],
  };

  test('the fork sits in its own slot, not where its entries sort', () {
    final rows = buildTrackEntryPath(
      items: items,
      sets: sets,
      branchesBySet: branches,
    );

    expect(ids(rows), [1, 20, 21, 3]);
  });

  test('another option can be taken, and only ever one of them', () {
    final rows = buildTrackEntryPath(
      items: items,
      sets: sets,
      branchesBySet: branches,
      branchBySet: {1: 102},
    );

    expect(ids(rows), [1, 30, 3]);
  });

  test('a fork still has a row when the option it takes holds nothing', () {
    // It carries the switch: an empty option must not be a dead end.
    final rows = buildTrackEntryPath(
      items: [item(1, sortOrder: 1), item(20, branchId: 101)],
      sets: sets,
      branchesBySet: branches,
      branchBySet: {1: 102},
    );

    expect(ids(rows), [1]);
    expect(rows.whereType<TrackPathDecision>().single.selected.id, 102);
  });

  test(
    'a decision names both the option taken and the one the trip follows',
    () {
      final rows = buildTrackEntryPath(
        items: items,
        sets: sets,
        branchesBySet: branches,
        branchBySet: {1: 102},
      );
      final fork = rows.whereType<TrackPathDecision>().single;

      expect(fork.selected.id, 102);
      expect(fork.chosen.id, 101);
      expect(fork.selectedIndex, 1);
    },
  );

  test('a run sharing a ticket is listed leg by leg', () {
    // The recording is divided per leg, so a group is not one row here — unlike
    // in the timeline, where it is one slot.
    final rows = buildTrackEntryPath(
      items: [
        item(1, sortOrder: 0, groupId: 7),
        item(2, sortOrder: 1, groupId: 7),
      ],
      sets: const {},
      branchesBySet: const {},
    );

    expect(ids(rows), [1, 2]);
  });

  test('days come in order, and only days with something on them', () {
    final rows = buildTrackEntryPath(
      items: [item(2, day: 3), item(1, day: 1)],
      sets: const {},
      branchesBySet: const {},
    );

    expect(rows.whereType<TrackPathDay>().map((d) => d.day.day), [1, 3]);
  });

  test('the entry an import was started from names its option', () {
    expect(pathThrough([item(30, branchId: 102)], branches), {1: 102});
    expect(pathThrough([item(1)], branches), isEmpty);
  });
}
