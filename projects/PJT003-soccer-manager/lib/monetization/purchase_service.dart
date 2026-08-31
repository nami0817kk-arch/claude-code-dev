import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// サポーター購入(買い切り・非消費型)の結果。
enum PurchaseOutcome {
  /// 購入が成立した、または過去の購入が復元された。
  purchased,

  /// 利用者が自分で取りやめた。エラー扱いにしない。
  canceled,

  /// ストアに繋がらない、商品が見つからないなど。
  unavailable,

  /// ストアから失敗が返った。
  failed,
}

/// サポーター購入の窓口。
///
/// 広告を任意視聴にしてある以上、「広告を消す」だけの購入では買っても
/// 何も変わらない。この購入は「広告を見ずに同じ特典を受け取れる」ものとして
/// 設計している (回数上限は RewardOffer を参照)。
abstract class PurchaseService {
  /// 商品IDはストア側の登録と一致させること。
  static const String supporterProductId = 'soccer_manager_supporter';

  Future<void> initialize();

  /// ストアが使えるか。使えなければ購入ボタンを出さない。
  Future<bool> isAvailable();

  /// 表示用の価格 (「¥480」など)。取得できなければ null。
  Future<String?> priceLabel();

  Future<PurchaseOutcome> buySupporter();

  /// 機種変更・再インストール後に購入済み状態を戻す。
  /// iOS は復元導線の提供が審査要件になっている。
  Future<PurchaseOutcome> restorePurchases();

  void dispose();
}

/// 課金を扱わない実装。Web版・テストで使う。
class NoOpPurchaseService implements PurchaseService {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<String?> priceLabel() async => null;

  @override
  Future<PurchaseOutcome> buySupporter() async => PurchaseOutcome.unavailable;

  @override
  Future<PurchaseOutcome> restorePurchases() async =>
      PurchaseOutcome.unavailable;

  @override
  void dispose() {}
}

/// ストアの課金基盤を使う実装。
class StorePurchaseService implements PurchaseService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// 購入・復元の完了を待つための受け皿。
  /// 課金の結果はストリームで非同期に返ってくるため、
  /// 呼び出し側が await できる形に変換している。
  Completer<PurchaseOutcome>? _pending;

  ProductDetails? _product;

  @override
  Future<void> initialize() async {
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (_) => _complete(PurchaseOutcome.failed),
    );
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID != PurchaseService.supporterProductId) continue;

      switch (purchase.status) {
        case PurchaseStatus.pending:
          continue;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _complete(PurchaseOutcome.purchased);
        case PurchaseStatus.canceled:
          _complete(PurchaseOutcome.canceled);
        case PurchaseStatus.error:
          _complete(PurchaseOutcome.failed);
      }

      // 完了通知を返さないと、ストアが同じ購入を送り続ける。
      if (purchase.pendingCompletePurchase) {
        unawaited(_iap.completePurchase(purchase));
      }
    }
  }

  void _complete(PurchaseOutcome outcome) {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    _pending = null;
    pending.complete(outcome);
  }

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _iap.isAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<ProductDetails?> _loadProduct() async {
    if (_product != null) return _product;
    final response =
        await _iap.queryProductDetails({PurchaseService.supporterProductId});
    if (response.productDetails.isEmpty) return null;
    return _product = response.productDetails.first;
  }

  @override
  Future<String?> priceLabel() async {
    try {
      return (await _loadProduct())?.price;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PurchaseOutcome> buySupporter() async {
    try {
      final product = await _loadProduct();
      if (product == null) return PurchaseOutcome.unavailable;

      final completer = Completer<PurchaseOutcome>();
      _pending = completer;
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        _pending = null;
        return PurchaseOutcome.failed;
      }
      // ストアの画面から戻ってこない場合に永久に待たないよう上限を置く。
      return await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => PurchaseOutcome.canceled,
      );
    } catch (_) {
      _pending = null;
      return PurchaseOutcome.failed;
    }
  }

  @override
  Future<PurchaseOutcome> restorePurchases() async {
    try {
      final completer = Completer<PurchaseOutcome>();
      _pending = completer;
      await _iap.restorePurchases();
      // 購入履歴が無い場合はストリームに何も流れてこないので、
      // 待ち続けずに「対象なし」で返す。
      return await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => PurchaseOutcome.unavailable,
      );
    } catch (_) {
      _pending = null;
      return PurchaseOutcome.failed;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

PurchaseService createPurchaseService() =>
    kIsWeb ? NoOpPurchaseService() : StorePurchaseService();
