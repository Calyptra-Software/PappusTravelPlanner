import 'package:latlong2/latlong.dart';
import 'package:travelplanner/features/attachments/application/media_location.dart';

/// The platform, standing still.
///
/// The real [MediaLocationChannel] is a method channel into
/// `MediaLocationBridge.kt` — a permission dialog and a read of a file the
/// system will only serve to a process that holds it, neither of which a test
/// can reach. This stands in for it wherever the *app's* behaviour around the
/// answer is what is being exercised; the channel's own mapping of that answer
/// is tested against a mocked messenger in `media_location_test.dart`.
///
/// It records rather than only answers: what the flow asked about is half of
/// what is worth asserting — a switch that is off must ask nothing at all.
class FakeMediaLocation extends MediaLocationChannel {
  FakeMediaLocation({this.access = MediaLocationAccess.granted, this.position});

  /// What the platform says to every question about the permission.
  final MediaLocationAccess access;

  /// What [readLocation] finds, when it is allowed to look.
  final LatLng? position;

  /// Every URI asked about, in order.
  final List<String> asked = [];

  /// How often the way out of a permanent refusal was taken.
  int settingsOpened = 0;

  @override
  Future<MediaLocationAccess> status() async => access;

  @override
  Future<MediaLocationAccess> request() async => access;

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }

  @override
  Future<LatLng?> readLocation(String uri) async {
    asked.add(uri);
    return access == MediaLocationAccess.granted ? position : null;
  }
}
