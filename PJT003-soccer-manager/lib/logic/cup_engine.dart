import 'dart:math';
import '../models/attributes.dart';
import '../models/cup.dart';
import '../models/match_result.dart';
import '../models/player.dart';
import '../models/team.dart';
import 'match_engine.dart';
import 'weather_engine.dart';

class CupEngine {
  static final Random _rng = Random();

  /// チームIDのリストからノックアウト方式のカップを作成する。
  /// 参加数が2の累乗でない場合は不戦勝(BYE)で埋める。BYE同士が対戦して
  /// 永久に決着しない事態を避けるため、各BYEは必ず実チーム1つと組ませる
  /// (2の累乗への切り上げである以上、BYE数は必ず組数の半分未満に収まる)。
  static Cup createKnockout(
      {required CupType type,
      required String name,
      required List<String> teamIds}) {
    if (teamIds.length < 2) {
      throw ArgumentError.value(teamIds, 'teamIds', 'ノックアウト方式のカップには最低2チーム必要です');
    }
    final shuffled = [...teamIds]..shuffle(_rng);
    int size = 1;
    while (size < shuffled.length) {
      size *= 2;
    }
    final byeCount = size - shuffled.length;

    final firstRound = <CupMatch>[];
    var idx = 0;
    for (int i = 0; i < byeCount; i++) {
      final match =
          CupMatch(round: 1, homeTeamId: shuffled[idx], awayTeamId: byeTeamId);
      match.result = MatchResult(
        matchday: 0,
        homeTeamId: match.homeTeamId,
        awayTeamId: byeTeamId,
        homeGoals: 1,
        awayGoals: 0,
        events: [],
      );
      firstRound.add(match);
      idx++;
    }
    while (idx < shuffled.length) {
      firstRound.add(CupMatch(
          round: 1, homeTeamId: shuffled[idx], awayTeamId: shuffled[idx + 1]));
      idx += 2;
    }

    final cup = Cup(type: type, name: name, rounds: [firstRound]);
    _advanceRoundIfComplete(cup);
    return cup;
  }

  /// 引き分け時のPK戦勝者を、チーム総合力に加えてキッカーのPK精度・冷静さと
  /// 相手GKの一対一対応力を反映した重み付き抽選で決める。
  static String decidePenaltyWinner(Team home, Team away) {
    final homeStrength = _shootoutStrength(home, away);
    final awayStrength = _shootoutStrength(away, home);
    final totalMilli = ((homeStrength + awayStrength) * 1000).round();
    if (totalMilli <= 0) return _rng.nextBool() ? home.id : away.id;
    return _rng.nextInt(totalMilli) < (homeStrength * 1000).round()
        ? home.id
        : away.id;
  }

  /// PK戦における[attacking]チームの強さ。チーム総合力を基準に、
  /// キッカー役(フィールドプレーヤー)のPK精度・冷静さと、相手GKの
  /// 一対一対応力による減点を加味する。
  static double _shootoutStrength(Team attacking, Team defending) {
    final outfield = MatchEngine.lineupOf(attacking)
        .where((p) => p.position.group != PositionGroup.gk)
        .toList();
    final kickerSkill = outfield.isEmpty
        ? 50.0
        : outfield.fold<double>(
                0,
                (s, p) =>
                    s +
                    p.attributeValue(AttributeKeys.penalties) * 0.7 +
                    p.attributeValue(AttributeKeys.composure) * 0.3) /
            outfield.length;

    final defendingGk = MatchEngine.lineupOf(defending)
        .where((p) => p.position.group == PositionGroup.gk)
        .toList();
    final gkSkill = defendingGk.isEmpty
        ? 50.0
        : defendingGk
                .map((p) => p.attributeValue(AttributeKeys.oneOnOnes))
                .reduce((a, b) => a + b) /
            defendingGk.length;

    final strength = attacking.overallRating +
        (kickerSkill - 50) * 0.6 -
        (gkSkill - 50) * 0.4;
    return strength.clamp(1, 200);
  }

  /// カップの次の未消化試合を1試合消化する。試合結果を返す(BYE戦は既に消化済みなのでnullを返す)。
  static MatchResult? playNextMatch(Cup cup, List<Team> allTeams,
      {int matchday = 0}) {
    final match = cup.nextUnplayedMatch;
    if (match == null || match.isBye) return null;

    final home = allTeams.firstWhere((t) => t.id == match.homeTeamId);
    final away = allTeams.firstWhere((t) => t.id == match.awayTeamId);
    final result = MatchEngine.simulate(
        home: home,
        away: away,
        matchday: matchday,
        weather: WeatherEngine.roll());
    match.result = result;
    if (result.homeGoals == result.awayGoals) {
      match.penaltyWinnerId = decidePenaltyWinner(home, away);
    }
    _advanceRoundIfComplete(cup);
    return result;
  }

  static bool _advanceRoundIfComplete(Cup cup) {
    bool advancedAny = false;
    while (true) {
      final lastRound = cup.rounds.last;
      if (lastRound.any((m) => m.winnerId == null)) break;
      if (lastRound.length == 1) break;
      final winners = lastRound.map((m) => m.winnerId!).toList();
      final nextRoundNum = lastRound.first.round + 1;
      final nextMatches = <CupMatch>[];
      for (int i = 0; i < winners.length; i += 2) {
        final match = CupMatch(
            round: nextRoundNum,
            homeTeamId: winners[i],
            awayTeamId: winners[i + 1]);
        if (match.isBye) {
          match.result = MatchResult(
            matchday: 0,
            homeTeamId: match.homeTeamId,
            awayTeamId: match.awayTeamId,
            homeGoals: match.awayTeamId == byeTeamId ? 1 : 0,
            awayGoals: match.homeTeamId == byeTeamId ? 1 : 0,
            events: [],
          );
        }
        nextMatches.add(match);
      }
      cup.rounds.add(nextMatches);
      advancedAny = true;
    }
    return advancedAny;
  }

  /// ラウンド数に応じたラウンド名(準々決勝・準決勝・決勝など)。
  static String roundLabel(int round, int totalRounds) {
    final fromFinal = totalRounds - round;
    return switch (fromFinal) {
      0 => '決勝',
      1 => '準決勝',
      2 => '準々決勝',
      _ => '第$round回戦',
    };
  }
}
