import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../transport_search/application/transport_search_controller.dart';

/// Pulls one imported leg's live (real-time) times on demand. On success the
/// refreshed actuals write to the DB and whatever shows the leg redraws with the
/// planned-vs-actual marks; a leg with no live data (already run, or schedule
/// changed) or a network failure just reports via a snackbar.
///
/// Manual only, and **one tap, one leg**: a whole-journey refresh would decide
/// for the traveller which legs to overwrite, and one leg's failure would be
/// lost among the others. The timeline tile carries one for the leg it draws;
/// the journey sheet carries one per leg card, which is the same rule with room
/// for a label.
class LiveRefreshButton extends ConsumerStatefulWidget {
  const LiveRefreshButton({super.key, required this.item});

  final ItineraryItem item;

  @override
  ConsumerState<LiveRefreshButton> createState() => _LiveRefreshButtonState();
}

class _LiveRefreshButtonState extends ConsumerState<LiveRefreshButton> {
  bool _loading = false;

  Future<void> _refresh() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final result = await ref
          .read(transportSearchControllerProvider)
          .refreshLeg(widget.item);
      // On an update the leg speaks for itself, in place; the other two
      // outcomes leave nothing on screen, so they have to be said. A
      // cancellation especially: "nothing to update" would read as "all is
      // well" about a train that is not running.
      switch (result) {
        case LegRefresh.updated:
          break;
        case LegRefresh.cancelled:
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.liveTimesCancelled),
              duration: const Duration(seconds: 6),
            ),
          );
        case LegRefresh.nothing:
          messenger.showSnackBar(SnackBar(content: Text(l10n.liveTimesNone)));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.liveTimesError)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context).liveTimesRefresh,
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync),
      onPressed: _loading ? null : _refresh,
    );
  }
}
