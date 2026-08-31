import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../monetization/monetization_controller.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../l10n/tr.dart';

/// 特典資金を受け取るカード。ファイナンス画面に置く。
///
/// 広告を出せない環境 (Web版・ストア未接続) では丸ごと消える。
/// 押しても何も起きないボタンを残すより、無いほうがよい。
class RewardFundsCard extends StatefulWidget {
  const RewardFundsCard({super.key});

  @override
  State<RewardFundsCard> createState() => _RewardFundsCardState();
}

class _RewardFundsCardState extends State<RewardFundsCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final money = context.watch<MonetizationController>();
    final gameState = context.watch<GameState>();
    if (!money.initialized || gameState.save == null) {
      return const SizedBox.shrink();
    }
    // 受け取れる見込みがまったく無い環境では出さない。
    // 上限に達しているだけなら、明日また受け取れることを伝えたいので出す。
    if (!money.canClaim && money.remainingToday > 0) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final amount = gameState.rewardFundsAmount;
    final soldOut = money.remainingToday <= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Tr.pick('スポンサーの特別協賛金', 'Special sponsorship payment'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  Tr.pick('本日 ${money.remainingToday}/${money.dailyLimit}',
                      'Today ${money.remainingToday}/${money.dailyLimit}'),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              soldOut
                  ? Tr.pick('本日分は受け取り済みです。日付が変わるとまた受け取れます。',
                      "You have taken today's allowance. It resets tomorrow.")
                  : money.requiresAd
                      ? Tr.pick(
                          '短い動画広告を最後まで見ると$amount万円を受け取れます。見なくてもゲームは最後まで遊べます。',
                          'Watch a short video to the end and receive $amount. You can finish the game without ever watching one.')
                      : Tr.pick('サポーターとして、広告なしで$amount万円を受け取れます。',
                          'As a supporter, you receive $amount with no ad.'),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(money.requiresAd
                        ? Icons.play_circle_outline
                        : Icons.redeem),
                label: Text(
                  soldOut
                      ? Tr.pick('本日分は受け取り済み', 'Already taken today')
                      : money.requiresAd
                          ? Tr.pick(
                              '動画を見て$amount万円', 'Watch a video for $amount')
                          : Tr.pick('$amount万円を受け取る', 'Receive $amount'),
                ),
                onPressed: _busy || soldOut ? null : _claim,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _claim() async {
    FeedbackService.tap();
    setState(() => _busy = true);
    final money = context.read<MonetizationController>();
    final gameState = context.read<GameState>();

    final result = await money.claimReward();
    if (!mounted) return;
    setState(() => _busy = false);

    final message = switch (result) {
      ClaimResult.granted => Tr.pick(
          '特別協賛金${gameState.claimRewardFunds()}万円を受け取りました',
          'You received ${gameState.claimRewardFunds()} in sponsorship'),
      ClaimResult.limitReached =>
        Tr.pick('本日分の受け取りは上限に達しています', "You have reached today's limit"),
      // 途中で閉じただけなので、責めるような文言にしない。
      ClaimResult.adNotCompleted => Tr.pick('広告が最後まで再生されなかったため、受け取れませんでした',
          'The ad did not finish, so nothing was paid'),
      ClaimResult.unavailable => Tr.pick('いま表示できる広告がありません。時間をおいてお試しください',
          'No ad is available right now. Please try again later'),
    };
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
