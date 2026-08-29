import 'dart:math';
import '../models/sponsor.dart';

class SponsorEngine {
  static final Random _rng = Random();

  static const _names = [
    '蒼海銀行',
    '白鷺自動車',
    '紅葉飲料',
    '北斗テック',
    '旭丘保険',
    '常盤エナジー',
    '朝霧食品',
    '東雲航空',
    '潮風モビリティ',
    '若鮎製薬',
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
          yearsRemaining: 3),
      SponsorDeal(name: shuffled[1], weeklyIncome: base, yearsRemaining: 2),
      SponsorDeal(
          name: shuffled[2],
          weeklyIncome: (base * 1.3).round(),
          yearsRemaining: 1),
    ];
  }
}
