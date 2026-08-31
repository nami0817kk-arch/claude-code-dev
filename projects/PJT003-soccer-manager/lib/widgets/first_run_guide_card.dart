import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_ext.dart';
import '../logic/first_run_guide.dart';
import '../models/first_run_step.dart';
import '../screens/lineup_screen.dart';
import '../screens/squad_screen.dart';
import '../screens/training_screen.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';

/// 初めて遊ぶ人をこのゲームの週次サイクルに一周させるためのカード。
///
/// ホーム画面の最上部に置き、4ステップすべてを終えるか、本人が閉じると
/// 二度と出なくなる。各ステップは該当画面へ直接飛べるようにしてあり、
/// 「どこにあるか分からない」で止まらないようにしている。
class FirstRunGuideCard extends StatelessWidget {
  const FirstRunGuideCard({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save;
    if (save == null || !FirstRunGuide.shouldShow(save)) {
      return const SizedBox.shrink();
    }

    final step = FirstRunGuide.nextStep(save)!;
    final done = FirstRunGuide.doneCount(save);
    final total = FirstRunStep.values.length;
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.firstRunProgress(done, total),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: scheme.onPrimaryContainer,
                  tooltip: l10n.firstRunClose,
                  onPressed: () {
                    FeedbackService.tap();
                    context.read<GameState>().dismissFirstRunGuide();
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 済んだステップも並べて見せる。進んでいる実感が続ける動機になる。
            Semantics(
              label: l10n.firstRunSemantics(done, total),
              child: Row(
                children: [
                  for (final s in FirstRunStep.values)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: LinearProgressIndicator(
                          value: FirstRunGuide.isDone(save, s) ? 1 : 0,
                          minHeight: 4,
                          backgroundColor: scheme.onPrimaryContainer
                              .withValues(alpha: 0.15),
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              step.label(l10n),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              step.description(l10n),
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: _actionFor(context, step),
            ),
          ],
        ),
      ),
    );
  }

  /// ステップごとの行き先。試合だけは同じホーム画面の「次の試合」カードで
  /// 完結するため、飛ばす先が無く案内文だけを出す。
  Widget _actionFor(BuildContext context, FirstRunStep step) {
    Widget? target;
    switch (step) {
      case FirstRunStep.lineup:
        target = const LineupScreen();
      case FirstRunStep.training:
        target = const TrainingScreen();
      case FirstRunStep.growth:
        target = const SquadScreen();
      case FirstRunStep.match:
        target = null;
    }

    if (target == null) {
      return Text(
        context.l10n.firstRunMatchHint,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final destination = target;
    return FilledButton.icon(
      icon: const Icon(Icons.arrow_forward),
      label: Text(step.actionLabel(context.l10n)),
      onPressed: () {
        FeedbackService.tap();
        // ガイドに従って開いた時点で踏んだ扱いにする。戻ってきたときに
        // 同じステップが残っていると、進めたのに進んでいないように見える。
        context.read<GameState>().markFirstRunStep(step);
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => destination));
      },
    );
  }
}
