import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_location.dart';
import '../../../core/providers.dart';
import '../../../core/settings/language_dialog.dart';
import '../../../core/settings/theme_mode_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../costs/presentation/cost_reasons_settings.dart';
import '../../costs/presentation/currencies_settings.dart';
import '../../costs/presentation/people_settings.dart';
import '../../itinerary/presentation/transport_modes_settings.dart';
import '../application/database_providers.dart';

/// Settings: language and database location/portability.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Desktop platforms open/create a database file at a chosen path, and so can
  /// also be reset back to the default one. Mobile (SAF) and the web have no
  /// path to choose: their database always sits at the default location, so
  /// they empty it in place and move data in and out by import/export.
  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dbPath = ref.watch(activeDbPathProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          _SectionHeader(title: l10n.language),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(currentLanguageLabel(context, ref)),
            onTap: () => showLanguageDialog(context, ref),
          ),
          const Divider(),
          _SectionHeader(title: l10n.theme),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: Text(l10n.theme),
            subtitle: Text(currentThemeModeLabel(context, ref)),
            onTap: () => showThemeModeDialog(context, ref),
          ),
          const Divider(),
          _SectionHeader(title: l10n.costReasonsSection),
          const CostReasonsSettings(),
          const Divider(),
          _SectionHeader(title: l10n.currenciesSection),
          const CurrenciesSettings(),
          const Divider(),
          _SectionHeader(title: l10n.transportModesSection),
          const TransportModesSettings(),
          const Divider(),
          _SectionHeader(title: l10n.peopleSection),
          const PeopleSettings(),
          const Divider(),
          _SectionHeader(title: l10n.databaseSection),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: Text(l10n.currentDatabase),
            subtitle: Text(dbPath, style: theme.textTheme.bodySmall),
            isThreeLine: false,
          ),
          if (_isDesktop) ...[
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(l10n.dbOpen),
              subtitle: Text(l10n.dbOpenSubtitle),
              onTap: () => _openExisting(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: Text(l10n.dbNew),
              subtitle: Text(l10n.dbNewSubtitle),
              onTap: () => _createNew(context, ref),
            ),
            // Only desktop can be pointed away from the default location, so
            // only desktop can be sent back to it.
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: Text(l10n.dbReset),
              subtitle: Text(l10n.dbResetSubtitle),
              onTap: () => _reset(context, ref),
            ),
          ] else ...[
            // The location is fixed here, so "new" can only mean "empty" —
            // no path to choose, and nothing to fall back to, hence the
            // confirmation.
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: Text(l10n.dbNewEmpty),
              subtitle: Text(l10n.dbNewEmptySubtitle),
              onTap: () => _createEmpty(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: Text(l10n.dbImport),
              subtitle: Text(l10n.dbImportSubtitle),
              onTap: () => _import(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: Text(l10n.dbExport),
              subtitle: Text(l10n.dbExportSubtitle),
              onTap: () => _export(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  // --- desktop: open / create in place ---

  Future<void> _openExisting(BuildContext context, WidgetRef ref) async {
    // Use file_selector (not file_picker) on desktop: its native GTK chooser
    // parents the dialog to the app window on Linux, so it opens in front
    // instead of behind. file_picker's XDG-portal path passes no parent handle.
    const typeGroup = XTypeGroup(label: 'SQLite', extensions: ['sqlite', 'db']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    final path = file?.path;
    if (path == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(databaseControllerProvider).openExisting(path),
      AppLocalizations.of(context).dbOpened,
    );
  }

  Future<void> _createNew(BuildContext context, WidgetRef ref) async {
    // file_selector parents the save dialog to the app window on Linux; see
    // _openExisting.
    final location = await getSaveLocation(
      suggestedName: 'travelplanner.sqlite',
    );
    final path = location?.path;
    if (path == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(databaseControllerProvider).createNew(path),
      AppLocalizations.of(context).dbCreated,
    );
  }

  // --- mobile & web: new / import / export ---

  Future<void> _createEmpty(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      context,
      title: l10n.dbNewEmptyConfirmTitle,
      body: l10n.dbNewEmptyConfirmBody,
      action: l10n.dbNewEmptyAction,
    );
    if (!confirmed || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(databaseControllerProvider).createEmpty(),
      l10n.dbNewEmptyDone,
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    // The web has no file paths, so load the picked file's bytes there instead.
    final result = await FilePicker.pickFiles(withData: kIsWeb);
    final file = result?.files.single;
    if (file == null || !context.mounted) return;

    final confirmed = await _confirm(
      context,
      title: l10n.dbImportConfirmTitle,
      body: l10n.dbImportConfirmBody,
      action: l10n.dbImportAction,
    );
    if (!confirmed || !context.mounted) return;

    final controller = ref.read(databaseControllerProvider);
    await _run(context, ref, () async {
      if (kIsWeb) {
        final bytes = file.bytes;
        if (bytes == null) throw StateError('Could not read the file.');
        await controller.importFromBytes(bytes);
      } else {
        await controller.importFrom(file.path!);
      }
    }, l10n.dbImported);
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      final bytes = await ref.read(databaseControllerProvider).exportBytes();
      if (!context.mounted) return;
      // The web storage key has no extension; the browser's download picker
      // requires one, so always suggest a `.sqlite` file name.
      final fileName = kDatabaseFileName.endsWith('.sqlite')
          ? kDatabaseFileName
          : '$kDatabaseFileName.sqlite';
      final saved = await FilePicker.saveFile(
        dialogTitle: l10n.dbExport,
        fileName: fileName,
        bytes: bytes,
      );
      if (saved == null || !context.mounted) return;
      _snack(context, l10n.dbExported);
    } catch (error) {
      if (context.mounted) _snack(context, l10n.dbError('$error'));
    }
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    await _run(
      context,
      ref,
      () => ref.read(databaseControllerProvider).resetToDefault(),
      AppLocalizations.of(context).dbResetDone,
    );
  }

  /// Asks before an irreversible swap of the whole database's contents.
  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// Runs [action], showing a success or error SnackBar.
  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      if (context.mounted) _snack(context, successMessage);
    } catch (error) {
      if (context.mounted) {
        _snack(context, AppLocalizations.of(context).dbError('$error'));
      }
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
