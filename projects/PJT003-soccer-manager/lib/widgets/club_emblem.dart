import 'dart:math';
import 'package:flutter/material.dart';

/// チームIDから決定論的に生成する、実際のロゴ画像を持たない代替のクラブエンブレム。
/// 同じチームなら常に同じ形・色・イニシャルになる。
class ClubEmblem extends StatelessWidget {
  final String teamId;
  final String teamName;
  final double size;

  const ClubEmblem(
      {super.key,
      required this.teamId,
      required this.teamName,
      this.size = 40});

  @override
  Widget build(BuildContext context) {
    final seed = teamId.hashCode;
    final rng = Random(seed);
    final hue = rng.nextDouble() * 360;
    final base = HSLColor.fromAHSL(1, hue, 0.55, 0.42).toColor();
    final accent = HSLColor.fromAHSL(1, (hue + 40) % 360, 0.6, 0.30).toColor();
    final shapeIndex = seed.abs() % 3;
    final motifIndex = (seed.abs() ~/ 3) % 3;
    final initial =
        teamName.trim().isEmpty ? '?' : teamName.trim().substring(0, 1);

    return Semantics(
      label: '$teamNameのエンブレム',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _EmblemPainter(
                  base: base,
                  accent: accent,
                  shapeIndex: shapeIndex,
                  motifIndex: motifIndex),
            ),
            Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.4,
                shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  final Color base;
  final Color accent;
  final int shapeIndex;
  final int motifIndex;

  const _EmblemPainter({
    required this.base,
    required this.accent,
    required this.shapeIndex,
    required this.motifIndex,
  });

  Path _shapePath(Size size) {
    final w = size.width;
    final h = size.height;
    switch (shapeIndex) {
      case 0: // 盾形(シールド)
        return Path()
          ..moveTo(w * 0.5, 0)
          ..lineTo(w, h * 0.2)
          ..lineTo(w, h * 0.55)
          ..quadraticBezierTo(w, h * 0.95, w * 0.5, h)
          ..quadraticBezierTo(0, h * 0.95, 0, h * 0.55)
          ..lineTo(0, h * 0.2)
          ..close();
      case 1: // 六角形
        return Path()
          ..moveTo(w * 0.5, 0)
          ..lineTo(w, h * 0.25)
          ..lineTo(w, h * 0.75)
          ..lineTo(w * 0.5, h)
          ..lineTo(0, h * 0.75)
          ..lineTo(0, h * 0.25)
          ..close();
      default: // 円形
        return Path()..addOval(Rect.fromLTWH(0, 0, w, h));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _shapePath(size);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [base, accent],
    );
    canvas.drawPath(
      path,
      Paint()..shader = gradient.createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipPath(path);
    final motifPaint = Paint()..color = Colors.white.withValues(alpha: 0.22);
    switch (motifIndex) {
      case 0: // 斜めの帯(サッシュ)
        canvas.drawRect(
          Rect.fromLTWH(-size.width * 0.2, size.height * 0.38, size.width * 1.4,
              size.height * 0.22),
          motifPaint,
        );
        break;
      case 1: // 星
        canvas.drawPath(
            _starPath(
                Offset(size.width / 2, size.height * 0.32), size.width * 0.16),
            motifPaint);
        break;
      default: // 横二分割
        canvas.drawRect(
            Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2),
            motifPaint);
    }
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.04,
    );
  }

  Path _starPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = -pi / 2 + i * 2 * pi / 5;
      final innerAngle = outerAngle + pi / 5;
      final outer = center + Offset(cos(outerAngle), sin(outerAngle)) * radius;
      final inner =
          center + Offset(cos(innerAngle), sin(innerAngle)) * radius * 0.45;
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter oldDelegate) =>
      oldDelegate.base != base ||
      oldDelegate.accent != accent ||
      oldDelegate.shapeIndex != shapeIndex;
}
