import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import '../../l10n/app_localizations.dart';
import 'presentation/trip_import.dart';
import 'received_trip_file.dart';

/// Method channel matching the native `MainActivity` bridge, over which a
/// received `.tpt` file arrives as the path of a copy in the app's cache.
const MethodChannel _channel = MethodChannel('dev.calyptra.pappus/trip_import');

/// Receiving shared files is wired only on Android; a no-op elsewhere.
bool get _supported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Runs [act] with a navigator context once one is available. Deferred to
/// after the frame so it works from `initState` (cold start) as well as a live
/// push.
void _whenReady(WidgetRef ref, void Function(BuildContext context) act) {
  WidgetsBinding.instance
    ..addPostFrameCallback((_) {
      final context = ref
          .read(routerProvider)
          .routerDelegate
          .navigatorKey
          .currentContext;
      if (context != null) act(context);
    })
    // A post-frame callback does not ask for a frame. Copying a large file
    // takes long enough for the screen to fall idle, and on an idle screen
    // the import would wait for whatever happens to redraw next.
    ..ensureVisualUpdate();
}

void _reportFailure(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AppLocalizations.of(context).importTripFailed)),
  );
}

/// Reads the received copy at [path] and feeds it into the import flow.
Future<void> _receive(WidgetRef ref, String path) async {
  final Uint8List bytes;
  try {
    bytes = await takeReceivedTrip(path);
  } on Exception {
    _whenReady(ref, _reportFailure);
    return;
  }
  _whenReady(ref, (context) => importTripBytes(context, ref, bytes));
}

/// Handles a `.tpt` file that launched the app from a cold start. Call once at
/// startup.
Future<void> handleInitialSharedTrip(WidgetRef ref) async {
  if (!_supported) return;
  final String? path;
  try {
    path = await _channel.invokeMethod<String>('getInitialTrip');
  } on PlatformException {
    _whenReady(ref, _reportFailure);
    return;
  }
  if (path != null) await _receive(ref, path);
}

/// Listens for `.tpt` files opened while the app is already running.
void listenSharedTrips(WidgetRef ref) {
  if (!_supported) return;
  _channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'onTripReceived':
        final path = call.arguments;
        if (path is String) await _receive(ref, path);
      case 'onTripFailed':
        _whenReady(ref, _reportFailure);
    }
  });
}
