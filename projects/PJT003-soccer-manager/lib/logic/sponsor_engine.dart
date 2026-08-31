import 'dart:math';

import '../models/sponsor.dart';
import '../l10n/tr.dart';

class SponsorEngine {
  static final Random _rng = Random();

  // スポンサー名は架空の企業名。表示時の言語で選ぶため const にできない。
  static List<String> get _names => [
        Tr.pick('蒼海銀行', 'Bluewater Bank'),
        Tr.pick('白鷺自動車', 'Heron Motors'),
        Tr.pick('紅葉飲料', 'Maple Drinks'),
        Tr.pick('北斗テック', 'Northstar Tech'),
        Tr.pick('旭丘保険', 'Sunhill Insurance'),
        Tr.pick('常盤エナジー', 'Evergreen Energy'),
        Tr.pick('朝霧食品', 'Morningmist Foods'),
        Tr.pick('東雲航空', 'Daybreak Airways'),
        Tr.pick('潮風モビリティ', 'Seabreeze Mobility'),
        Tr.pick('若鮎製薬', 'Riverfin Pharma'),
      ];

  /// チームの総合力に応じたスポンサー候補を3件生成する。
  /// 週間収入が高いほど契約期間(年単位)は短くなるトレードオフを持つ。
  static List<SponsorDeal> generateOffers(int overallRating) {
    final base = 40 + overallRating.clamp(0, 99);
    final shuffled = ([..._names]..shuffle(_rng)).take(3).toList();
    return [
      SponsorDeal(
        name: shuffled[0],
        weeklyIncome: (base * 0.8).round(),
        yearsRemaining: 3,
      ),
      SponsorDeal(name: shuffled[1], weeklyIncome: base, yearsRemaining: 2),
      SponsorDeal(
        name: shuffled[2],
        weeklyIncome: (base * 1.3).round(),
        yearsRemaining: 1,
      ),
    ];
  }
}
