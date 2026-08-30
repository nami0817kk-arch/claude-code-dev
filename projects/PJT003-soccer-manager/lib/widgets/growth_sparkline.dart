import 'package:flutter/material.dart';

/// 総合力の週次推移([Player.overallHistory])を描く小さな折れ線グラフ。
/// 2点以上の履歴があるときだけ使う想定(呼び出し側で出し分ける)。
class GrowthSparkline extends StatelessWidget {
  final List<int> history;
  final double height;

  const GrowthSparkline({super.key, required this.history, this.height = 56});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final first = history.first;
    final last = history.last;
    return Semantics(
      label: '成長推移: 直近${history.length}節で総合$firstから$lastへ',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparklinePainter(history: history, color: color),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> history;
  final Color color;

  const _SparklinePainter({required this.history, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;
    var minV = history.first;
    var maxV = history.first;
    for (final v in history) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    // 変化がない場合も水平線が中央に描かれるよう、最低2の値幅を確保する。
    final span = (maxV - minV) < 2 ? 2 : (maxV - minV);
    final mid = (maxV + minV) / 2;
    final lo = mid - span / 2;

    const padY = 4.0;
    final drawH = size.height - padY * 2;
    Offset pointAt(int i) {
      final x = size.width * i / (history.length - 1);
      final t = (history[i] - lo) / span;
      final y = padY + drawH * (1 - t);
      return Offset(x, y);
    }

    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < history.length; i++) {
      final p = pointAt(i);
      line.lineTo(p.dx, p.dy);
    }

    // 折れ線の下側をうっすら塗って面積グラフ風にする。
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.12),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    // 最新値を点で強調する。
    canvas.drawCircle(pointAt(history.length - 1), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.history != history || oldDelegate.color != color;
}
