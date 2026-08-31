import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// リワード広告の読み込みと表示。
///
/// 実装を差し替えられるようにしてあるのは、広告SDKがAndroid/iOSでしか
/// 動かないため。Web版・テスト・デスクトップでは何もしない実装を使う。
abstract class AdService {
  Future<void> initialize();

  /// 表示できる広告が手元にあるか。無ければボタンを押させない。
  bool get isRewardedAdReady;

  /// 広告を最後まで見せる。特典を与えてよい場合だけ true を返す。
  /// 途中で閉じられた場合は false。
  Future<bool> showRewardedAd();

  void dispose();
}

/// 広告を扱わない実装。Web版・テスト・広告を無効化した構成で使う。
class NoOpAdService implements AdService {
  @override
  Future<void> initialize() async {}

  @override
  bool get isRewardedAdReady => false;

  @override
  Future<bool> showRewardedAd() async => false;

  @override
  void dispose() {}
}

/// AdMob を使う実装。
///
/// 広告ユニットIDは --dart-define で渡す。既定値は Google が公開している
/// **テスト用ID**にしてある。自分のIDを設定し忘れたまま配信しても、
/// 本物の広告が出ず規約違反にならないようにするため。
///
///     flutter build appbundle --release \
///       --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-xxx/yyy \
///       --dart-define=ADMOB_REWARDED_IOS=ca-app-pub-xxx/zzz
class AdMobAdService implements AdService {
  static const _androidUnitId = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const _iosUnitId = String.fromEnvironment(
    'ADMOB_REWARDED_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );

  RewardedAd? _ad;
  bool _loading = false;

  static String get _unitId => Platform.isIOS ? _iosUnitId : _androidUnitId;

  /// 既定のテスト用IDのままか。設定画面に警告を出すために使う。
  static bool get isUsingTestUnitId =>
      _androidUnitId.startsWith('ca-app-pub-3940256099942544') ||
      _iosUnitId.startsWith('ca-app-pub-3940256099942544');

  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading || _ad != null) return;
    _loading = true;
    try {
      await RewardedAd.load(
        adUnitId: _unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _ad = ad;
            _loading = false;
          },
          onAdFailedToLoad: (error) {
            // 読み込み失敗は珍しくない(在庫切れ・通信断)。
            // 例外にせず、次に押されたときに読み直す。
            _ad = null;
            _loading = false;
          },
        ),
      );
    } catch (_) {
      _ad = null;
      _loading = false;
    }
  }

  @override
  bool get isRewardedAdReady => _ad != null;

  @override
  Future<bool> showRewardedAd() async {
    final ad = _ad;
    if (ad == null) {
      unawaited(_load());
      return false;
    }
    _ad = null;

    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(_load()); // 次回のために先読みしておく
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        unawaited(_load());
      },
    );

    await ad.show(onUserEarnedReward: (_, __) => earned = true);
    return earned;
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}

/// この端末で使う実装を選ぶ。
///
/// 広告SDKは Android/iOS 以外では動かないので、それ以外では
/// 何もしない実装を返す。Web版に広告は出ない。
AdService createAdService() {
  if (kIsWeb) return NoOpAdService();
  try {
    if (Platform.isAndroid || Platform.isIOS) return AdMobAdService();
  } catch (_) {
    // テスト環境など Platform を参照できない場合。
  }
  return NoOpAdService();
}
