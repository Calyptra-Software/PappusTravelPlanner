/// Asking whether the recording's notification may be shown.
///
/// A recording on Android runs in a foreground service, and the service posts
/// its notification whether or not this is granted: Android 13 and later only
/// keep it out of the drawer without `POST_NOTIFICATIONS`, and list the running
/// service in the quick settings' task manager instead. So the answer changes
/// where the recording is announced and never whether it runs, and the recorder
/// asks on the record press and carries on whatever comes back.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Android side of the question. See `NotificationPermission.kt`.
///
/// A class so a test can stand in for the platform
/// ([notificationPermissionProvider]), which is the only way the recorder's
/// asking is exercised off a phone.
class NotificationPermissionChannel {
  const NotificationPermissionChannel([
    this._channel = const MethodChannel('dev.calyptra.pappus/notifications'),
  ]);

  final MethodChannel _channel;

  /// Shows the system dialog where there is one to show, and answers whether
  /// notifications may be posted.
  ///
  /// True wherever there is nothing to ask: anywhere but Android, below
  /// Android 13, and when already granted. A failing bridge answers false
  /// rather than throwing, since nothing waiting on this may fail because of
  /// it.
  Future<bool> request() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _channel.invokeMethod<bool>('request') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

final notificationPermissionProvider = Provider<NotificationPermissionChannel>(
  (ref) => const NotificationPermissionChannel(),
);
