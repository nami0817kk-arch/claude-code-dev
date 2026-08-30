import 'dart:math';

import 'package:flutter/material.dart';

import '../models/attributes.dart';
import '../models/player.dart';

/// FM風の能力レーダーチャート(ポリゴン)。攻撃/守備/技術/メンタル/
/// フィジカル(GKは攻撃の代わりにGK能力)の5軸で選手のバランスを
/// 一目で伝える。値は0-100想定。
class AttributeRadar extends StatelessWidget {
  final Player player;
  final double size;

  const AttributeRadar({super.key, required this.player, this.size = 180});

  int _categoryAverage(AttributeCategory category) {
    final keys = category.keys;
    if (keys.isEmpty) return 0;
    final total = keys.fold<int>(0, (s, k) => s + player.attributeValue(k));
    return (total / keys.length).round();
  }

  @override
  Widget build(BuildContext context) {
    final isGk = player.position.group == PositionGroup.gk;
    final axes = <(String, int)>[
      if (isGk)
        ('GK', _categoryAverage(AttributeCategory.goalkeeping))
      else
        ('攻撃', player.attack),
      ('守備', player.defense),
      ('技術', _categoryAverage(AttributeCategory.technical)),
      ('メンタル', _categoryAverage(AttributeCategory.mental)),
      ('フィジカル', _categoryAverage(AttributeCategory.physical)),
    ];
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '能力レーダー: ${axes.map((a) => '${a.$1} ${a.$2}').join('、')}',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RadarPainter(
            axes: axes,
            lineColor: scheme.primary,
            fillColor: scheme.primary.withValues(alpha: 0.25),
            gridColor: Theme.of(context).dividerColor,
            labelStyle: TextStyle(
              fontSize: 10,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<(String, int)> axes;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final TextStyle labelStyle;

  _RadarPainter({
    required this.axes,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // ラベル描画分の余白を確保する。
    final radius = min(size.width, size.height) / 2 - 22;
    final n = axes.length;
    Offset pointAt(int i, double factor) {
      final angle = -pi / 2 + 2 * pi * i / n;
      return center +
          Offset(cos(angle) * radius * factor, sin(angle) * radius * factor);
    }

    // 目盛りの多角形(25/50/75/100)と軸線。
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final level in [0.25, 0.5, 0.75, 1.0]) {
      final path = Path();
      for (int i = 0; i < n; i++) {
        final pt = pointAt(i, level);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }
    for (int i = 0; i < n; i++) {
      canvas.drawLine(center, pointAt(i, 1.0), gridPaint);
    }

    // 値の多角形。
    final valuePath = Path();
    for (int i = 0; i < n; i++) {
      final factor = (axes[i].$2 / 100).clamp(0.0, 1.0);
      final pt = pointAt(i, factor);
      if (i == 0) {
        valuePath.moveTo(pt.dx, pt.dy);
      } else {
        valuePath.lineTo(pt.dx, pt.dy);
      }
    }
    valuePath.close();
    canvas.drawPath(valuePath, Paint()..color = fillColor);
    canvas.drawPath(
      valuePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // 軸ラベル(値つき)。
    for (int i = 0; i < n; i++) {
      final labelPos = pointAt(i, 1.18);
      final tp = TextPainter(
        text: TextSpan(text: '${axes[i].$1}\n${axes[i].$2}', style: labelStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      tp.paint(
        canvas,
        labelPos - Offset(tp.width / 2, tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.axes != axes || old.lineColor != lineColor;
}
