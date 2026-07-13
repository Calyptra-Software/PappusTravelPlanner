import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current time, re-emitted on every minute boundary — the heartbeat behind
/// the timeline's "you are here" mark.
///
/// Ticks on the boundary rather than every 60s from whenever it was first
/// listened to, so the displayed clock changes in step with the wall clock.
/// `autoDispose` so nothing ticks while no screen is showing a live timeline.
final nowProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  Timer? timer;

  void schedule() {
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    timer = Timer(nextMinute.difference(now), () {
      controller.add(DateTime.now());
      schedule();
    });
  }

  controller.add(DateTime.now());
  schedule();
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});
