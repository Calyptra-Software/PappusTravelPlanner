import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart' show ItineraryItem;
import '../../../l10n/app_localizations.dart';
import '../application/transport_search_controller.dart';
import '../data/motis_client.dart' show TransportSearchException;

/// Loads the rest of an imported leg's run (the stops before boarding and after
/// getting off) on request, from the leg's card in the journey view.
///
/// One tap, one leg, like the live-times button beside it, and for the same
/// reason: the router is a donated server, and nobody asked for the runs of the
/// legs they are not looking at. On success the leg redraws with the run in
/// place and this goes away, since the view reads the database the load wrote.
///
/// A failure is said **here**, under the button, rather than in a snackbar: this
/// sits inside a modal sheet, and a snackbar raised from one is drawn behind it.
class LoadRunButton extends ConsumerStatefulWidget {
  const LoadRunButton({super.key, required this.item});

  final ItineraryItem item;

  @override
  ConsumerState<LoadRunButton> createState() => _LoadRunButtonState();
}

class _LoadRunButtonState extends ConsumerState<LoadRunButton> {
  bool _loading = false;
  String? _problem;

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _problem = null;
    });
    String? problem;
    try {
      final found = await ref
          .read(transportSearchControllerProvider)
          .loadRunStops(widget.item);
      if (!found) problem = l10n.connectionRunNotFound;
    } on TransportSearchException catch (e) {
      // The router reissues its trip ids with every timetable it loads, so an
      // id stored a while ago answers "not found": the service is no longer
      // there to be asked about, which is not a connection problem.
      problem = e.statusCode == 404
          ? l10n.connectionRunNotFound
          : l10n.connectionRunError;
    } catch (_) {
      problem = l10n.connectionRunError;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _problem = problem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final problem = _problem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.unfold_more, size: 18),
          label: Text(l10n.connectionShowRun),
          onPressed: _loading ? null : _load,
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
