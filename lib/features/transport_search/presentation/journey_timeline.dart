import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A leg's rows with its line down their left side, as a timetable draws a
/// run: a dot for every stop, the line between them in the leg's color where
/// the traveler rides and in a quiet one outside, and the vehicle on the line
/// where it is believed to be.
///
/// Its own render object rather than a row of widgets per line, because the
/// vehicle sits *between* rows: half way from one stop to the next is half
/// way between their dots, whatever lies in between (the service's own line,
/// its notes, a fold of stops), and that is a distance only known once every
/// row has been laid out.
class JourneyTimeline extends MultiChildRenderObjectWidget {
  const JourneyTimeline({
    super.key,
    required super.children,
    required this.color,
    required this.outsideColor,
    required this.surface,
    this.vehicle,
  });

  /// The line and dots of the leg itself.
  final Color color;

  /// The line and dots outside it, before boarding and after getting off.
  final Color outsideColor;

  /// What an end's hollow dot is filled with: the color behind the rows.
  final Color surface;

  /// Where the [TimelineVehicle] among [children] goes, or null when there is
  /// none to place.
  final TimelineSpot? vehicle;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderJourneyTimeline(
        color: color,
        outsideColor: outsideColor,
        surface: surface,
        vehicle: vehicle,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderJourneyTimeline renderObject,
  ) {
    renderObject
      ..color = color
      ..outsideColor = outsideColor
      ..surface = surface
      ..vehicle = vehicle;
  }
}

/// A place on a timeline's line: [fraction] of the way from its [from]th dot
/// to its [to]th, counting only the rows that have one.
@immutable
class TimelineSpot {
  const TimelineSpot(this.from, this.to, [this.fraction = 0]);

  /// At the [index]th dot.
  const TimelineSpot.at(int index) : this(index, index);

  final int from;
  final int to;
  final double fraction;

  @override
  bool operator ==(Object other) =>
      other is TimelineSpot &&
      other.from == from &&
      other.to == to &&
      other.fraction == fraction;

  @override
  int get hashCode => Object.hash(from, to, fraction);
}

/// What a timeline row carries on the line.
enum TimelineDot {
  /// Nothing: the line passes beside it, if it runs past at all.
  none,

  /// A stop passed through: a small filled dot.
  stop,

  /// A stop the vehicle skips: a small hollow one.
  skipped,

  /// Where the traveler gets on or off: a larger hollow one.
  end,
}

/// One row of a [JourneyTimeline], with what it puts on the line beside it.
class TimelineRow extends ParentDataWidget<_TimelineParentData> {
  const TimelineRow({
    super.key,
    required super.child,
    this.dot = TimelineDot.none,
    this.outside = false,
  });

  final TimelineDot dot;

  /// Whether the row lies outside the leg, on the run before boarding or
  /// after getting off: its dot, and the line to it, in the quiet color.
  final bool outside;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as _TimelineParentData;
    if (data.dot == dot && data.outside == outside && !data.vehicle) return;
    data
      ..dot = dot
      ..outside = outside
      ..vehicle = false;
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => JourneyTimeline;
}

/// The vehicle on a [JourneyTimeline]'s line, placed by its
/// [JourneyTimeline.vehicle]. Drawn over the rows, centered on the line.
class TimelineVehicle extends ParentDataWidget<_TimelineParentData> {
  const TimelineVehicle({super.key, required super.child});

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as _TimelineParentData;
    if (data.vehicle) return;
    data
      ..vehicle = true
      ..dot = TimelineDot.none;
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => JourneyTimeline;
}

/// How wide the strip left of the rows is that the line runs down.
const double kTimelineGutter = 28;

/// Where in the gutter the line runs.
const double _lineX = 11;

/// How far below a row's top its dot sits, at most: the middle of a row of
/// one line, and the middle of the first line of a taller one.
const double _dotDepth = 11;

class _TimelineParentData extends ContainerBoxParentData<RenderBox> {
  TimelineDot dot = TimelineDot.none;
  bool outside = false;
  bool vehicle = false;
}

/// The render object of a [JourneyTimeline].
class RenderJourneyTimeline extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TimelineParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TimelineParentData> {
  RenderJourneyTimeline({
    required this._color,
    required this._outsideColor,
    required this._surface,
    this._vehicle,
  });

  Color _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  Color _outsideColor;
  set outsideColor(Color value) {
    if (value == _outsideColor) return;
    _outsideColor = value;
    markNeedsPaint();
  }

  Color _surface;
  set surface(Color value) {
    if (value == _surface) return;
    _surface = value;
    markNeedsPaint();
  }

  TimelineSpot? _vehicle;
  set vehicle(TimelineSpot? value) {
    if (value == _vehicle) return;
    _vehicle = value;
    markNeedsLayout();
  }

  /// The dots as laid out: how far down each is, and what it is.
  final List<({double y, TimelineDot dot, bool outside})> _dots = [];

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TimelineParentData) {
      child.parentData = _TimelineParentData();
    }
  }

  Iterable<RenderBox> get _children sync* {
    var child = firstChild;
    while (child != null) {
      yield child;
      child = childAfter(child);
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) => kTimelineGutter;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      kTimelineGutter +
      _children
          .where((c) => !_data(c).vehicle)
          .fold(0.0, (w, c) => math.max(w, c.getMaxIntrinsicWidth(height)));

  @override
  double computeMinIntrinsicHeight(double width) => _rowsHeight(
    (c) => c.getMinIntrinsicHeight(math.max(0, width - kTimelineGutter)),
  );

  @override
  double computeMaxIntrinsicHeight(double width) => _rowsHeight(
    (c) => c.getMaxIntrinsicHeight(math.max(0, width - kTimelineGutter)),
  );

  double _rowsHeight(double Function(RenderBox child) height) => _children
      .where((c) => !_data(c).vehicle)
      .fold(0.0, (h, c) => h + height(c));

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final rows = _rowConstraints(constraints);
    var height = 0.0;
    for (final child in _children) {
      if (_data(child).vehicle) continue;
      height += child.getDryLayout(rows).height;
    }
    return constraints.constrain(Size(constraints.maxWidth, height));
  }

  BoxConstraints _rowConstraints(BoxConstraints constraints) =>
      BoxConstraints.tightFor(
        width: math.max(0, constraints.maxWidth - kTimelineGutter),
      );

  _TimelineParentData _data(RenderBox child) =>
      child.parentData! as _TimelineParentData;

  @override
  void performLayout() {
    final rows = _rowConstraints(constraints);
    _dots.clear();
    var y = 0.0;
    RenderBox? vehicle;
    for (final child in _children) {
      final data = _data(child);
      if (data.vehicle) {
        vehicle = child;
        continue;
      }
      child.layout(rows, parentUsesSize: true);
      data.offset = Offset(kTimelineGutter, y);
      if (data.dot != TimelineDot.none) {
        _dots.add((
          y: y + math.min(child.size.height / 2, _dotDepth),
          dot: data.dot,
          outside: data.outside,
        ));
      }
      y += child.size.height;
    }
    size = constraints.constrain(Size(constraints.maxWidth, y));

    if (vehicle != null) {
      vehicle.layout(constraints.loosen(), parentUsesSize: true);
      final at = _vehicleY();
      _data(vehicle).offset = at == null
          // Laid out but kept out of sight: nothing to place it at.
          ? const Offset(-10000, 0)
          : Offset(
              _lineX - vehicle.size.width / 2,
              at - vehicle.size.height / 2,
            );
    }
  }

  /// How far down the vehicle is, or null when its spot names a dot the rows
  /// do not have.
  double? _vehicleY() {
    final spot = _vehicle;
    if (spot == null) return null;
    if (spot.from < 0 || spot.to < spot.from || spot.to >= _dots.length) {
      return null;
    }
    final a = _dots[spot.from].y;
    final b = _dots[spot.to].y;
    return a + spot.fraction.clamp(0.0, 1.0) * (b - a);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final line = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i + 1 < _dots.length; i++) {
      final a = _dots[i];
      final b = _dots[i + 1];
      line.color = a.outside || b.outside ? _outsideColor : _color;
      canvas.drawLine(
        offset + Offset(_lineX, a.y),
        offset + Offset(_lineX, b.y),
        line,
      );
    }
    for (final dot in _dots) {
      final color = dot.outside ? _outsideColor : _color;
      final center = offset + Offset(_lineX, dot.y);
      switch (dot.dot) {
        case TimelineDot.none:
          break;
        case TimelineDot.stop:
          canvas.drawCircle(center, 4, Paint()..color = color);
        case TimelineDot.skipped:
          canvas
            ..drawCircle(center, 4, Paint()..color = _surface)
            ..drawCircle(
              center,
              3.25,
              Paint()
                ..color = color
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
        case TimelineDot.end:
          canvas
            ..drawCircle(center, 6.5, Paint()..color = _surface)
            ..drawCircle(
              center,
              5.25,
              Paint()
                ..color = color
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.5,
            );
      }
    }
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// The vehicle as both the list and the map draw it: its mode's icon on a
/// disc of [color], ringed in white so it stands off a line of the same
/// color, with the icon dark or light by what reads on that disc.
class VehicleBadge extends StatelessWidget {
  const VehicleBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 24,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 3)],
      ),
      child: Icon(icon, size: size * 0.6, color: onColor),
    );
  }
}
