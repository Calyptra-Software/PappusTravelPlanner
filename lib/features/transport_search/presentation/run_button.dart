import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Shows or puts away the rest of a leg's run, in the journey's list and on its
/// map, from the leg's card in the journey screen.
///
/// Offered whether or not the run has been loaded before: what was loaded is
/// shown again without asking anybody, and put away again by the same button,
/// since often it is a journey's own route somebody wants to look at. The
/// screen owns what it does ([onPressed]) and whether it is under way
/// ([loading]); this only draws it.
///
/// A [problem] is said here, under the button, rather than in a snackbar: the
/// screen's panel is where it was asked, and the map takes the rest of the
/// screen.
class RunButton extends StatelessWidget {
  const RunButton({
    super.key,
    required this.shown,
    required this.onPressed,
    this.loading = false,
    this.problem,
  });

  /// Whether the run is on screen now, which turns the button into the one
  /// that puts it away.
  final bool shown;
  final VoidCallback onPressed;
  final bool loading;
  final String? problem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final problem = this.problem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
          icon: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(shown ? Icons.unfold_less : Icons.unfold_more, size: 18),
          label: Text(shown ? l10n.connectionHideRun : l10n.connectionShowRun),
          onPressed: loading ? null : onPressed,
        ),
        if (problem != null)
          Text(
            problem,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      ],
    );
  }
}
