import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/clock.dart';

/// The heartbeat behind the timeline's "you are here" mark.
///
/// Two things are worth standing on: it says what time it is at once — a screen
/// must not wait up to a minute to learn where the day has got to — and it stops
/// when nothing is listening, which is the whole reason it is `autoDispose`. A
/// timer that outlived its last listener would tick on behind every closed
/// screen, and the binding reports exactly that as a failure, so the second is
/// tested by the absence of one rather than by an assertion.
void main() {
  testWidgets('emits at once, and again on the minute boundary', (
    tester,
  ) async {
    final container = ProviderContainer();
    final seen = <DateTime>[];
    final subscription = container.listen(nowProvider, (_, next) {
      if (next.value case final at?) seen.add(at);
    }, fireImmediately: true);

    await tester.pump();
    expect(seen, hasLength(1), reason: 'nothing waits for the next minute');

    // The wait is to the *boundary*, never a flat sixty seconds from whenever
    // the provider was first listened to, so a minute of any length crosses it.
    await tester.pump(const Duration(minutes: 1));
    expect(seen.length, greaterThanOrEqualTo(2));

    // Closed and disposed inside the test body rather than from
    // `addTearDown`: the binding checks for pending timers *before* tear-downs
    // run, so the next tick would be reported as a leak.
    subscription.close();
    container.dispose();
    await tester.pump();
  });

  testWidgets('stops ticking when the last listener goes', (tester) async {
    final container = ProviderContainer();
    final subscription = container.listen(nowProvider, (_, _) {});
    await tester.pump();

    subscription.close();
    container.dispose();
    await tester.pump();

    // Nothing is asserted in words: a timer left running would be reported by
    // the binding as still pending after the tree was disposed, and this test
    // would fail on that alone.
    await tester.pump(const Duration(minutes: 5));
  });
}
