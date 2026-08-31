import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_service.dart';
import 'purchase_service.dart';
import 'reward_offer.dart';

/// 特典を受け取ろうとした結果。
enum ClaimResult {
  /// 受け取れた。呼び出し側が資金を加算する。
  granted,

  /// 今日の上限に達している。
  limitReached,

  /// 広告を最後まで見なかった、または表示できなかった。
  adNotCompleted,

  /// この端末では広告も課金も使えない (Web版など)。
  unavailable,
}

/// 広告・課金の状態を持ち、特典の受け取りを仲介する。
///
/// セーブデータではなく端末側 (SharedPreferences) に置いている。
/// 購入はストアのアカウントに紐づくもので、どのセーブスロットで
/// 遊んでいるかとは関係がないため。
class MonetizationController extends ChangeNotifier {
  MonetizationController({AdService? adService, PurchaseService? purchases})
      : _ads = adService ?? createAdService(),
        _purchases = purchases ?? createPurchaseService();

  static const _supporterKey = 'monetization.supporter';
  static const _claimDayKey = 'monetization.claimDay';
  static const _claimCountKey = 'monetization.claimCount';

  final AdService _ads;
  final PurchaseService _purchases;

  bool initialized = false;

  /// サポーター購入済みか。
  bool isSupporter = false;

  /// 今日すでに受け取った回数。
  int claimedToday = 0;

  /// 上の回数がどの日のものか (端末のローカル日付、yyyy-mm-dd)。
  String _claimDay = '';

  /// ストアが使えるか。使えない環境では購入導線を出さない。
  bool storeAvailable = false;

  /// 表示用の価格。取得できていなければ null。
  String? priceLabel;

  int get dailyLimit =>
      isSupporter ? RewardOffer.dailyLimitSupporter : RewardOffer.dailyLimitFree;

  int get remainingToday => (dailyLimit - claimedToday).clamp(0, dailyLimit);

  /// いま特典を受け取れるか。
  ///
  /// サポーターは広告なしで受け取れる。無料の利用者は広告の在庫が
  /// 無いと受け取れない (押せるのに何も起きない状態を避ける)。
  bool get canClaim {
    if (remainingToday <= 0) return false;
    return isSupporter || _ads.isRewardedAdReady;
  }

  /// 広告の視聴が必要か。ボタンの文言を切り替えるために使う。
  bool get requiresAd => !isSupporter;

  static String _today() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    isSupporter = prefs.getBool(_supporterKey) ?? false;
    _claimDay = prefs.getString(_claimDayKey) ?? '';
    claimedToday = prefs.getInt(_claimCountKey) ?? 0;
    _rolloverIfNewDay();

    await _ads.initialize();
    await _purchases.initialize();
    storeAvailable = await _purchases.isAvailable();
    if (storeAvailable) priceLabel = await _purchases.priceLabel();

    initialized = true;
    notifyListeners();
  }

  /// 日付が変わっていたら回数を0に戻す。
  ///
  /// 端末の時計を戻せば回数を増やせてしまうが、対戦相手のいない
  /// 単独プレイのゲームで、しかも設定画面に資金追加機能がある以上、
  /// ここを厳密にしても守るものがない。サーバーを持つ理由にはならない。
  void _rolloverIfNewDay() {
    final today = _today();
    if (_claimDay != today) {
      _claimDay = today;
      claimedToday = 0;
    }
  }

  Future<void> _persistClaims() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claimDayKey, _claimDay);
    await prefs.setInt(_claimCountKey, claimedToday);
  }

  /// 特典の受け取りを試みる。
  ///
  /// 資金の加算はここでは行わない。ゲームの状態を触るのは GameState の
  /// 責務で、この層はストアと広告だけを見る。
  Future<ClaimResult> claimReward() async {
    _rolloverIfNewDay();
    if (remainingToday <= 0) return ClaimResult.limitReached;

    if (!isSupporter) {
      if (!_ads.isRewardedAdReady) return ClaimResult.unavailable;
      final watched = await _ads.showRewardedAd();
      // 途中で閉じた場合は回数を消費させない。
      if (!watched) return ClaimResult.adNotCompleted;
    }

    claimedToday++;
    await _persistClaims();
    notifyListeners();
    return ClaimResult.granted;
  }

  Future<PurchaseOutcome> buySupporter() async {
    final outcome = await _purchases.buySupporter();
    if (outcome == PurchaseOutcome.purchased) await _markSupporter();
    return outcome;
  }

  Future<PurchaseOutcome> restorePurchases() async {
    final outcome = await _purchases.restorePurchases();
    if (outcome == PurchaseOutcome.purchased) await _markSupporter();
    return outcome;
  }

  Future<void> _markSupporter() async {
    isSupporter = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_supporterKey, true);
    notifyListeners();
  }

  @override
  void dispose() {
    _ads.dispose();
    _purchases.dispose();
    super.dispose();
  }
}
