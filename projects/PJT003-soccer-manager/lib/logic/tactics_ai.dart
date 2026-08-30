import '../models/team.dart';

/// CPUクラブの簡易的な戦術AI。試合前に対戦相手との力関係を見て、
/// チームメンタリティを選ぶ(格上相手には引いて守り、格下相手には
/// 攻勢をかける)。ユーザーのチームには一切適用しない。
class CpuTacticsAI {
  /// 総合力差からメンタリティを決める閾値(この差以上で1段階動く)。
  static const int mildGapThreshold = 4;
  static const int bigGapThreshold = 10;

  static TeamMentality mentalityFor({
    required int ownRating,
    required int opponentRating,
  }) {
    final diff = ownRating - opponentRating;
    if (diff >= bigGapThreshold) return TeamMentality.veryAttacking;
    if (diff >= mildGapThreshold) return TeamMentality.attacking;
    if (diff <= -bigGapThreshold) return TeamMentality.veryDefensive;
    if (diff <= -mildGapThreshold) return TeamMentality.defensive;
    return TeamMentality.balanced;
  }

  /// [home]対[away]のCPU側([userTeamId]以外)のメンタリティを試合前に
  /// 設定する。ユーザーのチームには触れない。
  static void applyPreMatch(Team home, Team away, String userTeamId) {
    if (home.id != userTeamId) {
      home.mentality = mentalityFor(
        ownRating: home.overallRating,
        opponentRating: away.overallRating,
      );
    }
    if (away.id != userTeamId) {
      away.mentality = mentalityFor(
        ownRating: away.overallRating,
        opponentRating: home.overallRating,
      );
    }
  }
}
