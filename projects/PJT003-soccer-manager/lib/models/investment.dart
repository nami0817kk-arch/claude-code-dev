/// 銀行に預け入れた定期預金。満期までは引き出せない代わりに、満期時に
/// 元本に利息を上乗せした額をまとめて受け取れる(資金運用による資産形成)。
class FixedDeposit {
  final String id;
  final int principal;
  final int maturityValue;
  final int termWeeks;
  int weeksRemaining;

  FixedDeposit({
    required this.id,
    required this.principal,
    required this.maturityValue,
    required this.termWeeks,
    required this.weeksRemaining,
  });

  /// 満期時に得られる利息(元本を除いた純増分)。
  int get interestEarned => maturityValue - principal;

  Map<String, dynamic> toJson() => {
        'id': id,
        'principal': principal,
        'maturityValue': maturityValue,
        'termWeeks': termWeeks,
        'weeksRemaining': weeksRemaining,
      };

  factory FixedDeposit.fromJson(Map<String, dynamic> json) => FixedDeposit(
        id: json['id'] as String,
        principal: json['principal'] as int,
        maturityValue: json['maturityValue'] as int,
        termWeeks: json['termWeeks'] as int,
        weeksRemaining: json['weeksRemaining'] as int,
      );
}
