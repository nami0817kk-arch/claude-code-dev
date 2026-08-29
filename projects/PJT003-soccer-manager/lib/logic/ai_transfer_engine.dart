import 'dart:math';
import '../models/team.dart';
import 'lineup_utils.dart';

/// ユーザーが関与しないCPUクラブ同士の移籍市場を活性化させるための簡易エンジン。
/// 資金のやり取りは行わず、選手が移籍する「ニュース」のみを生成する。
class AiTransferEngine {
  static const double weeklyProbability = 0.35;

  /// 選手の実力(総合力)に対して、行き先クラブの平均総合力がこの値を下回って
  /// いなければ「実力に見合う移籍先」とみなす。
  static const int fitMargin = 5;

  /// CPUクラブが受け入れ可能なスカッドの上限(ユーザークラブの上限と同じ)。
  /// これがないと「人気クラブ」に選手が際限なく集まってしまう。
  static const int maxSquadSize = 26;

  /// [teams]の中からユーザークラブ([userTeamId])を除いたCPUクラブ同士で、
  /// 一定確率で1件の移籍を成立させる。成立した場合はニュース文言を返す。
  /// 移籍先は完全ランダムではなく、選手の実力に見合う(平均総合力が近い、
  /// または上回る)クラブを優先的に選ぶ。該当クラブがなければ全候補から選ぶ
  /// (格下クラブへの放出も一定割合で起こり得るようにする)。
  static String? maybeGenerate(
      List<Team> teams, String userTeamId, Random random) {
    if (random.nextDouble() > weeklyProbability) return null;

    final cpuTeams = teams.where((t) => t.id != userTeamId).toList()
      ..shuffle(random);
    if (cpuTeams.length < 2) return null;

    for (final fromTeam in cpuTeams) {
      // 選手層が薄いクラブからは引き抜かない。
      if (fromTeam.players.length <= 16) continue;
      final eligible = fromTeam.players
          .where((p) => !p.isLoanedOut && !p.isInjured)
          .toList();
      if (eligible.isEmpty) continue;

      eligible.shuffle(random);
      final player = eligible.first;

      final toCandidates = cpuTeams
          .where((t) => t.id != fromTeam.id && t.players.length < maxSquadSize)
          .toList();
      if (toCandidates.isEmpty) continue;
      final fittingClubs = toCandidates
          .where((t) => t.overallRating >= player.overall - fitMargin)
          .toList();
      final pool = fittingClubs.isNotEmpty ? fittingClubs : toCandidates;
      final toTeam = pool[random.nextInt(pool.length)];

      fromTeam.players.remove(player);
      final wasStarter = fromTeam.startingXI.remove(player.id);
      if (fromTeam.captainId == player.id) fromTeam.captainId = null;
      if (fromTeam.viceCaptainId == player.id) fromTeam.viceCaptainId = null;
      if (fromTeam.penaltyTakerId == player.id) fromTeam.penaltyTakerId = null;
      if (fromTeam.freeKickTakerId == player.id) {
        fromTeam.freeKickTakerId = null;
      }
      if (fromTeam.cornerTakerId == player.id) fromTeam.cornerTakerId = null;
      if (fromTeam.manMarkerId == player.id) fromTeam.manMarkerId = null;
      if (fromTeam.setPieceDefenderId == player.id) {
        fromTeam.setPieceDefenderId = null;
      }
      if (wasStarter) LineupUtils.autoFill(fromTeam);
      toTeam.players.add(player);
      player.contractYearsRemaining = 2 + random.nextInt(3);
      // 移籍直後の不満度は、元クラブでの状態からの落差(環境変化)を軽く
      // 反映しつつ、より力のあるクラブへの移籍ならやや上向きにする。
      final moveUp = toTeam.overallRating >= fromTeam.overallRating;
      player.happiness = (player.happiness + (moveUp ? 8 : -8)).clamp(40, 90);
      return '${player.name}が${fromTeam.name}から${toTeam.name}へ移籍しました。';
    }
    return null;
  }
}
