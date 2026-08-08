import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/app_router.dart';
import 'presentation/trip_import.dart';

/// Method channel matching the native `MainActivity` bridge, over which a
/// received `.tpt` file's bytes arrive as Base64.
const MethodChannel _channel = MethodChannel('dev.calyptra.pappus/trip_import');

/// Receiving shared files is wired only on Android; a no-op elsewhere.
bool get _supported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Uint8List? _decode(Object? arg) => arg is String ? base64Decode(arg) : null;

/// Feeds received [bytes] into the import flow once a navigator context is
/// available. Deferred to after the frame so it works from `initState` (cold
/// start) as well as a live push.
void _deliver(WidgetRef ref, Uint8List bytes) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = ref
        .read(routerProvider)
        .routerDelegate
        .navigatorKey
        .currentContext;
    if (context != null) importTripBytes(context, ref, bytes);
  });
}

/// Handles a `.tpt` file that launched the app from a cold start. Call once at
/// startup.
Future<void> handleInitialSharedTrip(WidgetRef ref) async {
  if (!_supported) return;
  final bytes = _decode(await _channel.invokeMethod<String>('getInitialTrip'));
  if (bytes != null) _deliver(ref, bytes);
}

/// Listens for `.tpt` files opened while the app is already running.
void listenSharedTrips(WidgetRef ref) {
  if (!_supported) return;
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'onTripReceived') {
      final bytes = _decode(call.arguments);
      if (bytes != null) _deliver(ref, bytes);
    }
  });
}
