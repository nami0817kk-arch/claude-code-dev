/// 銀行から借り入れた融資。頭金なしで即座に資金を得られるが、毎週の返済が発生する。
class BankLoan {
  final String id;
  final int principal;
  final int weeklyRepayment;
  final int termWeeks;
  int weeksRemaining;

  BankLoan({
    required this.id,
    required this.principal,
    required this.weeklyRepayment,
    required this.termWeeks,
    required this.weeksRemaining,
  });

  /// 残りの返済総額。
  int get totalRemaining => weeklyRepayment * weeksRemaining;

  Map<String, dynamic> toJson() => {
        'id': id,
        'principal': principal,
        'weeklyRepayment': weeklyRepayment,
        'termWeeks': termWeeks,
        'weeksRemaining': weeksRemaining,
      };

  factory BankLoan.fromJson(Map<String, dynamic> json) => BankLoan(
        id: json['id'] as String,
        principal: json['principal'] as int,
        weeklyRepayment: json['weeklyRepayment'] as int,
        termWeeks: json['termWeeks'] as int? ?? json['weeksRemaining'] as int,
        weeksRemaining: json['weeksRemaining'] as int,
      );
}
