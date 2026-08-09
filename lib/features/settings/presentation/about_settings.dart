/// *About*: what this build is, and where it comes from.
///
/// Five rows, each of which answers a question the app cannot answer anywhere
/// else. The version is the one a bug report is useless without — so it is the
/// exact string the app already identifies itself to the routing service with
/// (`1.1.0+2`, build number included), and it copies to the clipboard on tap,
/// because it is normally read in order to be typed somewhere else. The source
/// and issue links are the other half of that: being open source is a condition
/// of using the Transitous API, and a "report a problem" that leads nowhere is
/// how a report is not made. The address beside them is for everything an issue
/// is the wrong shape for — the `User-Agent` names the repository rather than a
/// person, so this is the one place [kAppContact] is actually reachable from.
/// The licenses are Flutter's own page, which lists every dependency's terms —
/// plus the bundled fonts', registered in `core/licenses.dart`, since those ship
/// inside the binary too.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_info.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/external_link.dart';
import '../../../l10n/app_localizations.dart';

/// The square mark, not the lockup: the licence page prints the application's
/// name directly beneath the icon, and the lockup carries that name itself.
const String _markAsset = 'assets/logo/pappus_mark.png';

class AboutSettings extends ConsumerWidget {
  const AboutSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final version = ref.watch(appVersionProvider);

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.aboutVersion),
          subtitle: Text(version, style: theme.textTheme.bodySmall),
          trailing: const Icon(Icons.copy_outlined, size: 18),
          onTap: () => _copyVersion(context, version),
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: Text(l10n.aboutSourceCode),
          subtitle: Text(kAppRepositoryUrl, style: theme.textTheme.bodySmall),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => openExternalLink(context, kAppRepositoryUrl),
        ),
        ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: Text(l10n.aboutReportIssue),
          subtitle: Text(kAppIssuesUrl, style: theme.textTheme.bodySmall),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => openExternalLink(context, kAppIssuesUrl),
        ),
        ListTile(
          leading: const Icon(Icons.mail_outline),
          title: Text(l10n.aboutContact),
          subtitle: Text(kAppContact, style: theme.textTheme.bodySmall),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => openExternalLink(context, 'mailto:$kAppContact'),
        ),
        ListTile(
          leading: const Icon(Icons.article_outlined),
          title: Text(l10n.aboutLicenses),
          subtitle: Text(
            l10n.aboutLicensesSubtitle,
            style: theme.textTheme.bodySmall,
          ),
          onTap: () => showLicensePage(
            context: context,
            applicationName: l10n.appTitle,
            applicationVersion: version,
            applicationIcon: const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Image(
                image: AssetImage(_markAsset),
                width: 72,
                height: 72,
              ),
            ),
            applicationLegalese: kAppLegalese,
          ),
        ),
      ],
    );
  }

  Future<void> _copyVersion(BuildContext context, String version) async {
    final message = AppLocalizations.of(context).aboutVersionCopied;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: version));
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
