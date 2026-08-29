import 'dart:math';
import 'package:flutter/material.dart';
import '../models/player.dart';
import 'position_colors.dart';

/// 選手IDから決定論的に生成する、実際の顔写真を持たない代替の似顔絵。
/// ポジション別カラーのリングで縁取り、一目でポジションも分かるようにする。
class PlayerFaceAvatar extends StatelessWidget {
  final String playerId;
  final Position position;
  final double size;
  final bool highlighted;

  const PlayerFaceAvatar({
    super.key,
    required this.playerId,
    required this.position,
    this.size = 40,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = position.group.color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: highlighted ? 2.5 : 1.5),
      ),
      padding: const EdgeInsets.all(1.5),
      child: ClipOval(
        child: CustomPaint(
          size: Size.square(size),
          painter: _FacePainter(seed: playerId.hashCode),
        ),
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  final int seed;

  const _FacePainter({required this.seed});

  static const _skinTones = [
    Color(0xFFFFDBAC),
    Color(0xFFF1C27D),
    Color(0xFFE0AC69),
    Color(0xFFC68642),
    Color(0xFF8D5524),
  ];

  static const _hairColors = [
    Color(0xFF1B1B1B),
    Color(0xFF3B2314),
    Color(0xFF6B4226),
    Color(0xFFB55239),
    Color(0xFFD4C4A8),
    Color(0xFF4A4A4A),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final w = size.width;
    final h = size.height;

    final skin = _skinTones[rng.nextInt(_skinTones.length)];
    final hair = _hairColors[rng.nextInt(_hairColors.length)];
    final hairStyle = rng.nextInt(4);
    final hasFacialHair = rng.nextDouble() < 0.28;
    final bgHue = rng.nextDouble() * 360;
    final background = HSLColor.fromAHSL(1, bgHue, 0.35, 0.88).toColor();

    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final skinPaint = Paint()..color = skin;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.12, h * 0.52),
          width: w * 0.14,
          height: h * 0.18),
      skinPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.88, h * 0.52),
          width: w * 0.14,
          height: h * 0.18),
      skinPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.54), width: w * 0.86, height: h * 0.92),
      skinPaint,
    );

    final hairPaint = Paint()..color = hair;
    switch (hairStyle) {
      case 2: // 短髪(サイド刈り上げ)
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.42),
              width: w * 0.9,
              height: h * 0.7),
          pi,
          pi,
          true,
          hairPaint,
        );
        break;
      case 1: // サイド分け
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.4),
              width: w * 0.92,
              height: h * 0.82),
          pi,
          pi,
          true,
          hairPaint,
        );
        canvas.drawRect(
            Rect.fromLTWH(w * 0.06, h * 0.3, w * 0.28, h * 0.14), hairPaint);
        break;
      case 3: // くせ毛・ボリューム
        for (double t = 0; t <= 1; t += 0.14) {
          final angle = pi + t * pi;
          final x = w * 0.5 + cos(angle) * w * 0.42;
          final y = h * 0.42 + sin(angle) * h * 0.4;
          canvas.drawCircle(Offset(x, y), w * 0.12, hairPaint);
        }
        break;
      default: // 0: 坊主・薄毛気味
        canvas.drawArc(
          Rect.fromCenter(
              center: Offset(w * 0.5, h * 0.4),
              width: w * 0.9,
              height: h * 0.6),
          pi,
          pi,
          true,
          hairPaint..color = hair.withValues(alpha: 0.55),
        );
    }

    final browPaint = Paint()
      ..color = hair
      ..strokeWidth = h * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(w * 0.32, h * 0.46), Offset(w * 0.42, h * 0.44), browPaint);
    canvas.drawLine(
        Offset(w * 0.58, h * 0.44), Offset(w * 0.68, h * 0.46), browPaint);

    final eyePaint = Paint()..color = const Color(0xFF2B2B2B);
    canvas.drawCircle(Offset(w * 0.37, h * 0.52), w * 0.045, eyePaint);
    canvas.drawCircle(Offset(w * 0.63, h * 0.52), w * 0.045, eyePaint);

    final nosePaint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.02;
    canvas.drawLine(
        Offset(w * 0.5, h * 0.54), Offset(w * 0.5, h * 0.64), nosePaint);

    final mouthPaint = Paint()
      ..color = const Color(0xFF7A3B3B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.035
      ..strokeCap = StrokeCap.round;
    final mouthPath = Path()
      ..moveTo(w * 0.38, h * 0.74)
      ..quadraticBezierTo(w * 0.5, h * 0.78, w * 0.62, h * 0.74);
    canvas.drawPath(mouthPath, mouthPaint);

    if (hasFacialHair) {
      final beardPaint = Paint()..color = hair.withValues(alpha: 0.85);
      final beardPath = Path()
        ..moveTo(w * 0.34, h * 0.64)
        ..quadraticBezierTo(w * 0.5, h * 0.9, w * 0.66, h * 0.64)
        ..quadraticBezierTo(w * 0.5, h * 0.8, w * 0.34, h * 0.64);
      canvas.drawPath(beardPath, beardPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) =>
      oldDelegate.seed != seed;
}
