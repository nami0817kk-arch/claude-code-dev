import 'dart:math';

import '../models/attributes.dart';
import '../models/cup.dart';
import '../models/match_result.dart';
import '../models/player.dart';
import '../models/team.dart';
import 'match_engine.dart';
import 'weather_engine.dart';
import '../l10n/tr.dart';

class CupEngine {
  static final Random _rng = Random();

  /// チームIDのリストからノックアウト方式のカップを作成する。
  /// 参加数が2の累乗でない場合は不戦勝(BYE)で埋める。BYE同士が対戦して
  /// 永久に決着しない事態を避けるため、各BYEは必ず実チーム1つと組ませる
  /// (2の累乗への切り上げである以上、BYE数は必ず組数の半分未満に収まる)。
  static Cup createKnockout({
    required CupType type,
    required String name,
    required List<String> teamIds,
  }) {
    if (teamIds.length < 2) {
      throw ArgumentError.value(
          teamIds,
          'teamIds',
          Tr.pick('ノックアウト方式のカップには最低2チーム必要です',
              'A knockout cup needs at least two teams'));
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
      final match = CupMatch(
        round: 1,
        homeTeamId: shuffled[idx],
        awayTeamId: byeTeamId,
      );
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
      firstRound.add(
        CupMatch(
          round: 1,
          homeTeamId: shuffled[idx],
          awayTeamId: shuffled[idx + 1],
        ),
      );
      idx += 2;
    }

    final cup = Cup(type: type, name: name, rounds: [firstRound]);
    _advanceRoundIfComplete(cup);
    return cup;
  }

  /// PK戦を1本ずつシミュレートし、キック順の記録つきで勝者を決める。
  /// ライブ観戦のフルタイム画面で「1本ごとの成否」を演出表示するために使う。
  /// CPU同士のクイック消化は従来通り[decidePenaltyWinner](重み付き抽選1回)で
  /// 軽量に決めるため両者の結果分布は厳密には一致しないが、どちらも
  /// チーム力・キッカーのPK/冷静さ・相手GKの一対一を反映する。
  static PenaltyShootoutResult simulateShootout(Team home, Team away) {
    List<Player> kickersOf(Team t) {
      double kickSkill(Player p) =>
          p.attributeValue(AttributeKeys.penalties) * 0.7 +
          p.attributeValue(AttributeKeys.composure) * 0.3;
      return MatchEngine.lineupOf(t)
          .where((p) => p.position.group != PositionGroup.gk)
          .toList()
        ..sort((a, b) => kickSkill(b).compareTo(kickSkill(a)));
    }

    double gkSkillOf(Team t) {
      final gks = MatchEngine.lineupOf(t)
          .where((p) => p.position.group == PositionGroup.gk)
          .toList();
      if (gks.isEmpty) return 50;
      return gks
              .map((p) => p.attributeValue(AttributeKeys.oneOnOnes))
              .reduce((a, b) => a + b) /
          gks.length;
    }

    final homeKickers = kickersOf(home);
    final awayKickers = kickersOf(away);
    final homeGk = gkSkillOf(home);
    final awayGk = gkSkillOf(away);

    bool kick(List<Player> kickers, int index, double defendingGk) {
      if (kickers.isEmpty) return _rng.nextDouble() < 0.5;
      final k = kickers[index % kickers.length];
      final skill = k.attributeValue(AttributeKeys.penalties) * 0.7 +
          k.attributeValue(AttributeKeys.composure) * 0.3;
      final prob = (0.75 + (skill - 50) / 200 - (defendingGk - 50) / 250)
          .clamp(0.35, 0.95);
      return _rng.nextDouble() < prob;
    }

    String kickerName(List<Player> kickers, int index) =>
        kickers.isEmpty ? '---' : kickers[index % kickers.length].name;

    final kicks = <PenaltyKick>[];
    var homeScore = 0;
    var awayScore = 0;
    var round = 0; // 完了した「両チーム1本ずつ」の往復数
    while (true) {
      final homeScored = kick(homeKickers, round, awayGk);
      if (homeScored) homeScore++;
      kicks.add(PenaltyKick(
        teamId: home.id,
        kickerName: kickerName(homeKickers, round),
        scored: homeScored,
      ));
      if (round < 5) {
        // ホームの残り本数は(4 - round)、アウェイはこの往復をまだ蹴って
        // いないので(5 - round)。届かなくなった時点で即終了する。
        if (homeScore > awayScore + (5 - round) ||
            awayScore > homeScore + (4 - round)) {
          break;
        }
      }

      final awayScored = kick(awayKickers, round, homeGk);
      if (awayScored) awayScore++;
      kicks.add(PenaltyKick(
        teamId: away.id,
        kickerName: kickerName(awayKickers, round),
        scored: awayScored,
      ));
      round++;
      if (round <= 4) {
        final rem = 5 - round;
        if (homeScore > awayScore + rem || awayScore > homeScore + rem) {
          break;
        }
      } else if (homeScore != awayScore) {
        // 5本ずつ終了後はサドンデス: 往復ごとに差がつけば終了。
        break;
      }
      // 異常系の安全弁: 30往復しても決まらなければ重み付き抽選で決める。
      if (round >= 30) {
        if (decidePenaltyWinner(home, away) == home.id) {
          homeScore++;
        } else {
          awayScore++;
        }
        break;
      }
    }
    return PenaltyShootoutResult(
      homeId: home.id,
      awayId: away.id,
      kicks: kicks,
      homeScore: homeScore,
      awayScore: awayScore,
      winnerId: homeScore > awayScore ? home.id : away.id,
    );
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
                  p.attributeValue(AttributeKeys.composure) * 0.3,
            ) /
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
  static MatchResult? playNextMatch(
    Cup cup,
    List<Team> allTeams, {
    int matchday = 0,
  }) {
    final match = cup.nextUnplayedMatch;
    if (match == null || match.isBye) return null;

    final home = allTeams.firstWhere((t) => t.id == match.homeTeamId);
    final away = allTeams.firstWhere((t) => t.id == match.awayTeamId);
    final result = MatchEngine.simulate(
      home: home,
      away: away,
      matchday: matchday,
      weather: WeatherEngine.roll(),
    );
    applyMatchResult(cup, allTeams, match, result);
    return result;
  }

  /// 外部(ライブ観戦)で確定した[result]を[match]に適用し、引き分けなら
  /// PK戦で勝者を決め、ラウンドが完了していれば次ラウンドを組む。
  /// 自クラブのカップ戦をライブ観戦で戦った場合に、シミュレートの代わりに
  /// この適用だけを行うための分離されたAPI。
  static void applyMatchResult(
    Cup cup,
    List<Team> allTeams,
    CupMatch match,
    MatchResult result,
  ) {
    match.result = result;
    if (result.homeGoals == result.awayGoals) {
      final home = allTeams.firstWhere((t) => t.id == match.homeTeamId);
      final away = allTeams.firstWhere((t) => t.id == match.awayTeamId);
      // ライブ観戦側で1本ずつのPK戦を先に実施済みの場合はその勝者を尊重する。
      match.penaltyWinnerId ??= decidePenaltyWinner(home, away);
    }
    _advanceRoundIfComplete(cup);
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
          awayTeamId: winners[i + 1],
        );
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
      0 => Tr.pick('決勝', 'Final'),
      1 => Tr.pick('準決勝', 'Semi-final'),
      2 => Tr.pick('準々決勝', 'Quarter-final'),
      _ => Tr.pick('第$round回戦', 'Round $round'),
    };
  }
}

/// PK戦の1本ぶんの記録(演出表示用)。
class PenaltyKick {
  final String teamId;
  final String kickerName;
  final bool scored;

  const PenaltyKick({
    required this.teamId,
    required this.kickerName,
    required this.scored,
  });
}

/// PK戦全体の記録。[CupEngine.simulateShootout]が返す。セーブには保存せず、
/// フルタイム画面の演出にのみ使う一時データ。
class PenaltyShootoutResult {
  final String homeId;
  final String awayId;
  final List<PenaltyKick> kicks;
  final int homeScore;
  final int awayScore;
  final String winnerId;

  const PenaltyShootoutResult({
    required this.homeId,
    required this.awayId,
    required this.kicks,
    required this.homeScore,
    required this.awayScore,
    required this.winnerId,
  });
}
