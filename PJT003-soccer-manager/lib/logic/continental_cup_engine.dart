import 'dart:math';
import '../models/continental_cup.dart';
import '../models/cup.dart';
import '../models/league.dart';
import '../models/match_result.dart';
import '../models/team.dart';
import 'cup_engine.dart';
import 'match_engine.dart';
import 'weather_engine.dart';

/// 大陸カップ: グループステージ(4チーム総当たり)+決勝トーナメント
/// (準決勝はホーム&アウェイ2試合合計、決勝は1試合)を管理する。
class ContinentalCupEngine {
  static final Random _rng = Random();

  /// 1グループあたりのチーム数。
  static const int groupSize = 4;

  /// [teamIds]を[groupSize]チームずつのグループに振り分け、各組の総当たり
  /// (1回戦制)の対戦表を生成する。
  static ContinentalCup create(
      {required String name, required List<String> teamIds}) {
    final shuffled = [...teamIds]..shuffle(_rng);
    final groups = <List<String>>[];
    for (var i = 0; i < shuffled.length; i += groupSize) {
      final end =
          (i + groupSize < shuffled.length) ? i + groupSize : shuffled.length;
      groups.add(shuffled.sublist(i, end));
    }

    final perGroupMatches = groups.map(_groupRoundRobin).toList();
    const maxRound = groupSize - 1;
    final matches = <CupMatch>[];
    for (int round = 1; round <= maxRound; round++) {
      for (final groupMatches in perGroupMatches) {
        matches.addAll(groupMatches.where((m) => m.round == round));
      }
    }
    return ContinentalCup(name: name, groups: groups, groupMatches: matches);
  }

  /// 総当たり(circle method)。組の人数が奇数の場合は不戦(BYE)枠を
  /// 挟んで偶数扱いにし、BYEが絡む組み合わせだけ除外する
  /// (FixtureGenerator.generateDoubleRoundRobinと同じ考え方)。
  static List<CupMatch> _groupRoundRobin(List<String> teamIds) {
    final ids = List<String>.from(teamIds);
    final hasBye = ids.length.isOdd;
    if (hasBye) ids.add(byeTeamId);

    final n = ids.length;
    final arr = List<String>.from(ids);
    final rounds = n - 1;
    final half = n ~/ 2;
    final matches = <CupMatch>[];
    for (int r = 0; r < rounds; r++) {
      for (int i = 0; i < half; i++) {
        final home = arr[i];
        final away = arr[n - 1 - i];
        if (home == byeTeamId || away == byeTeamId) continue;
        matches.add(CupMatch(round: r + 1, homeTeamId: home, awayTeamId: away));
      }
      final last = arr.removeLast();
      arr.insert(1, last);
    }
    return matches;
  }

  /// 指定した組の順位表(勝点順。並んだ場合は直接対決優先)。
  static List<StandingRow> groupStandings(
      ContinentalCup cup, int groupIndex, List<Team> allTeams) {
    final ids = cup.groups[groupIndex].toSet();
    final groupTeams = allTeams.where((t) => ids.contains(t.id)).toList();
    final fixtures = cup.groupMatches
        .where((m) => ids.contains(m.homeTeamId) && ids.contains(m.awayTeamId))
        .map((m) => Fixture(
            matchday: m.round,
            homeTeamId: m.homeTeamId,
            awayTeamId: m.awayTeamId,
            result: m.result))
        .toList();
    return League(teams: groupTeams, fixtures: fixtures).sortedStandings;
  }

  /// グループステージの次の未消化試合(全組を通じて先頭のもの)。
  static CupMatch? nextGroupMatch(ContinentalCup cup) {
    for (final m in cup.groupMatches) {
      if (m.result == null) return m;
    }
    return null;
  }

  /// グループステージの次の1試合を消化する。全試合が終わると自動的に
  /// 決勝トーナメントの組み合わせが決定される。
  static MatchResult? playNextGroupMatch(
      ContinentalCup cup, List<Team> allTeams) {
    final match = nextGroupMatch(cup);
    if (match == null) return null;
    final home = allTeams.firstWhere((t) => t.id == match.homeTeamId);
    final away = allTeams.firstWhere((t) => t.id == match.awayTeamId);
    final result = MatchEngine.simulate(
        home: home,
        away: away,
        matchday: match.round,
        weather: WeatherEngine.roll());
    match.result = result;
    if (cup.isGroupStageComplete) {
      _startKnockout(cup, allTeams);
    }
    return result;
  }

  /// 各組の上位2チームから決勝トーナメント(準決勝)を組む。同組同士が
  /// 準決勝で当たらないよう、他組の2位とクロスで組み合わせる。
  static void _startKnockout(ContinentalCup cup, List<Team> allTeams) {
    if (cup.knockoutRounds.isNotEmpty) return;
    final qualifiers = <List<String>>[];
    for (int g = 0; g < cup.groups.length; g++) {
      final standings = groupStandings(cup, g, allTeams);
      qualifiers.add(standings.take(2).map((r) => r.teamId).toList());
    }
    if (qualifiers.length < 2) return;
    // 各組の1位を、隣の組(添字+1、末尾は先頭へ循環)の2位とクロスで
    // 組み合わせる。組数が2の場合は従来通りの組み合わせになる。
    final groupCount = qualifiers.length;
    final semis = <CupTie>[
      for (int g = 0; g < groupCount; g++)
        CupTie(
          round: 1,
          teamAId: qualifiers[g][0],
          teamBId: qualifiers[(g + 1) % groupCount][1],
        ),
    ];
    cup.knockoutRounds.add(semis);
  }

  /// 決勝トーナメントの次の未消化レグを1試合消化する(2ndレグはホーム/
  /// アウェイを入れ替える)。合計スコアが同点の場合はPK戦で決着する。
  static MatchResult? playNextKnockoutLeg(
      ContinentalCup cup, List<Team> allTeams) {
    if (cup.knockoutRounds.isEmpty) return null;
    final round = cup.knockoutRounds.last;
    for (final tie in round) {
      if (tie.isComplete) continue;
      final isFirstLeg = tie.legs.isEmpty;
      final homeId = (tie.singleLeg || isFirstLeg) ? tie.teamAId : tie.teamBId;
      final awayId = (tie.singleLeg || isFirstLeg) ? tie.teamBId : tie.teamAId;
      final home = allTeams.firstWhere((t) => t.id == homeId);
      final away = allTeams.firstWhere((t) => t.id == awayId);
      final result = MatchEngine.simulate(
          home: home, away: away, matchday: 0, weather: WeatherEngine.roll());
      tie.legs.add(result);
      if (tie.isComplete &&
          tie.goalsFor(tie.teamAId) == tie.goalsFor(tie.teamBId)) {
        tie.penaltyWinnerId = CupEngine.decidePenaltyWinner(home, away);
      }
      _advanceKnockoutIfRoundComplete(cup);
      return result;
    }
    return null;
  }

  static void _advanceKnockoutIfRoundComplete(ContinentalCup cup) {
    final round = cup.knockoutRounds.last;
    if (round.any((t) => !t.isComplete)) return;
    if (round.length == 1) return;
    final winners = round.map((t) => t.winnerId!).toList();
    final nextRound = <CupTie>[];
    final isFinalNext = winners.length == 2;
    for (int i = 0; i < winners.length; i += 2) {
      nextRound.add(CupTie(
        round: round.first.round + 1,
        teamAId: winners[i],
        teamBId: winners[i + 1],
        singleLeg: isFinalNext,
      ));
    }
    cup.knockoutRounds.add(nextRound);
  }

  /// ラウンド数に応じたラウンド名(準決勝・決勝など)。
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
