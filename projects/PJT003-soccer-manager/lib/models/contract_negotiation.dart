/// 契約交渉1回分の提示・対案のやり取りを表す。
class ContractNegotiation {
  final String playerId;
  final int initialWage;
  int offeredWage;
  int counterWage;
  int roundsUsed;

  ContractNegotiation({
    required this.playerId,
    required this.initialWage,
    required this.offeredWage,
    required this.counterWage,
    this.roundsUsed = 0,
  });

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'initialWage': initialWage,
        'offeredWage': offeredWage,
        'counterWage': counterWage,
        'roundsUsed': roundsUsed,
      };

  factory ContractNegotiation.fromJson(Map<String, dynamic> json) =>
      ContractNegotiation(
        playerId: json['playerId'] as String,
        initialWage: json['initialWage'] as int,
        offeredWage: json['offeredWage'] as int,
        counterWage: json['counterWage'] as int,
        roundsUsed: json['roundsUsed'] as int? ?? 0,
      );
}

/// 契約交渉で週俸を提示した結果。
enum ContractOfferResult {
  /// 提示額で合意し、契約が更新された。
  accepted,

  /// 提示額では折り合わず、選手側から対案が届いた(交渉継続)。
  countered,

  /// 選手の要求は満たしたが、クラブの資金が足りず更新できなかった。
  insufficientFunds,

  /// 交渉が規定回数を超え、選手が交渉から離脱した。
  walkedAway,
}
