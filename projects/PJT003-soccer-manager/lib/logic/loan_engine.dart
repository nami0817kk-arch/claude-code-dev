/// 融資の返済プラン。期間が長いほど利率(総支払額に占める利息の割合)は高くなるが、
/// 週あたりの返済額は抑えられる。
class LoanTerm {
  final int weeks;
  final double interestRatePercent;

  const LoanTerm({required this.weeks, required this.interestRatePercent});

  String get label => weeks <= 12 ? '短期' : '長期';
}

class LoanEngine {
  static const List<LoanTerm> terms = [
    LoanTerm(weeks: 12, interestRatePercent: 8),
    LoanTerm(weeks: 26, interestRatePercent: 18),
  ];

  /// スタジアムのレベルと監督への世間の評価が高いほど、銀行からの信用が高く借入上限が上がる。
  /// 既存の融資残高はその分だけ借入余力から差し引かれる。
  static int maxBorrowable({
    required int stadiumLevel,
    required int reputation,
    required int outstandingDebt,
  }) {
    final capacity = 1500 + stadiumLevel * 500 + reputation * 15;
    return (capacity - outstandingDebt).clamp(0, capacity);
  }

  static int weeklyRepaymentFor(int principal, LoanTerm term) =>
      (principal * (1 + term.interestRatePercent / 100) / term.weeks).round();

  static int totalRepaymentFor(int principal, LoanTerm term) =>
      weeklyRepaymentFor(principal, term) * term.weeks;
}
