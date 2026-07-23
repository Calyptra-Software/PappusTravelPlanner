import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/money_format.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/tables.dart';
import '../../../core/widgets/text_prompt_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../application/item_clipboard.dart';
import '../day_blocks.dart';
import '../now_marker.dart';
import 'now_line.dart';
import 'put_down_chip.dart';
import 'timeline_tile.dart';

/// An option's name: its own label, or its position spelled as a letter
/// ("Option B") when it has none. Top-level so anything that has to name an
/// option away from the card — a message about where an entry just landed, say
/// — names it the same way the card does.
String optionLabel(AppLocalizations l10n, Alternative branch, int index) {
  final label = branch.label;
  if (label != null && label.isNotEmpty) return label;
  return l10n.optionLetter(String.fromCharCode(65 + index));
}

/// A decision in the timeline: the competing options for one stretch of a day,
/// shown one at a time and **swiped** through left/right (dragged with the mouse
/// on desktop and web, or stepped with the arrow keys / the chevrons).
///
/// Swiping only *browses*: it is deliberately not the same gesture as choosing,
/// so looking at an option never moves the trip's money. Committing is the
/// explicit "use this option" button — which is also how a decision is settled
/// after the fact: the option you actually took is simply the one you choose.
///
/// Because a pager can't show two options side by side, the indicator row under
/// it carries every option's price — the comparison a decision exists for stays
/// visible without swiping.
class AlternativeCard extends ConsumerStatefulWidget {
  const AlternativeCard({
    super.key,
    required this.block,
    required this.accent,
    required this.groups,
    required this.costsByItem,
    required this.costsByGroup,
    required this.localeName,
    required this.onTapItem,
    required this.onTapCost,
    required this.onAddPlace,
    required this.onAddTransport,
    required this.onQuickAddPlace,
    required this.onReorderBranch,
    required this.held,
    required this.onPutDown,
    this.dragHandle,
    this.isNow = false,
    this.nowLineMinutes,
    this.nowMinutes,
  });

  /// The entry currently picked up, or null. Each option offers to take it —
  /// the option on screen, so the destination is the one you are looking at.
  final Held? held;
  final void Function(int alternativeId) onPutDown;

  final DecisionBlock block;
  final Color accent;
  final Map<int, ItemGroup> groups;
  final Map<int, List<Cost>> costsByItem;
  final Map<int, List<Cost>> costsByGroup;
  final String localeName;
  final ValueChanged<ItineraryItem> onTapItem;
  final ValueChanged<Cost> onTapCost;

  /// Adds an entry to the branch with the given id (the one on screen).
  final void Function(int alternativeId) onAddPlace;
  final void Function(int alternativeId) onAddTransport;

  /// Adds a place named after where the branch's last leg leaves you, with no
  /// form step — the "you just arrived here" chip, as on the day itself.
  final void Function(int alternativeId, String location) onQuickAddPlace;

  /// Reorders the items *within* one branch.
  final void Function(List<ItineraryItem> items, int oldIndex, int newIndex)
  onReorderBranch;

  /// Handle for dragging the whole decision to another slot in its day.
  final Widget? dragHandle;

  /// Whether the decision — that is, the option it currently follows — is under
  /// way right now. An option not chosen is not what the trip is doing, so it can
  /// never be "now", however it is priced or swiped to.
  final bool isNow;

  /// When set, the current time: the now-line is drawn above the card.
  final int? nowLineMinutes;

  /// The current time, when this decision sits on today. Places the mark within
  /// the chosen option: the entry under way, or — when [isNow] but now falls
  /// between two of its entries — the now-line between them. Null on any other
  /// day.
  final int? nowMinutes;

  @override
  ConsumerState<AlternativeCard> createState() => _AlternativeCardState();
}

class _AlternativeCardState extends ConsumerState<AlternativeCard> {
  late PageController _controller;
  late int _page;

  /// Measured height of each branch's content, so the card grows and shrinks as
  /// you swipe instead of every branch being padded to the tallest one.
  final _heights = <int, double>{};

  /// Keyboard focus, which the arrow keys need. Clicking the card takes it (see
  /// [build]) — without that the shortcuts would only be reachable by tabbing
  /// blindly through the page, which is no way to offer a keyboard path.
  final _focusNode = FocusNode(debugLabel: 'AlternativeCard');
  bool _focused = false;

  List<Alternative> get _branches => widget.block.branches;

  @override
  void initState() {
    super.initState();
    // Open on the chosen branch: the plan as it stands is what you expect to see.
    _page = _branches.indexWhere((b) => b.id == widget.block.chosen.id);
    if (_page < 0) _page = 0;
    _controller = PageController(initialPage: _page);
  }

  @override
  void didUpdateWidget(AlternativeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A branch may have been deleted while it was on screen.
    if (_page >= _branches.length) {
      _page = _branches.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(_page);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= _branches.length) return;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  /// The costs of everything in a branch: its items' own costs plus each group's
  /// shared cost counted once (a group never straddles two branches).
  List<Cost> _branchCosts(List<ItineraryItem> items) {
    final groupIds = {
      for (final item in items)
        if (item.groupId != null) item.groupId!,
    };
    return [
      for (final item in items) ...?widget.costsByItem[item.id],
      for (final groupId in groupIds) ...?widget.costsByGroup[groupId],
    ];
  }

  /// Where an option's last entry leaves you, when that entry is a leg with a
  /// destination — the name the "you just arrived here" chip offers to add as a
  /// place, so it isn't typed twice. Null when the option ends on a place (you
  /// are already there) or has nowhere to arrive.
  String? _arrival(List<ItineraryItem> items) {
    if (items.isEmpty) return null;
    final last = items.last;
    if (last.kind != ItemKind.transport) return null;
    final destination = last.toLocation?.trim();
    return (destination == null || destination.isEmpty) ? null : destination;
  }

  String _branchLabel(AppLocalizations l10n, int index) =>
      optionLabel(l10n, _branches[index], index);

  /// Interpolates between the two pages the swipe is between, so the card's
  /// height follows the finger rather than jumping when the page settles.
  ///
  /// Only meaningful if it is re-read on every frame of the scroll — see the
  /// [AnimatedBuilder] in [build]. Sampling it once per page change would freeze
  /// the card at whatever height the interpolation had reached mid-swipe.
  double get _viewportHeight {
    final current = _heights[_page] ?? 0;
    if (!_controller.hasClients || !_controller.position.hasContentDimensions) {
      return current;
    }
    final page = _controller.page ?? _page.toDouble();
    final lower = page.floor().clamp(0, _branches.length - 1);
    final upper = page.ceil().clamp(0, _branches.length - 1);
    return lerpDouble(
          _heights[lower] ?? current,
          _heights[upper] ?? current,
          page - lower,
        ) ??
        current;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final set = widget.block.set;
    final label = (set.label != null && set.label!.isNotEmpty)
        ? set.label!
        : l10n.decisionDefaultLabel;

    // Clicking anywhere on the card gives it the keyboard, so the arrow keys
    // step through the options — the desktop counterpart of putting a finger on
    // it. A Listener rather than a gesture detector: it must not enter the
    // gesture arena, or it would compete with the pager's drag and the tiles'
    // taps.
    final card = Listener(
      onPointerDown: (_) => _focusNode.requestFocus(),
      child: FocusableActionDetector(
        focusNode: _focusNode,
        onShowFocusHighlight: (focused) {
          if (focused != _focused) setState(() => _focused = focused);
        },
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowLeft): _StepIntent(-1),
          SingleActivator(LogicalKeyboardKey.arrowRight): _StepIntent(1),
        },
        actions: {
          _StepIntent: CallbackAction<_StepIntent>(
            onInvoke: (intent) => _goTo(_page + intent.delta),
          ),
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: _focused ? 0.09 : 0.05),
            // The ring says "the arrows land here" — a focusable card with no
            // way to see it has the focus is a keyboard path no one can find.
            border: Border.all(
              color: widget.accent.withValues(alpha: _focused ? 1 : 0.4),
              width: _focused ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(theme, l10n, label),
              // The pager drives the card's height, so the height has to be
              // recomputed on every scroll tick: `onPageChanged` fires halfway
              // through a swipe, and rebuilding only then would leave the card
              // frozen at that moment's interpolated height — cutting the taller
              // option's last rows off when it came back into view.
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) =>
                    SizedBox(height: _viewportHeight, child: child),
                child: ScrollConfiguration(
                  // Desktop and web disable mouse-drag scrolling by default,
                  // which would leave the pager swipeable only by touch.
                  // Click-and-drag is the mouse's swipe.
                  behavior: const _DragAnywhereScrollBehavior(),
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _branches.length,
                    onPageChanged: (page) => setState(() => _page = page),
                    itemBuilder: (context, index) {
                      // A page is handed the viewport's height as a tight
                      // constraint; the scroll view frees the content to take
                      // its natural height so it can be measured.
                      return SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: _MeasureSize(
                          onChange: (size) {
                            if (_heights[index] == size.height) return;
                            setState(() => _heights[index] = size.height);
                          },
                          child: _branchPage(theme, l10n, index),
                        ),
                      );
                    },
                  ),
                ),
              ),
              _indicators(theme, l10n),
            ],
          ),
        ),
      ),
    );

    final nowLine = widget.nowLineMinutes;
    if (nowLine == null) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NowLine(minutes: nowLine),
        card,
      ],
    );
  }

  Widget _header(ThemeData theme, AppLocalizations l10n, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Row(
        children: [
          Icon(Icons.alt_route, size: 18, color: widget.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: widget.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (widget.isNow) ...[const NowBadge(), const SizedBox(width: 4)],
          _menu(l10n),
          ?widget.dragHandle,
        ],
      ),
    );
  }

  Widget _menu(AppLocalizations l10n) {
    final repo = ref.read(repositoryProvider);
    final set = widget.block.set;
    final branch = _branches[_page.clamp(0, _branches.length - 1)];
    return PopupMenuButton<_MenuAction>(
      tooltip: l10n.decisionActions,
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (action) async {
        switch (action) {
          case _MenuAction.renameDecision:
            final name = await _promptName(
              title: l10n.decisionNameLabel,
              hint: l10n.decisionNameHint,
              initial: set.label,
            );
            if (name != null) await repo.setAlternativeSetLabel(set.id, name);
          case _MenuAction.renameOption:
            final name = await _promptName(
              title: l10n.optionNameLabel,
              hint: l10n.optionNameHint,
              initial: branch.label,
            );
            if (name != null) await repo.setAlternativeLabel(branch.id, name);
          case _MenuAction.addOption:
            await repo.addAlternative(set.id);
            // Swipe to the option just added, ready to be planned.
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _goTo(_branches.length - 1),
            );
          case _MenuAction.duplicateOption:
            await repo.duplicateAlternative(branch.id);
            // Land on the copy — the whole point is to tweak it from here.
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _goTo(_branches.length - 1),
            );
          case _MenuAction.keepOnly:
            if (await _confirm(
              title: l10n.optionKeepOnlyQuestion,
              body: l10n.optionKeepOnlyBody,
              action: l10n.optionKeepOnly,
            )) {
              await repo.keepOnlyAlternative(branch.id);
            }
          case _MenuAction.deleteOption:
            if (await _confirm(
              title: l10n.optionDeleteQuestion,
              body: l10n.optionDeleteBody,
              action: l10n.delete,
            )) {
              await repo.deleteAlternative(branch.id);
            }
          case _MenuAction.deleteDecision:
            if (await _confirm(
              title: l10n.decisionDeleteQuestion,
              body: l10n.decisionDeleteBody,
              action: l10n.delete,
            )) {
              await repo.deleteAlternativeSet(set.id);
            }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _MenuAction.addOption,
          child: Text(l10n.optionAdd),
        ),
        PopupMenuItem(
          value: _MenuAction.duplicateOption,
          child: Text(l10n.optionDuplicate),
        ),
        PopupMenuItem(
          value: _MenuAction.renameDecision,
          child: Text(l10n.decisionRename),
        ),
        PopupMenuItem(
          value: _MenuAction.renameOption,
          child: Text(l10n.optionRename),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _MenuAction.keepOnly,
          child: Text(l10n.optionKeepOnly),
        ),
        PopupMenuItem(
          value: _MenuAction.deleteOption,
          child: Text(l10n.optionDelete),
        ),
        PopupMenuItem(
          value: _MenuAction.deleteDecision,
          child: Text(l10n.decisionDelete),
        ),
      ],
    );
  }

  Widget _branchPage(ThemeData theme, AppLocalizations l10n, int index) {
    final branch = _branches[index];
    final items = widget.block.itemsByBranch[branch.id] ?? const [];
    final isChosen = branch.chosen;
    final totals = sumByCurrency(_branchCosts(items));
    // Where now sits inside this option — only ever the chosen one, and only on
    // today: an option the trip is not following is not somewhere we can be.
    //
    // A decision spans its chosen option whole, so when now falls *between* two
    // of its entries the day sees the decision as under way and draws no line of
    // its own. The boundary is inside the card, so it is drawn inside the card —
    // otherwise a decision would swallow the mark exactly when it is most needed
    // ([widget.isNow] is the day's word for that, and the only case in which an
    // option may draw a line).
    final nowMinutes = widget.nowMinutes;
    final marker = (isChosen && nowMinutes != null)
        ? nowMarkerForItems(items, nowMinutes)
        : null;
    final nowIndex = (marker != null && marker.happening) ? marker.index : -1;
    final lineIndex = (widget.isNow && marker != null && !marker.happening)
        ? marker.index
        : -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _branchLabel(l10n, index),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (totals.isNotEmpty)
                      Text(
                        formatTotals(totals, widget.localeName),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (isChosen)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.check, size: 16),
                  label: Text(l10n.optionChosen),
                )
              else
                FilledButton.tonal(
                  onPressed: () =>
                      ref.read(repositoryProvider).chooseAlternative(branch.id),
                  child: Text(l10n.optionChoose),
                ),
            ],
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 8, 8, 4),
            child: Text(
              l10n.optionEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: items.length,
            onReorderItem: (oldIndex, newIndex) =>
                widget.onReorderBranch(items, oldIndex, newIndex),
            itemBuilder: (context, i) {
              final item = items[i];
              final groupId = item.groupId;
              return TimelineTile(
                key: ValueKey(item.id),
                item: item,
                accent: widget.accent,
                onTap: () => widget.onTapItem(item),
                costs: widget.costsByItem[item.id] ?? const [],
                group: groupId == null ? null : widget.groups[groupId],
                isFirstInGroup: startsGroupRun(
                  item,
                  i == 0 ? null : items[i - 1],
                ),
                isLastInGroup: endsGroupRun(
                  item,
                  i == items.length - 1 ? null : items[i + 1],
                ),
                groupCosts: groupId == null
                    ? const []
                    : (widget.costsByGroup[groupId] ?? const []),
                localeName: widget.localeName,
                onTapCost: widget.onTapCost,
                isNow: i == nowIndex,
                nowLineMinutes: i == lineIndex ? nowMinutes : null,
                held: isHeldItem(widget.held, item),
                dragHandle: ReorderableDragStartListener(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.drag_indicator,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
        // Everything the option has left to say is behind us — which reads as the
        // decision still being under way only when something untimed is left in
        // it, so the line closes the option off rather than being dropped.
        if (lineIndex == items.length && items.isNotEmpty)
          NowLine(minutes: nowMinutes!),
        Padding(
          padding: const EdgeInsets.only(left: 40, top: 4, bottom: 4),
          child: Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => widget.onAddPlace(branch.id),
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: Text(l10n.addPlace),
              ),
              if (_arrival(items) case final arrival?)
                ActionChip(
                  avatar: const Icon(Icons.place, size: 16),
                  label: Text(l10n.addArrival(arrival)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => widget.onQuickAddPlace(branch.id, arrival),
                ),
              TextButton.icon(
                onPressed: () => widget.onAddTransport(branch.id),
                icon: const Icon(Icons.alt_route, size: 18),
                label: Text(l10n.addTransport),
              ),
              // The option's own add-row, so the entry lands in the option you
              // swiped to — the ambiguity a drop *onto* the card would have.
              if (widget.held case final held?)
                PutDownChip(
                  mode: held.mode,
                  onPressed: () => widget.onPutDown(branch.id),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// One pill per option, each showing its price — so the options can be
  /// compared at a glance, which a pager otherwise makes impossible — plus the
  /// chevrons that step through them without a swipe.
  Widget _indicators(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.optionPrevious,
            icon: const Icon(Icons.chevron_left),
            onPressed: _page == 0 ? null : () => _goTo(_page - 1),
          ),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var i = 0; i < _branches.length; i++)
                  _OptionPill(
                    label: _branchLabel(l10n, i),
                    totals: formatTotals(
                      sumByCurrency(
                        _branchCosts(
                          widget.block.itemsByBranch[_branches[i].id] ??
                              const [],
                        ),
                      ),
                      widget.localeName,
                    ),
                    accent: widget.accent,
                    current: i == _page,
                    chosen: _branches[i].chosen,
                    onTap: () => _goTo(i),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.optionNext,
            icon: const Icon(Icons.chevron_right),
            onPressed: _page == _branches.length - 1
                ? null
                : () => _goTo(_page + 1),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptName({
    required String title,
    required String hint,
    String? initial,
  }) {
    return showTextPromptDialog(
      context,
      title: title,
      hint: hint,
      initial: initial ?? '',
      confirmLabel: AppLocalizations.of(context).save,
    );
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
  }) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}

enum _MenuAction {
  addOption,
  duplicateOption,
  renameDecision,
  renameOption,
  keepOnly,
  deleteOption,
  deleteDecision,
}

/// Steps the pager one option left ([delta] -1) or right (+1), from the keyboard.
class _StepIntent extends Intent {
  const _StepIntent(this.delta);
  final int delta;
}

/// An option's indicator: its name and price, so every option's cost is visible
/// while only one is on screen. Tapping it swipes there.
class _OptionPill extends StatelessWidget {
  const _OptionPill({
    required this.label,
    required this.totals,
    required this.accent,
    required this.current,
    required this.chosen,
    required this.onTap,
  });

  final String label;
  final String totals;
  final Color accent;
  final bool current;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: current ? accent.withValues(alpha: 0.18) : Colors.transparent,
          border: Border.all(
            color: current ? accent : theme.colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chosen) ...[
              Icon(Icons.check, size: 13, color: accent),
              const SizedBox(width: 3),
            ],
            Text(
              totals.isEmpty ? label : '$label · $totals',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: current ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scroll behaviour that lets a mouse drag the pager, which Flutter otherwise
/// allows only for touch and trackpad.
class _DragAnywhereScrollBehavior extends MaterialScrollBehavior {
  const _DragAnywhereScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
  };
}

/// Reports its child's laid-out size, so the pager can size itself to the option
/// on screen.
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _previous;

  @override
  void performLayout() {
    super.performLayout();
    final size = child?.size ?? Size.zero;
    if (_previous == size) return;
    _previous = size;
    // Reporting during layout would rebuild mid-frame; hand it to the next one.
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(size));
  }
}
