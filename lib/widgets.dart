import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(22),
        ),
        child: child,
      );
}

class DonutPainter extends CustomPainter {
  DonutPainter(this.values, this.colors);

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.18;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = kTrack;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = colors[i % colors.length];
      final drawn = sweep > 0.05 ? sweep - 0.03 : sweep;
      canvas.drawArc(rect, start, drawn, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) => true;
}

/// نمودار خطی ۷ روزه؛ روز اول (شنبه) سمت راست است چون برنامه راست‌به‌چپ است
class LinePainter extends CustomPainter {
  LinePainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = kTrack
      ..strokeWidth = 1;

    for (var i = 0; i < 5; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (values.isEmpty) return;

    final maxV = math.max(
      4.0,
      values.fold<double>(0, (a, b) => a > b ? a : b),
    );

    Offset point(int i) {
      final x = size.width - (i + 0.5) / values.length * size.width;
      final y = size.height - (values[i] / maxV) * (size.height - 8) - 4;
      return Offset(x, y);
    }

    final line = Paint()
      ..color = kAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(point(i).dx, point(i).dy);
    }
    canvas.drawPath(path, line);

    final dot = Paint()..color = kAccent;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(point(i), 4, dot);
    }
  }

  @override
  bool shouldRepaint(covariant LinePainter oldDelegate) => true;
}
