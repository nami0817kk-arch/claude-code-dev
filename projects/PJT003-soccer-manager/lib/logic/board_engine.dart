import '../models/league.dart';
import '../models/match_result.dart';

class BoardEngine {
  /// 現在のスカッド総合力から見て妥当な目標順位（1が最高位）を見積もる。
  static int estimateTargetRank(League league, String userTeamId) {
    final sorted = [...league.teams]
      ..sort((a, b) => b.overallRating.compareTo(a.overallRating));
    final idx = sorted.indexWhere((t) => t.id == userTeamId);
    return idx < 0 ? (league.teams.length / 2).ceil() : idx + 1;
  }

  /// 試合結果を受けて信頼度の増減量を返す。
  static int confidenceDeltaForMatch(MatchResult result, String userTeamId) {
    final isHome = result.homeTeamId == userTeamId;
    final userGoals = isHome ? result.homeGoals : result.awayGoals;
    final oppGoals = isHome ? result.awayGoals : result.homeGoals;
    if (userGoals > oppGoals) return 4;
    if (userGoals == oppGoals) return -1;
    return -6;
  }

  /// シーズン終了時の順位評価による信頼度の増減量を返す。
  static int confidenceDeltaForSeasonEnd(
      {required int finalRank, required int targetRank}) {
    if (finalRank <= targetRank) return 15;
    if (finalRank > targetRank + 2) return -20;
    return 0;
  }

  /// シーズン中盤(折り返し地点)の理事会レビューによる信頼度の増減量。
  /// シーズン終了時ほど大きくは動かないが、早期の軌道修正を促す。
  static int midSeasonReviewDelta(
      {required int currentRank, required int targetRank}) {
    if (currentRank <= targetRank) return 8;
    if (currentRank > targetRank + 3) return -12;
    return 0;
  }

  /// シーズン中盤レビューで理事会から届く講評文。
  static String midSeasonReviewMessage({
    required int currentRank,
    required int targetRank,
  }) {
    if (currentRank <= targetRank) {
      return '理事会からシーズン中盤レビュー: 現在$currentRank位と好調な滑り出しです。'
          'このまま$targetRank位以内を目指してください。';
    }
    if (currentRank > targetRank + 3) {
      return '理事会からシーズン中盤レビュー: 現在$currentRank位と目標の$targetRank位を'
          '大きく下回っています。残り試合での早急な立て直しを求めます。';
    }
    return '理事会からシーズン中盤レビュー: 現在$currentRank位。目標の$targetRank位以内に向けて、'
        '引き続き注視しています。';
  }

  /// 資金がマイナスのまま連続した週数がこの値に達するたびに信頼度が下がる。
  static const int negativeBudgetPenaltyThresholdWeeks = 8;

  /// 資金マイナスが続いている週数を受けて信頼度の増減量を返す。
  /// 閾値に達するたびに(閾値の倍数ごとに)ペナルティが発生する。
  static int negativeBudgetConfidenceDelta(int consecutiveNegativeWeeks) {
    if (consecutiveNegativeWeeks <= 0) return 0;
    if (consecutiveNegativeWeeks % negativeBudgetPenaltyThresholdWeeks != 0) {
      return 0;
    }
    return -8;
  }

  /// 最終順位に応じた賞金（万円）。
  static int seasonPrizeMoney(
      {required int finalRank, required int teamCount}) {
    final worst = teamCount;
    final ratio = worst <= 1 ? 1.0 : 1 - (finalRank - 1) / (worst - 1);
    return (300 + ratio * 2700).round();
  }
}
