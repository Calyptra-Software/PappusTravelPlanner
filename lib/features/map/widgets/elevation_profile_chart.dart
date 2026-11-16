import 'package:material_ui/material_ui.dart';

import '../../../core/format/distance_format.dart';
import '../elevation.dart';

/// A line's heights against the distance along it: the profile.
///
/// Drawn from the lowest point to the highest, not from sea level, since what
/// a profile is read for is the shape of the climb. The two heights are
/// written beside it and the length under it, so the picture has a scale.
/// A stretch without heights is left empty rather than bridged.
///
/// With [onScrub] the profile can be read point by point: a pointer hovering
/// over it, or a finger drawn across it, puts a line at that distance with the
/// distance and the height written by it, and [onScrub] is told the point, so
/// the map can show where it is. Letting go, or leaving the chart, takes the
/// line away and tells [onScrub] null. In a gap of the profile the line is
/// drawn with the distance only, and [onScrub] is told null: there is no
/// height there to point at.
class ElevationProfileChart extends StatefulWidget {
  const ElevationProfileChart({
    super.key,
    required this.profile,
    required this.color,
    this.height = 120,
    this.onScrub,
  });

  final LaidProfile profile;

  /// What the line is drawn in elsewhere: the trip's accent, or the entry's
  /// own color.
  final Color color;
  final double height;
  final ValueChanged<ProfilePoint?>? onScrub;

  @override
  State<ElevationProfileChart> createState() => _ElevationProfileChartState();
}

class _ElevationProfileChartState extends State<ElevationProfileChart> {
  /// Where the cursor stands, in meters from the start; null when there is
  /// none.
  double? _cursor;

  /// Moves the cursor to [dx] across a plot [width] wide.
  void _scrubTo(double dx, double width) {
    final meters = widget.profile.meters;
    if (width <= 0 || meters <= 0) return;
    final at = (dx / width).clamp(0.0, 1.0) * meters;
    setState(() => _cursor = at);
    widget.onScrub?.call(widget.profile.at(at));
  }

  void _clear() {
    if (_cursor == null) return;
    setState(() => _cursor = null);
    widget.onScrub?.call(null);
  }

  @override
  void didUpdateWidget(ElevationProfileChart old) {
    super.didUpdateWidget(old);
    // A cursor placed on another profile points at nothing on this one.
    if (old.profile != widget.profile && _cursor != null) {
      _cursor = null;
      widget.onScrub?.call(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = widget.profile.range;
    if (range == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final label = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final cursor = _cursor;
    final at = cursor == null ? null : widget.profile.at(cursor);

    final painted = CustomPaint(
      painter: _ProfilePainter(
        profile: widget.profile,
        low: range.low,
        high: range.high,
        line: widget.color,
        fill: widget.color.withValues(alpha: 0.18),
        axis: theme.colorScheme.outlineVariant,
        cursor: cursor,
        cursorElevation: at?.elevation,
        cursorColor: theme.colorScheme.onSurface,
      ),
    );
    // The painting is a variable of its own: the builder below must not close
    // over the one it is assigned to, or it builds itself inside itself.
    Widget plot = painted;
    if (widget.onScrub != null) {
      plot = LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return MouseRegion(
            onHover: (event) => _scrubTo(event.localPosition.dx, width),
            onExit: (_) => _clear(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (details) => _scrubTo(details.localPosition.dx, width),
              onPanUpdate: (details) =>
                  _scrubTo(details.localPosition.dx, width),
              onPanEnd: (_) => _clear(),
              onPanCancel: _clear,
              child: painted,
            ),
          );
        },
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${range.high.round()} m', style: label),
                  Text('${range.low.round()} m', style: label),
                ],
              ),
              const SizedBox(width: 6),
              Expanded(child: plot),
            ],
          ),
        ),
        // The length, and where the cursor stands while there is one: the
        // line in the plot says where, this says how far and how high.
        Row(
          children: [
            Expanded(
              child: cursor == null
                  ? const SizedBox.shrink()
                  : Text(
                      [
                        formatDistance(cursor),
                        if (at != null) '${at.elevation.round()} m',
                      ].join(' · '),
                      key: const ValueKey('profile-cursor'),
                      style: label?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
            ),
            Text(formatDistance(widget.profile.meters), style: label),
          ],
        ),
      ],
    );
  }
}

class _ProfilePainter extends CustomPainter {
  _ProfilePainter({
    required this.profile,
    required this.low,
    required this.high,
    required this.line,
    required this.fill,
    required this.axis,
    this.cursor,
    this.cursorElevation,
    this.cursorColor = const Color(0xFF202124),
  });

  final LaidProfile profile;
  final double low;
  final double high;
  final Color line;
  final Color fill;
  final Color axis;

  /// Where the cursor stands, in meters, and the height there; the height is
  /// null in a gap.
  final double? cursor;
  final double? cursorElevation;
  final Color cursorColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.meters <= 0 || size.isEmpty) return;
    // A flat line has no span to scale by; it is drawn half way up.
    final span = high - low;
    double x(double meters) => meters / profile.meters * size.width;
    double y(double elevation) => span <= 0
        ? size.height / 2
        : size.height - (elevation - low) / span * size.height;
    Offset at(ProfilePoint point) =>
        Offset(x(point.meters), y(point.elevation));

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = axis
        ..strokeWidth = 1,
    );
    for (final stretch in profile.stretches) {
      if (stretch.length < 2) continue;
      final outline = Path()
        ..moveTo(at(stretch.first).dx, at(stretch.first).dy);
      for (final point in stretch.skip(1)) {
        final offset = at(point);
        outline.lineTo(offset.dx, offset.dy);
      }
      final area = Path.from(outline)
        ..lineTo(at(stretch.last).dx, size.height)
        ..lineTo(at(stretch.first).dx, size.height)
        ..close();
      canvas
        ..drawPath(area, Paint()..color = fill)
        ..drawPath(
          outline,
          Paint()
            ..color = line
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeJoin = StrokeJoin.round,
        );
    }

    final cursor = this.cursor;
    if (cursor == null) return;
    final cx = x(cursor);
    canvas.drawLine(
      Offset(cx, 0),
      Offset(cx, size.height),
      Paint()
        ..color = cursorColor
        ..strokeWidth = 1,
    );
    final elevation = cursorElevation;
    if (elevation != null) {
      canvas
        ..drawCircle(
          Offset(cx, y(elevation)),
          4,
          Paint()..color = const Color(0xFFFFFFFF),
        )
        ..drawCircle(Offset(cx, y(elevation)), 3, Paint()..color = cursorColor);
    }
  }

  @override
  bool shouldRepaint(_ProfilePainter old) =>
      old.profile != profile ||
      old.line != line ||
      old.fill != fill ||
      old.axis != axis ||
      old.cursor != cursor ||
      old.cursorElevation != cursorElevation ||
      old.cursorColor != cursorColor;
}
