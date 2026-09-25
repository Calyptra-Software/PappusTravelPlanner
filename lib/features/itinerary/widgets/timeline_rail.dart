import 'package:flutter/material.dart';

/// The width of the timeline's left gutter. The rail runs down its middle, and
/// everything a day is strung along — a place's dot, a leg's mode icon, the
/// now-line's dot, a run's or a decision's header icon — is centered on it.
const double kTimelineGutterWidth = 40;

/// Paints the timeline's rail behind [child], down the middle of the gutter
/// and over the child's whole height.
///
/// Every stretch of a day draws its own piece of the one line, so the pieces
/// have to agree on where it is. That is why a band or a card wrapping entries
/// must not *inset* them: a border drawn as a `decoration` pads its child by
/// its own width, and a run's 3px stripe once moved its members' rail 3px to
/// the right of the entries above and below it. Their borders are therefore
/// drawn as `foregroundDecoration`, which takes no room.
///
/// It is also why a band or a card wraps its *whole* height in one of these,
/// label, shared ticket and margins included, rather than leaving the rail to
/// the entries inside: those rows are where the line used to break.
class TimelineRail extends StatelessWidget {
  const TimelineRail({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RailPainter(Theme.of(context).colorScheme.outlineVariant),
      child: child,
    );
  }
}

class _RailPainter extends CustomPainter {
  const _RailPainter(this.color);

  final Color color;

  static const double _width = 2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(
        (kTimelineGutterWidth - _width) / 2,
        0,
        _width,
        size.height,
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_RailPainter oldDelegate) => oldDelegate.color != color;
}

/// A header's icon sitting on the rail, in the gutter, the way an entry's node
/// does: a run's link, a decision's fork.
///
/// The disc is filled with [background] — the color the header is drawn on — so
/// the rail stops at the icon and resumes under it rather than running through
/// the glyph.
class TimelineRailIcon extends StatelessWidget {
  const TimelineRailIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    this.size = 16,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kTimelineGutterWidth,
      child: Center(
        child: Container(
          width: size + 8,
          height: size + 8,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}
