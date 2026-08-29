/// 定期預金の預入プラン。期間が長いほど利回り(満期時に得られる利息の割合)は
/// 高くなるが、その間は資金を引き出せず身動きが取れなくなるリスクを伴う。
class DepositTerm {
  final int weeks;
  final double interestRatePercent;

  const DepositTerm({required this.weeks, required this.interestRatePercent});

  String get label => weeks <= 12 ? '短期' : '長期';
}

class InvestmentEngine {
  static const List<DepositTerm> terms = [
    DepositTerm(weeks: 12, interestRatePercent: 5),
    DepositTerm(weeks: 26, interestRatePercent: 14),
  ];

  /// 満期時に受け取れる総額(元本+利息)。
  static int maturityValueFor(int principal, DepositTerm term) =>
      (principal * (1 + term.interestRatePercent / 100)).round();

  /// 満期時に得られる利息のみの額。
  static int interestFor(int principal, DepositTerm term) =>
      maturityValueFor(principal, term) - principal;
}
