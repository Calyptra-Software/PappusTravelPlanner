import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money_format.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../application/cost_display_provider.dart';
import '../application/cost_providers.dart';
import '../cost_reason_icons.dart';

/// A tappable chip for a single cost. The amount is always shown; the reason is
/// rendered as its icon, its text, or both, per [costReasonDisplayProvider].
/// The reason's icon is looked up from the saved reasons by label.
class CostChip extends ConsumerWidget {
  const CostChip({super.key, required this.cost, required this.onTap});

  final Cost cost;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final display = ref.watch(costReasonDisplayProvider);
    final localeName = Localizations.localeOf(context).languageCode;
    final amount = formatMoney(cost.amountMinor, cost.currency, localeName);

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
    // and the payer ("Paid by …") whenever one is set.
    final tooltipParts = <String>[
      if (!showText) cost.reason,
      if (hasPayer) l10n.costPaidByName(payer),
    ];

    return ActionChip(
      avatar: showIcon ? Icon(iconForReason(iconId), size: 16) : null,
      label: Text(label),
      tooltip: tooltipParts.isEmpty ? null : tooltipParts.join(' · '),
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }
}
