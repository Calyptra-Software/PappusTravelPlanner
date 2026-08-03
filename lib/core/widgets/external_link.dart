/// Opening a link that leaves the app — the data-source attribution under the
/// connection search, and the repository and issue tracker in *About*.
///
/// One helper rather than one per caller, because the part that matters is the
/// failure: a link that silently refuses is worse than none, whether it was an
/// attribution the app owes or the address a bug report is meant to go to.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';

/// Opens [url] in the platform's browser, telling the user when that fails
/// rather than leaving a tap that does nothing.
Future<void> openExternalLink(BuildContext context, String url) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (opened) return;
  messenger?.showSnackBar(SnackBar(content: Text(l10n.linkOpenFailed(url))));
}
