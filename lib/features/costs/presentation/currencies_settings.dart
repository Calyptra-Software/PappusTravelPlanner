import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money_format.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/daos/currency_dao.dart';
import '../../../l10n/app_localizations.dart';
import '../application/currency_providers.dart';

/// Settings block to manage the currencies an expense can be recorded in:
/// reorder them, add new ones, edit any of them (built-ins included), pick which
/// one is the **base**, and give the others their exchange rate against it.
///
/// The money counterpart to `TransportModesSettings`, with one difference that
/// runs through the whole screen: a currency in use cannot be deleted. A leg can
/// lose its transport mode and still be a leg, but an amount with no currency
/// means nothing — so the row says what still uses it instead.
class CurrenciesSettings extends ConsumerWidget {
  const CurrenciesSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final currencies = ref.watch(currenciesProvider).value ?? const [];
    final counts = ref.watch(currencyCostCountsProvider).value ?? const {};
    final base = currencies.where((c) => c.isBase).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.currencyBaseHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (currencies.isEmpty)
          ListTile(
            title: Text(
              l10n.noCurrencies,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            // newIndex is already adjusted for the removal at oldIndex
            // (onReorderItem semantics), so it drops straight in.
            onReorderItem: (oldIndex, newIndex) {
              final ids = [for (final c in currencies) c.id];
              ids.insert(newIndex, ids.removeAt(oldIndex));
              ref.read(currencyControllerProvider).reorderCurrencies(ids);
            },
            children: [
              for (final (index, currency) in currencies.indexed)
                ListTile(
                  key: ValueKey(currency.id),
                  leading: IconButton(
                    icon: Icon(
                      currency.isBase ? Icons.star : Icons.star_border,
                      color: currency.isBase ? theme.colorScheme.primary : null,
                    ),
                    tooltip: currency.isBase
                        ? l10n.currencyBase
                        : l10n.currencyMakeBase,
                    onPressed: currency.isBase
                        ? null
                        : () => _makeBase(context, ref, currency),
                  ),
                  title: Text('${currency.symbol}  ${currency.code}'),
                  subtitle: Text(
                    _subtitle(l10n, currency, base, counts[currency.id] ?? 0),
                  ),
                  onTap: () => _editCurrency(context, ref, currency, base),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: theme.colorScheme.error,
                        tooltip: l10n.delete,
                        onPressed: () => _confirmDelete(context, ref, currency),
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.currencyAdd),
              onPressed: () => _addCurrency(context, ref, base),
            ),
          ),
        ),
      ],
    );
  }

  /// The second line of a row: the base says so, another currency shows its rate
  /// against the base (or that it has none), and either way how many expenses
  /// depend on it — which is what decides whether it can still be deleted.
  String _subtitle(
    AppLocalizations l10n,
    CurrencyRow currency,
    CurrencyRow? base,
    int costCount,
  ) {
    final usage = costCount == 0 ? null : l10n.currencyInUse(costCount);
    final rate = currency.isBase
        ? l10n.currencyBase
        : (currency.rateMicros == null || base == null
              ? l10n.currencyRateNone
              : l10n.currencyRateExplains(
                  currency.code,
                  formatRate(currency.rateMicros!),
                  base.code,
                ));
    return usage == null ? rate : '$rate · $usage';
  }

  Future<void> _addCurrency(
    BuildContext context,
    WidgetRef ref,
    CurrencyRow? base,
  ) async {
    final existing = ref.read(currenciesProvider).value ?? const [];
    final result = await _showCurrencyDialog(
      context,
      title: AppLocalizations.of(context).currencyAddTitle,
      baseCode: base?.code,
      takenCodes: {for (final c in existing) c.code.toUpperCase()},
    );
    if (result == null) return;
    await ref
        .read(currencyControllerProvider)
        .addCurrency(
          code: result.code,
          symbol: result.symbol,
          rateMicros: result.rateMicros,
        );
  }

  Future<void> _editCurrency(
    BuildContext context,
    WidgetRef ref,
    CurrencyRow currency,
    CurrencyRow? base,
  ) async {
    final existing = ref.read(currenciesProvider).value ?? const [];
    final result = await _showCurrencyDialog(
      context,
      title: AppLocalizations.of(context).currencyEditTitle,
      baseCode: base?.code,
      // Its own code is not "taken" — only the others'.
      takenCodes: {
        for (final c in existing)
          if (c.id != currency.id) c.code.toUpperCase(),
      },
      initial: currency,
      // The base's rate is 1 by definition, so there is nothing to edit.
      showRate: !currency.isBase,
    );
    if (result == null) return;
    final controller = ref.read(currencyControllerProvider);
    await controller.editCurrency(
      currency.id,
      code: result.code,
      symbol: result.symbol,
    );
    if (!currency.isBase) {
      await controller.setRate(currency.id, result.rateMicros);
    }
  }

  /// Moves the base. Warns first when the target has no rate of its own, since
  /// the other rates then have nothing to be re-expressed against and are lost.
  Future<void> _makeBase(
    BuildContext context,
    WidgetRef ref,
    CurrencyRow currency,
  ) async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(currencyControllerProvider);
    if (await controller.rebaseClearsRates(currency.id)) {
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.currencyRebaseWarnTitle),
          content: Text(l10n.currencyRebaseWarnBody(currency.code)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.currencyMakeBase),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await controller.setBase(currency.id);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CurrencyRow currency,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // Refuse up front rather than opening a confirmation the delete would then
    // reject: the reason is the answer, not the question.
    if (currency.isBase) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.currencyDeleteBlockedBase)));
      return;
    }
    final inUse =
        (ref.read(currencyCostCountsProvider).value ?? const {})[currency.id] ??
        0;
    if (inUse > 0) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              l10n.currencyDeleteBlockedInUse(currency.code, inUse),
            ),
          ),
        );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.currencyDeleteConfirmTitle),
        content: Text(l10n.currencyDeleteConfirmBody(currency.code)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(currencyControllerProvider).deleteCurrency(currency.id);
    } on CurrencyInUseException catch (error) {
      // The counts stream could have moved on between the check and the tap.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error.isBase
                  ? l10n.currencyDeleteBlockedBase
                  : l10n.currencyDeleteBlockedInUse(
                      currency.code,
                      error.costCount,
                    ),
            ),
          ),
        );
    }
  }
}

/// What the add/edit dialog hands back.
typedef _CurrencyEdit = ({String code, String symbol, int? rateMicros});

/// The add/edit form: code, symbol and — for anything but the base — the rate
/// against the base. Three fields in one dialog rather than three prompts,
/// because a currency is not useful until all three are settled.
Future<_CurrencyEdit?> _showCurrencyDialog(
  BuildContext context, {
  required String title,
  required String? baseCode,
  required Set<String> takenCodes,
  CurrencyRow? initial,
  bool showRate = true,
}) {
  return showDialog<_CurrencyEdit>(
    context: context,
    builder: (context) => _CurrencyDialog(
      title: title,
      baseCode: baseCode,
      takenCodes: takenCodes,
      initial: initial,
      showRate: showRate,
    ),
  );
}

class _CurrencyDialog extends StatefulWidget {
  const _CurrencyDialog({
    required this.title,
    required this.baseCode,
    required this.takenCodes,
    required this.initial,
    required this.showRate,
  });

  final String title;
  final String? baseCode;
  final Set<String> takenCodes;
  final CurrencyRow? initial;
  final bool showRate;

  @override
  State<_CurrencyDialog> createState() => _CurrencyDialogState();
}

class _CurrencyDialogState extends State<_CurrencyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _codeController = TextEditingController(
    text: widget.initial?.code ?? '',
  );
  late final _symbolController = TextEditingController(
    text: widget.initial?.symbol ?? '',
  );
  late final _rateController = TextEditingController(
    text: widget.initial?.rateMicros == null
        ? ''
        : formatRate(widget.initial!.rateMicros!),
  );

  @override
  void dispose() {
    _codeController.dispose();
    _symbolController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final code = _codeController.text.trim().toUpperCase();
    final symbol = _symbolController.text.trim();
    Navigator.pop(context, (
      code: code,
      // A currency with no symbol of its own simply shows its code — plenty
      // have no glyph, and a blank prefix would leave the amount unlabelled.
      symbol: symbol.isEmpty ? code : symbol,
      rateMicros: widget.showRate
          ? parseRateToMicros(_rateController.text)
          : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final baseCode = widget.baseCode;
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _codeController,
              autofocus: widget.initial == null,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [LengthLimitingTextInputFormatter(8)],
              decoration: InputDecoration(
                labelText: l10n.currencyCode,
                hintText: l10n.currencyCodeHint,
              ),
              // The rate field's helper names this code ("what one JPY is worth
              // in EUR"), so it has to follow what is being typed.
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final code = (value ?? '').trim().toUpperCase();
                if (code.isEmpty) return l10n.currencyCodeRequired;
                if (widget.takenCodes.contains(code)) {
                  return l10n.currencyCodeTaken;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _symbolController,
              inputFormatters: [LengthLimitingTextInputFormatter(8)],
              decoration: InputDecoration(
                labelText: l10n.currencySymbol,
                hintText: l10n.currencySymbolHint,
              ),
            ),
            if (widget.showRate && baseCode != null) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _rateController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: l10n.currencyRate,
                  helperText: l10n.currencyRateHelp(
                    _codeController.text.trim().isEmpty
                        ? l10n.currencyCode
                        : _codeController.text.trim().toUpperCase(),
                    baseCode,
                  ),
                  helperMaxLines: 3,
                ),
                // Empty is allowed and means "no rate": the app then declines
                // to convert rather than inventing a number.
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  return parseRateToMicros(text) == null
                      ? l10n.currencyRateInvalid
                      : null;
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
