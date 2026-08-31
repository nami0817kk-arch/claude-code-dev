import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../monetization/monetization_controller.dart';
import '../monetization/purchase_service.dart';
import '../monetization/reward_offer.dart';
import '../services/feedback_service.dart';
import '../l10n/tr.dart';

/// サポーター購入と、購入の復元。設定画面に置く。
///
/// 復元導線は iOS の審査要件なので、購入済みかどうかに関わらず出す。
class SupporterSection extends StatefulWidget {
  const SupporterSection({super.key});

  @override
  State<SupporterSection> createState() => _SupporterSectionState();
}

class _SupporterSectionState extends State<SupporterSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final money = context.watch<MonetizationController>();
    // ストアに繋がらない環境 (Web版など) では、押せない購入ボタンを
    // 見せる意味がないので丸ごと隠す。
    if (!money.initialized || !money.storeAvailable) {
      return const SizedBox.shrink();
    }

    final price = money.priceLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(Tr.pick('サポーター', 'Supporter'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              if (money.isSupporter)
                ListTile(
                  leading: const Icon(Icons.favorite),
                  title: Text(Tr.pick('サポーターとしてご支援いただいています',
                      'Thank you for supporting the game')),
                  subtitle: Text(
                    Tr.pick('広告を見なくても特別協賛金を受け取れます。ありがとうございます。',
                        'You can take the sponsorship money without watching an ad. Thank you.'),
                  ),
                )
              else
                ListTile(
                  leading: const Icon(Icons.favorite_border),
                  title: Text(
                    price == null
                        ? Tr.pick('サポーターになる', 'Become a supporter')
                        : Tr.pick(
                            'サポーターになる（$price）', 'Become a supporter ($price)'),
                  ),
                  subtitle: Text(
                    Tr.pick(
                        '買い切りです。広告を見なくても特別協賛金を受け取れるようになり、1日の回数が${RewardOffer.dailyLimitFree}回から${RewardOffer.dailyLimitSupporter}回に増えます。',
                        'A one-off purchase. You get the sponsorship money without watching an ad, and your daily limit rises from ${RewardOffer.dailyLimitFree} to ${RewardOffer.dailyLimitSupporter}.'),
                  ),
                  trailing: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _busy ? null : _buy,
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.restore),
                title: Text(Tr.pick('購入を復元', 'Restore purchase')),
                subtitle: Text(
                  Tr.pick('機種変更や再インストールをした場合は、ここから購入済みの状態に戻せます',
                      'Changed device or reinstalled? Restore your purchase here'),
                ),
                onTap: _busy ? null : _restore,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _buy() =>
      _run(() => context.read<MonetizationController>().buySupporter());

  Future<void> _restore() =>
      _run(() => context.read<MonetizationController>().restorePurchases());

  Future<void> _run(Future<PurchaseOutcome> Function() action) async {
    FeedbackService.tap();
    setState(() => _busy = true);
    final outcome = await action();
    if (!mounted) return;
    setState(() => _busy = false);

    final message = switch (outcome) {
      PurchaseOutcome.purchased => Tr.pick(
          'ありがとうございます。サポーターとして登録されました', 'Thank you. You are now a supporter'),
      // 自分でやめた場合は何も言わない。失敗のように見せない。
      PurchaseOutcome.canceled => null,
      PurchaseOutcome.unavailable =>
        Tr.pick('対象の購入が見つかりませんでした', 'No matching purchase was found'),
      PurchaseOutcome.failed => Tr.pick('購入処理に失敗しました。時間をおいてお試しください',
          'The purchase did not go through. Please try again later'),
    };
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
