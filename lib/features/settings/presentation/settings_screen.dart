import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/providers.dart';
import '../../../core/settings/language_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../application/database_providers.dart';

/// Settings: language and database location/portability.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Desktop platforms open/create a database file in place; mobile uses
  /// import/export (SAF) instead.
  bool get _isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

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
          ] else ...[
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
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: Text(l10n.dbReset),
            subtitle: Text(l10n.dbResetSubtitle),
            onTap: () => _reset(context, ref),
          ),
        ],
      ),
    );
  }

  // --- desktop: open / create in place ---

  Future<void> _openExisting(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['sqlite', 'db'],
    );
    final path = result?.files.single.path;
    if (path == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(databaseControllerProvider).openExisting(path),
      AppLocalizations.of(context).dbOpened,
    );
  }

  Future<void> _createNew(BuildContext context, WidgetRef ref) async {
    final path = await FilePicker.saveFile(
      dialogTitle: AppLocalizations.of(context).dbNew,
      fileName: 'travelplanner.sqlite',
    );
    if (path == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(databaseControllerProvider).createNew(path),
      AppLocalizations.of(context).dbCreated,
    );
  }

  // --- mobile: import / export via SAF ---

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.pickFiles();
    final path = result?.files.single.path;
    if (path == null) return;
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.dbImportConfirmTitle),
        content: Text(l10n.dbImportConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.dbImportAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await _run(
      context,
      ref,
      () => ref.read(databaseControllerProvider).importFrom(path),
      l10n.dbImported,
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      final file = await ref.read(databaseControllerProvider).exportFile();
      final bytes = await file.readAsBytes();
      if (!context.mounted) return;
      final saved = await FilePicker.saveFile(
        dialogTitle: l10n.dbExport,
        fileName: p.basename(file.path),
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
