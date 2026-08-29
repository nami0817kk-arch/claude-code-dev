import '../models/league.dart';
import '../models/match_result.dart';
import '../models/player.dart';
import '../models/season_award.dart';

class AwardsEngine {
  /// 完了した全試合の得点イベントから選手ごとの得点数を集計する。
  static Map<String, int> _goalsByPlayer(League league) {
    final goals = <String, int>{};
    for (final f in league.fixtures) {
      final result = f.result;
      if (result == null) continue;
      for (final e in result.events) {
        if (e.type == MatchEventType.goal && e.scorerId != null) {
          goals[e.scorerId!] = (goals[e.scorerId!] ?? 0) + 1;
        }
      }
    }
    return goals;
  }

  /// 得点イベント自体が持つ選手名・チームIDを選手IDごとに記録する。
  /// シーズン中に移籍・退団した得点王でも、現在のロースター検索に頼らず
  /// 表彰記録の氏名を確定できるようにするため。
  static Map<String, ({String name, String teamId})> _scorerInfoByPlayer(
      League league) {
    final info = <String, ({String name, String teamId})>{};
    for (final f in league.fixtures) {
      final result = f.result;
      if (result == null) continue;
      for (final e in result.events) {
        if (e.type == MatchEventType.goal &&
            e.scorerId != null &&
            e.scorerName != null) {
          info[e.scorerId!] = (name: e.scorerName!, teamId: e.teamId);
        }
      }
    }
    return info;
  }

  /// シーズン終了時に得点王・年間MVPを確定する。得点イベントが1件もない場合はnullを返す項目もある。
  static SeasonAward computeAwards(League league, int season) {
    final goals = _goalsByPlayer(league);
    final scorerInfo = _scorerInfoByPlayer(league);

    String? topScorerId;
    int topScorerGoals = 0;
    for (final entry in goals.entries) {
      if (entry.value > topScorerGoals) {
        topScorerGoals = entry.value;
        topScorerId = entry.key;
      }
    }

    String? topScorerName;
    String? topScorerTeamName;
    String? topScorerTeamId;
    if (topScorerId != null) {
      final info = scorerInfo[topScorerId];
      if (info != null) {
        topScorerName = info.name;
        topScorerTeamId = info.teamId;
        for (final t in league.teams) {
          if (t.id == info.teamId) {
            topScorerTeamName = t.name;
            break;
          }
        }
      }
    }

    // 年間MVP: 総合力に得点数を加味したスコアが最も高い選手を選ぶ簡易的な
    // ヒューリスティック。t.startingXIは「現時点」のスタメン指定であり、
    // シーズン終了時点でたまたま入れ替えていた選手が除外されてしまう
    // (=シーズンを通じて活躍していた主力が、最終節前のローテーションだけで
    // 対象外になる)ため、対象は全所属選手とする。
    String? mvpId;
    String? mvpName;
    String? mvpTeamName;
    String? mvpTeamId;
    double bestScore = -1;
    for (final t in league.teams) {
      for (final p in t.players) {
        final score = p.overall.toDouble() + (goals[p.id] ?? 0) * 2;
        if (score > bestScore) {
          bestScore = score;
          mvpId = p.id;
          mvpName = p.name;
          mvpTeamName = t.name;
          mvpTeamId = t.id;
        }
      }
    }

    // ゴールデングラブ(無失点王): 実際に出場した(playerRatingsに記録がある)
    // GKのうち、最も多く無失点試合を守った選手を選ぶ。得点王・MVPと異なり、
    // 出場記録から選手を特定する必要があるため対象は現在のロースターに
    // 限られる(シーズン中に放出されたGKは対象外)。
    final cleanSheets = <String, int>{};
    for (final f in league.fixtures) {
      final r = f.result;
      if (r == null) continue;
      if (r.awayGoals == 0) {
        final gk = _startingGoalkeeper(league, f.homeTeamId, r);
        if (gk != null) cleanSheets[gk.id] = (cleanSheets[gk.id] ?? 0) + 1;
      }
      if (r.homeGoals == 0) {
        final gk = _startingGoalkeeper(league, f.awayTeamId, r);
        if (gk != null) cleanSheets[gk.id] = (cleanSheets[gk.id] ?? 0) + 1;
      }
    }
    String? goldenGloveId;
    String? goldenGloveName;
    String? goldenGloveTeamName;
    String? goldenGloveTeamId;
    int goldenGloveCleanSheets = 0;
    for (final entry in cleanSheets.entries) {
      if (entry.value > goldenGloveCleanSheets) {
        goldenGloveCleanSheets = entry.value;
        for (final t in league.teams) {
          for (final p in t.players) {
            if (p.id == entry.key) {
              goldenGloveId = p.id;
              goldenGloveName = p.name;
              goldenGloveTeamName = t.name;
              goldenGloveTeamId = t.id;
            }
          }
        }
      }
    }

    return SeasonAward(
      season: season,
      topScorerId: topScorerId,
      topScorerName: topScorerName,
      topScorerTeamName: topScorerTeamName,
      topScorerTeamId: topScorerTeamId,
      topScorerGoals: topScorerGoals,
      mvpId: mvpId,
      mvpName: mvpName,
      mvpTeamName: mvpTeamName,
      mvpTeamId: mvpTeamId,
      goldenGloveId: goldenGloveId,
      goldenGloveName: goldenGloveName,
      goldenGloveTeamName: goldenGloveTeamName,
      goldenGloveTeamId: goldenGloveTeamId,
      goldenGloveCleanSheets: goldenGloveCleanSheets,
    );
  }

  /// 指定チームがその試合で実際に出場させていたGKを1人特定する
  /// (playerRatingsに記録があるGKポジションの選手)。
  static Player? _startingGoalkeeper(
      League league, String teamId, MatchResult r) {
    for (final t in league.teams) {
      if (t.id != teamId) continue;
      for (final p in t.players) {
        if (p.position == Position.gk && r.playerRatings.containsKey(p.id)) {
          return p;
        }
      }
    }
    return null;
  }

  /// 指定した節の範囲([fromMatchday, toMatchday]、両端含む)で最も良い成績
  /// (勝点、同点なら得失点差・総得点)を残したクラブ名を返す
  /// (=月間最優秀監督賞に相当)。対象試合が1件もなければnull。
  static String? computeManagerOfPeriod(
    League league, {
    required int fromMatchday,
    required int toMatchday,
  }) {
    final points = <String, int>{};
    final goalDiff = <String, int>{};
    final goalsFor = <String, int>{};
    for (final f in league.fixtures) {
      if (f.matchday < fromMatchday || f.matchday > toMatchday) continue;
      final r = f.result;
      if (r == null) continue;
      points.putIfAbsent(f.homeTeamId, () => 0);
      points.putIfAbsent(f.awayTeamId, () => 0);
      goalDiff[f.homeTeamId] =
          (goalDiff[f.homeTeamId] ?? 0) + (r.homeGoals - r.awayGoals);
      goalDiff[f.awayTeamId] =
          (goalDiff[f.awayTeamId] ?? 0) + (r.awayGoals - r.homeGoals);
      goalsFor[f.homeTeamId] = (goalsFor[f.homeTeamId] ?? 0) + r.homeGoals;
      goalsFor[f.awayTeamId] = (goalsFor[f.awayTeamId] ?? 0) + r.awayGoals;
      if (r.homeGoals > r.awayGoals) {
        points[f.homeTeamId] = points[f.homeTeamId]! + 3;
      } else if (r.homeGoals < r.awayGoals) {
        points[f.awayTeamId] = points[f.awayTeamId]! + 3;
      } else {
        points[f.homeTeamId] = points[f.homeTeamId]! + 1;
        points[f.awayTeamId] = points[f.awayTeamId]! + 1;
      }
    }
    if (points.isEmpty) return null;
    String? bestId;
    for (final id in points.keys) {
      if (bestId == null) {
        bestId = id;
        continue;
      }
      final cmp = points[id]!.compareTo(points[bestId]!);
      if (cmp > 0 ||
          (cmp == 0 && goalDiff[id]! > goalDiff[bestId]!) ||
          (cmp == 0 &&
              goalDiff[id] == goalDiff[bestId] &&
              goalsFor[id]! > goalsFor[bestId]!)) {
        bestId = id;
      }
    }
    return league.teams.firstWhere((t) => t.id == bestId).name;
  }

  /// シーズン終了時、現在の総合力から見た「期待順位」を最も上回った
  /// (=実際の最終順位が最も良かった)クラブ名を返す(=年間最優秀監督賞に相当)。
  static String computeManagerOfSeason(League league) {
    final byOverall = [...league.teams]
      ..sort((a, b) => b.overallRating.compareTo(a.overallRating));
    final expectedRank = {
      for (int i = 0; i < byOverall.length; i++) byOverall[i].id: i + 1,
    };
    final standings = league.sortedStandings;
    var bestTeamId = standings.first.teamId;
    var bestDiff = -1 << 30;
    for (int i = 0; i < standings.length; i++) {
      final actualRank = i + 1;
      final teamId = standings[i].teamId;
      final diff = (expectedRank[teamId] ?? actualRank) - actualRank;
      if (diff > bestDiff) {
        bestDiff = diff;
        bestTeamId = teamId;
      }
    }
    return league.teams.firstWhere((t) => t.id == bestTeamId).name;
  }
}
