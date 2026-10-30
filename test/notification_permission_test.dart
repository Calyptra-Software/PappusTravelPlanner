import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/features/map/location/notification_permission.dart';

/// The bridge's Dart half: nothing asked off Android, and a failing bridge is
/// an answer rather than an error.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.calyptra.pappus/notifications');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('off Android there is nothing to ask', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    var called = false;
    messenger.setMockMethodCallHandler(channel, (_) async {
      called = true;
      return false;
    });
    expect(await const NotificationPermissionChannel().request(), isTrue);
    expect(called, isFalse);
  });

  test('on Android the bridge answers', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'request');
      return false;
    });
    expect(await const NotificationPermissionChannel().request(), isFalse);
  });

  test('a missing or failing bridge answers no, and does not throw', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await const NotificationPermissionChannel().request(), isFalse);
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'x'),
    );
    expect(await const NotificationPermissionChannel().request(), isFalse);
  });
}
