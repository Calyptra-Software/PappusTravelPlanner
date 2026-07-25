import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money_format.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../application/cost_display_provider.dart';
import '../application/cost_providers.dart';
import '../application/currency_providers.dart';
import '../cost_reason_icons.dart';

/// A tappable chip for a single cost. The amount is always shown; the reason is
/// rendered as its icon, its text, or both, per [costReasonDisplayProvider].
/// The reason's icon is looked up from the saved reasons by label.
///
/// A transfer ([Costs.isTransfer]) has no category to show, so it draws itself
/// as its two ends instead — see [_transferChip].
class CostChip extends ConsumerWidget {
  const CostChip({super.key, required this.cost, required this.onTap});

  final Cost cost;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final display = ref.watch(costReasonDisplayProvider);
    final localeName = Localizations.localeOf(context).languageCode;
    final book = ref.watch(currencyBookProvider);
    final amount = formatMoney(
      cost.amountMinor,
      book.byId(cost.currency),
      localeName,
    );

    if (cost.isTransfer) return _transferChip(context, ref, l10n, amount);

    final showIcon = display != CostReasonDisplay.text;
    final showText = display != CostReasonDisplay.icon;

    final iconId = ref.watch(reasonIconsProvider)[cost.reason];
    final payer = cost.paidBy;
    final hasPayer = payer != null && payer.isNotEmpty;
    // Append the payer to the visible label only when text is shown; otherwise
    // keep the chip icon-only. The payer is always surfaced in the tooltip.
    var label = showText ? '${cost.reason}  $amount' : amount;
    if (showText && hasPayer) label = '$label · $payer';

    // Tooltip carries whatever the label omits: the reason when text is hidden,
    // the payer ("Paid by …") whenever one is set, and the paid state.
    final tooltipParts = <String>[
      if (!showText) cost.reason,
      if (hasPayer) l10n.costPaidByName(payer),
      if (cost.paid) l10n.costPaid,
    ];

    return ActionChip(
      avatar: showIcon ? Icon(iconForReason(iconId), size: 16) : null,
      // A trailing check marks a settled expense; the icon inherits the chip's
      // foreground colour.
      label: cost.paid
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                const SizedBox(width: 4),
                const Icon(Icons.check_circle, size: 14),
              ],
            )
          : Text(label),
      tooltip: tooltipParts.isEmpty ? null : tooltipParts.join(' · '),
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }

  /// A settlement's chip: who paid whom, and how much. Its receiver is the row's
  /// single beneficiary, so it is read from there; until that stream has loaded
  /// the chip shows the amount alone rather than a half-written arrow.
  Widget _transferChip(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String amount,
  ) {
    final from = cost.paidBy?.trim() ?? '';
    final to =
        ref
            .watch(costBeneficiariesProvider(cost.id))
            .value
            ?.firstOrNull
            ?.name ??
        '';
    final between = from.isEmpty || to.isEmpty
        ? null
        : l10n.transferBetween(from, to);

    return ActionChip(
      avatar: const Icon(Icons.swap_horiz, size: 16),
      label: Text(between == null ? amount : '$between  $amount'),
      tooltip: l10n.transfer,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }
}
