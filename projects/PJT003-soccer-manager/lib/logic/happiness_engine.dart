import '../models/player.dart';
import '../models/team.dart';

/// 選手の不満度(happiness)を週次で更新する。出場機会・待遇・チーム成績の
/// 3要素を性格ごとの感度で重み付けする。
class HappinessEngine {
  static void applyWeekly(
    Team team, {
    required int leagueRank,
    required int boardTargetRank,
  }) {
    for (final p in team.players) {
      // ローン放出中・出場停止中・代表召集中の選手は、そもそも自クラブの
      // スタメンに入りようがないため「ベンチ扱いの不満」を適用しない。
      if (p.isInjured ||
          p.isLoanedOut ||
          p.isSuspended ||
          p.isOnInternationalDuty) {
        continue;
      }
      final personality = p.personality;
      var delta = 0;

      final started = team.startingXI.contains(p.id);
      if (started) {
        delta += 3;
      } else {
        final benchPenalty = p.overall >= 65 ? 4 : 2;
        delta -= (benchPenalty * personality.benchSensitivity).round();
      }

      final fairWage = (p.marketValue / 40).round().clamp(5, 999);
      if (p.wage < fairWage * 0.7) {
        delta -= (2 * personality.wageSensitivity).round();
      } else if (p.wage >= fairWage) {
        delta += 1;
      }

      if (leagueRank <= boardTargetRank) {
        delta += 1;
      } else if (leagueRank > boardTargetRank + 2) {
        delta -= (2 * personality.resultSensitivity).round();
      }

      p.happiness = (p.happiness + delta).clamp(0, 100);
      if (p.reassureCooldownWeeks > 0) p.reassureCooldownWeeks -= 1;
    }
  }

  /// 選手と話し合い、不満度を引き上げる。連発を防ぐため不満度が高いうちは
  /// 効果がなく、実施後は[reassureCooldownWeeks]の間は再実施できない。
  static const int reassureThreshold = 70;
  static const int reassureBoost = 20;
  static const int reassureCooldownWeeks = 4;

  static bool reassure(Player p) {
    if (p.happiness >= reassureThreshold) return false;
    if (p.reassureCooldownWeeks > 0) return false;
    p.happiness = (p.happiness + reassureBoost).clamp(0, 100);
    p.reassureCooldownWeeks = reassureCooldownWeeks;
    return true;
  }
}
