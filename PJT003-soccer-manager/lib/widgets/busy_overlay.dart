import 'package:flutter/material.dart';

/// 重い同期処理の実行中に、操作をブロックしつつ進行中であることを示す
/// 半透明のローディングオーバーレイ。
class BusyOverlay extends StatelessWidget {
  final bool visible;
  final String label;
  final Widget child;

  const BusyOverlay(
      {super.key,
      required this.visible,
      required this.child,
      this.label = '処理中…'});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(label),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
