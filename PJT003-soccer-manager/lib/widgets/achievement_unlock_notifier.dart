import 'package:flutter/material.dart';
import '../state/game_state.dart';

/// 試合・シーズン終了・複数節まとめてシミュレーションなど、実績が新たに
/// 解除されうるあらゆる操作の直後に呼び出す共通の通知処理。1件なら
/// SnackBar、複数同時に解除された場合はまとめてダイアログで表示する。
void showAchievementUnlockNotification(
    BuildContext context, GameState gameState) {
  final newly = gameState.lastUnlockedAchievements;
  if (newly.isEmpty) return;
  gameState.lastUnlockedAchievements = [];

  if (newly.length == 1) {
    final a = newly.first;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('実績解除: ${a.name}')),
    );
    return;
  }
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('実績解除！'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final a in newly)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.emoji_events, color: Colors.amber.shade700),
                title: Text(a.name),
                subtitle: Text(a.description),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}
