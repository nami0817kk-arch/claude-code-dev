import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/monetization/ad_service.dart';
import 'package:soccer_manager/monetization/monetization_controller.dart';
import 'package:soccer_manager/monetization/purchase_service.dart';
import 'package:soccer_manager/monetization/reward_offer.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 常に広告が用意できていて、指定した結果を返す差し替え用の実装。
class _FakeAdService implements AdService {
  _FakeAdService({this.ready = true, this.watchedToEnd = true});

  bool ready;
  bool watchedToEnd;
  int showCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  bool get isRewardedAdReady => ready;

  @override
  Future<bool> showRewardedAd() async {
    showCount++;
    return watchedToEnd;
  }

  @override
  void dispose() {}
}

class _FakePurchaseService implements PurchaseService {
  _FakePurchaseService({this.outcome = PurchaseOutcome.purchased});

  PurchaseOutcome outcome;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String?> priceLabel() async => '¥480';

  @override
  Future<PurchaseOutcome> buySupporter() async => outcome;

  @override
  Future<PurchaseOutcome> restorePurchases() async => outcome;

  @override
  void dispose() {}
}

Future<MonetizationController> _build({
  _FakeAdService? ads,
  _FakePurchaseService? purchases,
}) async {
  final controller = MonetizationController(
    adService: ads ?? _FakeAdService(),
    purchases: purchases ?? _FakePurchaseService(),
  );
  await controller.initialize();
  return controller;
}

void main() {
  // ニュース文を日本語で突き合わせているため、表示言語を固定する。
  // (テスト環境の端末ロケールは en で、既定のままだと英語が返る)
  setUp(() => Tr.language = AppLanguage.japanese);
  tearDown(() => Tr.language = AppLanguage.system);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('収益化', () {
    test('広告を最後まで見れば特典を受け取れる', () async {
      final ads = _FakeAdService();
      final money = await _build(ads: ads);

      expect(money.requiresAd, isTrue);
      expect(await money.claimReward(), ClaimResult.granted);
      expect(ads.showCount, 1);
      expect(money.claimedToday, 1);
    });

    test('広告を途中で閉じたら回数を消費しない', () async {
      // 見ていないのに回数だけ減ると、利用者から見れば単なる損。
      final money = await _build(ads: _FakeAdService(watchedToEnd: false));

      expect(await money.claimReward(), ClaimResult.adNotCompleted);
      expect(money.claimedToday, 0);
      expect(money.remainingToday, RewardOffer.dailyLimitFree);
    });

    test('広告の在庫が無いときは押せない', () async {
      final money = await _build(ads: _FakeAdService(ready: false));

      expect(money.canClaim, isFalse);
      expect(await money.claimReward(), ClaimResult.unavailable);
    });

    test('1日の上限を超えて受け取れない', () async {
      final money = await _build();

      for (var i = 0; i < RewardOffer.dailyLimitFree; i++) {
        expect(await money.claimReward(), ClaimResult.granted);
      }
      expect(money.remainingToday, 0);
      expect(await money.claimReward(), ClaimResult.limitReached);
    });

    test('サポーターは広告なしで受け取れて、上限も増える', () async {
      final ads = _FakeAdService();
      final money = await _build(ads: ads);

      expect(await money.buySupporter(), PurchaseOutcome.purchased);
      expect(money.isSupporter, isTrue);
      expect(money.requiresAd, isFalse);
      expect(money.dailyLimit, RewardOffer.dailyLimitSupporter);

      expect(await money.claimReward(), ClaimResult.granted);
      expect(ads.showCount, 0, reason: 'サポーターに広告を見せてはいけない');
    });

    test('サポーター状態は再起動後も残り、復元でも戻る', () async {
      final first = await _build();
      await first.buySupporter();

      // 同じ端末で起動し直した想定。
      final again = await _build();
      expect(again.isSupporter, isTrue);

      // 購入情報が消えた端末で復元した想定。
      SharedPreferences.setMockInitialValues({});
      final restored = await _build();
      expect(restored.isSupporter, isFalse);
      expect(await restored.restorePurchases(), PurchaseOutcome.purchased);
      expect(restored.isSupporter, isTrue);
    });

    test('購入をやめても失敗扱いにしない', () async {
      final money = await _build(
        purchases: _FakePurchaseService(outcome: PurchaseOutcome.canceled),
      );
      expect(await money.buySupporter(), PurchaseOutcome.canceled);
      expect(money.isSupporter, isFalse);
    });

    test('特典額はディビジョンに比例し、下部ほど少ない', () async {
      // 1部の額を5部で配ると序盤の経営判断が消し飛ぶ。
      expect(RewardOffer.fundsFor(1), greaterThan(RewardOffer.fundsFor(5)));
      for (var tier = 1; tier < 5; tier++) {
        expect(RewardOffer.fundsFor(tier),
            greaterThan(RewardOffer.fundsFor(tier + 1)));
      }
    });

    test('特典を受け取ると資金が増え、理由がニュースに残る', () async {
      final gameState = GameState();
      await gameState.startNewGame('テストFC');
      final before = gameState.save!.budget;

      final amount = gameState.claimRewardFunds();
      expect(amount, gameState.rewardFundsAmount);
      expect(gameState.save!.budget, before + amount);
      // 資金が増えた理由が追えないと、収支が読めなくなる。
      expect(gameState.save!.newsLog.first.text, contains('特別協賛金'));
    });
  });
}
