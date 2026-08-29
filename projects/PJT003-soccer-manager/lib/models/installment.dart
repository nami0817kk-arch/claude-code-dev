/// 分割払いで獲得した選手の残金支払い予定。
class Installment {
  String description;
  int weeklyAmount;
  int weeksRemaining;

  /// この分割払いの対象選手。売却・引き抜きで手放した際に残金請求を
  /// 打ち切れるよう紐付ける(旧セーブにはないため復元時はnullになりうる)。
  String? playerId;

  Installment({
    required this.description,
    required this.weeklyAmount,
    required this.weeksRemaining,
    this.playerId,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'weeklyAmount': weeklyAmount,
        'weeksRemaining': weeksRemaining,
        'playerId': playerId,
      };

  factory Installment.fromJson(Map<String, dynamic> json) => Installment(
        description: json['description'] as String,
        weeklyAmount: json['weeklyAmount'] as int,
        weeksRemaining: json['weeksRemaining'] as int,
        playerId: json['playerId'] as String?,
      );
}
