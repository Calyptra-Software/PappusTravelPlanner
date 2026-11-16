import 'package:material_ui/material_ui.dart';

import '../../../core/format/distance_format.dart';
import '../elevation.dart';

/// A line's heights against the distance along it: the profile.
///
/// Drawn from the lowest point to the highest, not from sea level, since what
/// a profile is read for is the shape of the climb. The two heights are
/// written beside it and the length under it, so the picture has a scale.
/// A stretch without heights is left empty rather than bridged.
class ElevationProfileChart extends StatelessWidget {
  const ElevationProfileChart({
    super.key,
    required this.profile,
    required this.color,
    this.height = 120,
  });

  final LaidProfile profile;

  /// What the line is drawn in elsewhere: the trip's accent, or the entry's
  /// own color.
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final range = profile.range;
    if (range == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final label = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
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
              Expanded(
                child: CustomPaint(
                  painter: _ProfilePainter(
                    profile: profile,
                    low: range.low,
                    high: range.high,
                    line: color,
                    fill: color.withValues(alpha: 0.18),
                    axis: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(formatDistance(profile.meters), style: label),
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
  });

  final LaidProfile profile;
  final double low;
  final double high;
  final Color line;
  final Color fill;
  final Color axis;

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.meters <= 0 || size.isEmpty) return;
    // A flat line has no span to scale by; it is drawn half way up.
    final span = high - low;
    Offset at(ProfilePoint point) => Offset(
      point.meters / profile.meters * size.width,
      span <= 0
          ? size.height / 2
          : size.height - (point.elevation - low) / span * size.height,
    );

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
  }

  @override
  bool shouldRepaint(_ProfilePainter old) =>
      old.profile != profile ||
      old.line != line ||
      old.fill != fill ||
      old.axis != axis;
}
