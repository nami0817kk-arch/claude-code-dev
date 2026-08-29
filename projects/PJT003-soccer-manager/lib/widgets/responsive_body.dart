import 'package:flutter/material.dart';

/// 画面本体をワイド画面(デスクトップブラウザ等)では中央寄せ・最大幅制限し、
/// スマートフォン等の狭い画面では従来通り全幅で表示するラッパー。
/// PC等の広いウィンドウでリスト・カードが不必要に間延びするのを防ぐ。
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveBody({super.key, required this.child, this.maxWidth = 720});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
