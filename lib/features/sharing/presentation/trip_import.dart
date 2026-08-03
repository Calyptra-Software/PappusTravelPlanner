import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../trip_bundle.dart';

/// Desktop platforms use file_selector (like the database open in settings) so
/// the chooser parents to the app window on Linux; mobile/web use file_picker.
bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Lets the user pick a shared `.tpt` trip file and imports it as a new trip.
/// `.tpt` has no registered MIME type, so any file is accepted and validated by
/// parsing.
Future<void> pickAndImportTrip(BuildContext context, WidgetRef ref) async {
  Uint8List? bytes;
  if (_isDesktop) {
    const typeGroup = XTypeGroup(
      label: 'Travel Planner trip',
      extensions: [tripBundleExtension],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    bytes = file == null ? null : await file.readAsBytes();
  } else {
    // Read through the picked file rather than off a path, so the one branch
    // works on web and native alike.
    final result = await FilePicker.pickFiles();
    bytes = await result?.files.single.readAsBytes();
  }
  if (bytes == null || !context.mounted) return;
  await importTripBytes(context, ref, bytes);
}

/// Imports a shared trip bundle's [bytes] as a new trip and opens it. The single
/// entry point for both the manual file picker and opening a received `.tpt`
/// file, so both surface the same localized errors: an invalid file, or one
/// shared from a newer app version.
Future<void> importTripBytes(
  BuildContext context,
  WidgetRef ref,
  Uint8List bytes,
) async {
  final l10n = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final id = await ref.read(repositoryProvider).importTrip(bytes);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.importTripSuccess)));
    router.go('/trip/$id');
  } on IncompatibleBundleException {
    messenger.showSnackBar(SnackBar(content: Text(l10n.importTripTooNew)));
  } on FormatException {
    messenger.showSnackBar(SnackBar(content: Text(l10n.importTripInvalid)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.importTripFailed)));
  }
}
