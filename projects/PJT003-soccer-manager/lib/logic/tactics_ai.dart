import '../models/team.dart';
import 'style_engine.dart';

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

  /// CPUクラブが戦術スタイルを名乗るのに必要な最低適性。5つの専門スタイル
  /// のどれもこの値に届かないスカッドは、無理に型へはめず柔軟で戦う。
  static const double styleSuitabilityThreshold = 0.45;

  /// スカッドの適性が最も高い戦術スタイルを選ぶ(全て低ければ柔軟)。
  static TacticalStyle styleFor(Team t) {
    var best = TacticalStyle.flexible;
    var bestFit = styleSuitabilityThreshold;
    for (final style in TacticalStyle.values) {
      if (style == TacticalStyle.flexible) continue;
      final fit = StyleEngine.suitability(t, style);
      if (fit > bestFit) {
        bestFit = fit;
        best = style;
      }
    }
    return best;
  }

  /// [home]対[away]のCPU側([userTeamId]以外)のメンタリティと戦術スタイルを
  /// 試合前に設定する。ユーザーのチームには触れない。
  static void applyPreMatch(Team home, Team away, String userTeamId) {
    if (home.id != userTeamId) {
      home.mentality = mentalityFor(
        ownRating: home.overallRating,
        opponentRating: away.overallRating,
      );
      home.tacticalStyle = styleFor(home);
    }
    if (away.id != userTeamId) {
      away.mentality = mentalityFor(
        ownRating: away.overallRating,
        opponentRating: home.overallRating,
      );
      away.tacticalStyle = styleFor(away);
    }
  }
}
