/// スポンサー契約。週間収入と引き換えに一定期間(年単位)クラブに紐づく。
class SponsorDeal {
  String name;
  int weeklyIncome;
  int yearsRemaining;

  SponsorDeal({
    required this.name,
    required this.weeklyIncome,
    required this.yearsRemaining,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'weeklyIncome': weeklyIncome,
        'yearsRemaining': yearsRemaining,
      };

  factory SponsorDeal.fromJson(Map<String, dynamic> json) => SponsorDeal(
        name: json['name'] as String,
        weeklyIncome: json['weeklyIncome'] as int,
        yearsRemaining: _migrateYears(json),
      );

  /// 旧セーブ(契約を週数で管理していた版)からの移行用。
  static int _migrateYears(Map<String, dynamic> json) {
    final years = json['yearsRemaining'] as int?;
    if (years != null) return years;
    final legacyWeeks = json['weeksRemaining'] as int?;
    if (legacyWeeks == null) return 1;
    if (legacyWeeks <= 0) return 0;
    return (legacyWeeks / 52).ceil().clamp(1, 10);
  }
}
