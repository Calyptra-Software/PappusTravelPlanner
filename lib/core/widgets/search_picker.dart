import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// One row of a search picker: the value it yields — which is also the text it
/// is shown and matched by — and an optional leading icon.
class SearchPickerOption {
  const SearchPickerOption(this.value, {this.icon});

  final String value;
  final IconData? icon;
}

/// What the user settled on in a search picker. A `null` future means the sheet
/// was dismissed and nothing should change; a result whose [value] is null means
/// the "none" row was picked — an explicit "leave this empty".
class SearchPickerResult {
  const SearchPickerResult(this.value);

  final String? value;
}

/// Shows a searchable list of [options] and resolves to what the user picked.
///
/// The sheet is one field over one list: typing filters the list, and — unless
/// [allowCreate] is off — a query that matches nothing offers a row to create
/// it. Searching for an existing entry and adding a new one are therefore the
/// same gesture, which keeps a long roster of categories or people usable.
///
/// [selected] is ticked in the list. [noneLabel], when given, adds a leading row
/// that clears the choice (a result whose value is null).
Future<SearchPickerResult?> showSearchPicker(
  BuildContext context, {
  required String title,
  required List<SearchPickerOption> options,
  String? selected,
  String? noneLabel,
  bool allowCreate = true,
  TextCapitalization textCapitalization = TextCapitalization.sentences,
}) {
  return showSearchPickerSheet(
    context,
    (context) => SearchPickerSheet(
      title: title,
      options: options,
      selected: selected,
      noneLabel: noneLabel,
      allowCreate: allowCreate,
      textCapitalization: textCapitalization,
    ),
  );
}

/// Shows a [SearchPickerSheet] built by [builder] — for callers that must build
/// their options against live data (e.g. inside a Riverpod `Consumer`) rather
/// than hand them over up front, as [showSearchPicker] does.
Future<SearchPickerResult?> showSearchPickerSheet(
  BuildContext context,
  WidgetBuilder builder,
) {
  return showModalBottomSheet<SearchPickerResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: builder,
  );
}

class SearchPickerSheet extends StatefulWidget {
  const SearchPickerSheet({
    super.key,
    required this.title,
    required this.options,
    this.selected,
    this.noneLabel,
    this.allowCreate = true,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final String title;
  final List<SearchPickerOption> options;

  /// The value currently chosen, ticked in the list.
  final String? selected;

  /// Label of a leading row that clears the choice, if the field allows none.
  final String? noneLabel;

  /// Whether a query matching no option may be added as a new entry.
  final bool allowCreate;

  /// Capitalization of the search box — it doubles as the name of a new entry.
  final TextCapitalization textCapitalization;

  @override
  State<SearchPickerSheet> createState() => _SearchPickerSheetState();
}

class _SearchPickerSheetState extends State<SearchPickerSheet> {
  final _controller = TextEditingController();

  String _query = '';

  /// From this many options on, the sheet opens with the keyboard up: a long
  /// list is what searching is for, while a handful of options is faster to read
  /// than to type — and would only be hidden behind the keyboard.
  static const _autofocusFrom = 8;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(String? value) =>
      Navigator.of(context).pop(SearchPickerResult(value));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);

    final query = _query.trim();
    final needle = query.toLowerCase();
    final matches = query.isEmpty
        ? widget.options
        : widget.options
              .where((o) => o.value.toLowerCase().contains(needle))
              .toList();
    // Offer to create only what isn't there already — an exact match is a hit,
    // not a new entry, even when the list is filtered down to it.
    final showCreate =
        widget.allowCreate &&
        query.isNotEmpty &&
        !widget.options.any((o) => o.value.toLowerCase() == needle);
    final noneLabel = widget.noneLabel;
    // The "none" row is not searchable text, so it only shows on the full list.
    final showNone = noneLabel != null && query.isEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(widget.title, style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _controller,
                autofocus: widget.options.length >= _autofocusFrom,
                textCapitalization: widget.textCapitalization,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.search,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.cancel,
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                onChanged: (value) => setState(() => _query = value),
                // Enter takes the obvious choice: the new entry being typed, or
                // the single option left standing.
                onSubmitted: (_) {
                  if (showCreate) return _pick(query);
                  if (matches.length == 1) return _pick(matches.single.value);
                },
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                // The last row must clear the Android system navigation-bar
                // inset (padding.bottom) — the sheet's SafeArea guards the top
                // and sides but leaves the bottom to us. With the keyboard up,
                // padding.bottom collapses to 0 (viewInsets covers it above).
                padding: EdgeInsets.only(
                  top: 8,
                  bottom: 12 + media.padding.bottom,
                ),
                children: [
                  if (showCreate)
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: Text(l10n.searchAdd(query)),
                      onTap: () => _pick(query),
                    ),
                  if (showNone)
                    ListTile(
                      leading: const Icon(Icons.remove_circle_outline),
                      title: Text(noneLabel),
                      selected: widget.selected == null,
                      onTap: () => _pick(null),
                    ),
                  for (final option in matches)
                    ListTile(
                      leading: Icon(option.icon),
                      title: Text(option.value),
                      selected: option.value == widget.selected,
                      trailing: option.value == widget.selected
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => _pick(option.value),
                    ),
                  if (matches.isEmpty && !showCreate)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Text(
                        l10n.searchNoMatches,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
