import '../models/player.dart';
import '../models/team.dart';

/// 疲労の溜まったスタメンと、より疲労の少ないベンチの控え選手を
/// 入れ替えるローテーション提案。
class RotationSuggestion {
  final String tiredPlayerId;
  final String tiredPlayerName;
  final int tiredFatigue;
  final String replacementId;
  final String replacementName;
  final int replacementFatigue;

  RotationSuggestion({
    required this.tiredPlayerId,
    required this.tiredPlayerName,
    required this.tiredFatigue,
    required this.replacementId,
    required this.replacementName,
    required this.replacementFatigue,
  });
}

class RotationEngine {
  /// この疲労度以上のスタメンをローテーション対象とみなす。
  static const int fatigueThreshold = 65;

  /// 控え選手の疲労度がこれ以上低くなければ入れ替えを提案しない。
  static const int minFatigueImprovement = 20;

  /// 現在のスタメンのうち、疲労が溜まっており、かつ同ポジションをこなせる
  /// より疲労の少ないベンチ選手がいる場合に入れ替えを提案する。
  static List<RotationSuggestion> suggest(Team team) {
    final byId = {for (final p in team.players) p.id: p};
    final starters =
        team.startingXI.map((id) => byId[id]).whereType<Player>().toList();
    // 提案の中で同じ控え選手が複数のスタメンの交代先として重複しないよう、
    // 一度提案に使った選手はここから除外していく。
    final benched = team.players
        .where(
          (p) =>
              !team.startingXI.contains(p.id) &&
              !p.isInjured &&
              !p.isOnInternationalDuty &&
              !p.isLoanedOut &&
              !p.isSuspended,
        )
        .toList();

    final suggestions = <RotationSuggestion>[];
    for (final starter in starters) {
      if (starter.fatigue < fatigueThreshold) continue;
      final candidates = benched
          .where(
            (p) =>
                p.canPlay(starter.position) &&
                starter.fatigue - p.fatigue >= minFatigueImprovement,
          )
          .toList()
        ..sort((a, b) {
          final byFatigue = a.fatigue.compareTo(b.fatigue);
          if (byFatigue != 0) return byFatigue;
          return b.overall.compareTo(a.overall);
        });
      if (candidates.isEmpty) continue;
      final best = candidates.first;
      suggestions.add(
        RotationSuggestion(
          tiredPlayerId: starter.id,
          tiredPlayerName: starter.name,
          tiredFatigue: starter.fatigue,
          replacementId: best.id,
          replacementName: best.name,
          replacementFatigue: best.fatigue,
        ),
      );
      benched.remove(best);
    }
    return suggestions;
  }
}
