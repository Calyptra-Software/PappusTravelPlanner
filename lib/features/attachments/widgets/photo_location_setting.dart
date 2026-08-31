import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../application/media_location.dart';

/// The switch that lets a photograph bring the place it was taken.
///
/// It is a switch and not a behavior for two reasons, and the second is the one
/// worth stating: it costs an Android permission the app otherwise does not
/// hold, and it costs the photo picker — the chooser people know — because that
/// picker strips a picture's coordinates whatever the app is allowed to read
/// (see `attachment_flow.dart`). Neither is a trade to make on somebody's
/// behalf, so the app makes it only when asked, and the subtitle says both
/// halves out loud rather than presenting this as free.
///
/// Drawn only where the question exists at all — the settings screen asks
/// [PhotoLocationState.supported] first, which is false on the desktop, on the
/// web, and on Android 9 and older, where a photograph arrives intact and
/// always did.
///
/// The state it shows is [PhotoLocationState.active] and not the stored switch:
/// a permission can be taken away in the system settings, and a control that
/// went on claiming the feature was running would be the app's own word against
/// the system's.
class PhotoLocationSetting extends ConsumerWidget {
  const PhotoLocationSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(photoLocationProvider);

    return SwitchListTile(
      secondary: const Icon(Icons.add_location_alt_outlined),
      title: Text(l10n.photoLocationTitle),
      subtitle: Text(l10n.photoLocationSubtitle),
      value: state.active,
      onChanged: (wanted) => wanted
          ? _enable(context, ref)
          : ref.read(photoLocationProvider.notifier).disable(),
    );
  }

  /// Asks for the permission, and says what came of it when something did.
  ///
  /// Silence on success: the switch has moved, which is the whole answer. A
  /// refusal needs a sentence, because the switch springs back and nothing else
  /// would explain why — and a *permanent* refusal needs the way out with it,
  /// since the app can no longer show the dialog itself.
  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(photoLocationProvider.notifier);
    final access = await controller.enable();
    switch (access) {
      case MediaLocationAccess.granted:
      case MediaLocationAccess.notNeeded:
      case MediaLocationAccess.unsupported:
        return;
      case MediaLocationAccess.denied:
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.photoLocationDenied)),
        );
      case MediaLocationAccess.deniedForever:
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.photoLocationBlocked),
            action: SnackBarAction(
              label: l10n.photoLocationOpenSettings,
              onPressed: ref.read(mediaLocationProvider).openSettings,
            ),
          ),
        );
    }
  }
}
