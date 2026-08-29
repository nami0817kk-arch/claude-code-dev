/// 選手1人の今シーズンの成績集計(リーグ戦の消化済み試合から都度算出する。保存はしない)。
class PlayerSeasonStats {
  final int appearances;
  final int goals;
  final int yellowCards;
  final int redCards;

  /// 出場試合の平均採点(1試合も出場していない場合はnull)。
  final double? averageRating;

  const PlayerSeasonStats({
    this.appearances = 0,
    this.goals = 0,
    this.yellowCards = 0,
    this.redCards = 0,
    this.averageRating,
  });
}
