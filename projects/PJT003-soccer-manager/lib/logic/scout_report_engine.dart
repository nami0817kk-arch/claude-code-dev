import '../models/player.dart';
import '../models/team.dart';
import 'match_engine.dart';
import 'style_engine.dart';
import 'tactics_ai.dart';
import '../l10n/tr.dart';

/// アシスタントコーチによる対戦相手のスカウティングレポート。
class ScoutReport {
  final String opponentName;
  final int opponentOverall;
  final int opponentAttack;
  final int opponentDefense;
  final int opponentTechnique;
  final int opponentStamina;
  final List<String> strengths;
  final List<String> weaknesses;
  final String? keyPlayerId;
  final String? keyPlayerName;
  final String? keyPlayerDetail;
  final String recommendation;

  /// 相手が採用してくると予想される戦術スタイル。
  final TacticalStyle opponentStyle;

  /// 相手のスタイルに対して相性で有利を取れるスタイル(相手が柔軟ならnull)。
  final TacticalStyle? counterStyle;

  const ScoutReport({
    required this.opponentName,
    required this.opponentOverall,
    required this.opponentAttack,
    required this.opponentDefense,
    required this.opponentTechnique,
    required this.opponentStamina,
    required this.strengths,
    required this.weaknesses,
    required this.keyPlayerId,
    required this.keyPlayerName,
    required this.keyPlayerDetail,
    required this.recommendation,
    this.opponentStyle = TacticalStyle.flexible,
    this.counterStyle,
  });
}

class ScoutReportEngine {
  static int _average(List<Player> players, int Function(Player) selector) {
    if (players.isEmpty) return 0;
    final total = players.fold<int>(0, (s, p) => s + selector(p));
    return (total / players.length).round();
  }

  static ScoutReport generateFor({
    required Team opponent,
    required Team userTeam,
  }) {
    final oppLineup = MatchEngine.lineupOf(opponent);
    final userLineup = MatchEngine.lineupOf(userTeam);

    final oppAttack = _average(oppLineup, (p) => p.attack);
    final oppDefense = _average(oppLineup, (p) => p.defense);
    final oppTechnique = _average(oppLineup, (p) => p.technique);
    final oppStamina = _average(oppLineup, (p) => p.stamina);

    final userAttack = _average(userLineup, (p) => p.attack);
    final userDefense = _average(userLineup, (p) => p.defense);
    final userTechnique = _average(userLineup, (p) => p.technique);
    final userStamina = _average(userLineup, (p) => p.stamina);

    final strengths = <String>[];
    final weaknesses = <String>[];
    void compare(String label, int opp, int user) {
      final diff = opp - user;
      if (diff >= 6) {
        strengths.add(label);
      } else if (diff <= -6) {
        weaknesses.add(label);
      }
    }

    compare(Tr.pick('攻撃力', 'Attack'), oppAttack, userAttack);
    compare(Tr.pick('守備力', 'Defence'), oppDefense, userDefense);
    compare(Tr.pick('技術', 'Technical'), oppTechnique, userTechnique);
    compare(Tr.pick('スタミナ', 'Stamina'), oppStamina, userStamina);

    Player? keyPlayer;
    for (final p in oppLineup) {
      if (keyPlayer == null || p.overall > keyPlayer.overall) keyPlayer = p;
    }

    final String recommendation;
    if (oppAttack - userDefense > 8) {
      recommendation = Tr.pick('相手の攻撃力が高いため、守備を固める戦術を推奨します。',
          'They carry a real attacking threat, so shoring up the defence is advised.');
    } else if (userAttack - oppDefense > 8) {
      recommendation = Tr.pick(
          '相手の守備は手薄です。積極的に攻め込みましょう。', 'Their defence is thin. Go at them.');
    } else if (oppStamina - userStamina > 8) {
      recommendation = Tr.pick('相手はスタミナに優れています。終盤の運動量低下に注意してください。',
          'They are strong on stamina. Watch for your side dropping off late on.');
    } else {
      recommendation = Tr.pick('拮抗した実力差です。試合の流れを重視した戦術が有効でしょう。',
          'There is little between the sides. Tactics that play the momentum should serve you well.');
    }

    // CPUが試合前に選ぶロジックと同じ判定で相手のスタイルを予想する
    // (ユーザー同士の対戦はないため、予想は実際の採用スタイルと一致する)。
    final oppStyle = CpuTacticsAI.styleFor(opponent);
    TacticalStyle? counterStyle;
    if (oppStyle != TacticalStyle.flexible) {
      for (final entry in StyleEngine.beats.entries) {
        if (entry.value == oppStyle) {
          counterStyle = entry.key;
          break;
        }
      }
    }

    return ScoutReport(
      opponentName: opponent.name,
      opponentOverall: opponent.overallRating,
      opponentAttack: oppAttack,
      opponentDefense: oppDefense,
      opponentTechnique: oppTechnique,
      opponentStamina: oppStamina,
      strengths: strengths,
      weaknesses: weaknesses,
      keyPlayerId: keyPlayer?.id,
      keyPlayerName: keyPlayer?.name,
      keyPlayerDetail: keyPlayer == null
          ? null
          : Tr.pick('${keyPlayer.position.label} / 総合 ${keyPlayer.overall}',
              '${keyPlayer.position.label} / overall ${keyPlayer.overall}'),
      recommendation: recommendation,
      opponentStyle: oppStyle,
      counterStyle: counterStyle,
    );
  }
}
