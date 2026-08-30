import '../models/attributes.dart';
import '../models/player.dart';
import '../models/team.dart';

/// ロッカールームの社内序列(ダイナミクス)。リーダーシップ・実力・年齢
/// (とキャプテンの肩書)から影響力を算出し、上位数人をチームリーダーと
/// して扱う。リーダーの機嫌はロッカールーム全体の士気に波及し、リーダーを
/// 放出するとチームに動揺が走る。
class DynamicsEngine {
  /// チームリーダーとして扱う人数。
  static const int leaderCount = 3;

  /// リーダーが不機嫌(平均不満度がこの値未満)だと周囲の士気を下げる。
  static const int unhappyLeaderThreshold = 40;

  /// リーダーが上機嫌(平均不満度がこの値以上)だと周囲の士気を上げる。
  static const int happyLeaderThreshold = 75;

  /// リーダー放出時にチームメイト全員が受ける不満度ペナルティ。
  static const int leaderSalePenalty = 5;

  /// [p]のロッカールーム内での影響力。リーダーシップを最も重く、実力と
  /// 年齢(経験)を加味し、キャプテン/副キャプテンの肩書を上乗せする。
  static double influenceOf(Player p, Team team) {
    var score = p.attributeValue(AttributeKeys.leadership) * 0.5 +
        p.overall * 0.3 +
        (p.age.clamp(18, 34) - 18) * 1.2;
    if (team.captainId == p.id) score += 10;
    if (team.viceCaptainId == p.id) score += 5;
    return score;
  }

  /// 影響力上位[leaderCount]人のチームリーダー(ローン放出中は除く)。
  static List<Player> teamLeaders(Team team) {
    final candidates = team.players.where((p) => !p.isLoanedOut).toList()
      ..sort((a, b) => influenceOf(b, team).compareTo(influenceOf(a, team)));
    return candidates.take(leaderCount).toList();
  }

  static bool isTeamLeader(Team team, String playerId) =>
      teamLeaders(team).any((p) => p.id == playerId);
}
