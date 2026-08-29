/// 他クラブから届いた、自クラブ所属選手への移籍オファー。
class IncomingOffer {
  final String id;
  final String playerId;
  final String playerName;
  final String buyerClubName;
  final int amount;
  int weeksRemaining;

  /// リリース条項の金額提示による自動成立オファーかどうか。
  /// trueの場合は交渉の余地なく必ず成立する。
  final bool viaReleaseClause;

  IncomingOffer({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.buyerClubName,
    required this.amount,
    this.weeksRemaining = 3,
    this.viaReleaseClause = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'playerId': playerId,
        'playerName': playerName,
        'buyerClubName': buyerClubName,
        'amount': amount,
        'weeksRemaining': weeksRemaining,
        'viaReleaseClause': viaReleaseClause,
      };

  factory IncomingOffer.fromJson(Map<String, dynamic> json) => IncomingOffer(
        id: json['id'] as String,
        playerId: json['playerId'] as String,
        playerName: json['playerName'] as String,
        buyerClubName: json['buyerClubName'] as String,
        amount: json['amount'] as int,
        weeksRemaining: json['weeksRemaining'] as int? ?? 3,
        viaReleaseClause: json['viaReleaseClause'] as bool? ?? false,
      );
}
