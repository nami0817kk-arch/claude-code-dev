import 'dart:math';
import '../models/league.dart';

/// あるチームのシーズン最終順位に関する見込み。実際の試合結果には一切
/// 影響しない、参考情報としての予測値。
class TeamProjection {
  final String teamId;
  final double avgFinalPoints;
  final double avgFinalRank;
  final double titleProbability;
  final double continentalProbability;
  final double relegationProbability;

  const TeamProjection({
    required this.teamId,
    required this.avgFinalPoints,
    required this.avgFinalRank,
    required this.titleProbability,
    required this.continentalProbability,
    required this.relegationProbability,
  });
}

enum _Outcome { home, draw, away }

/// チームの総合力から残り試合の勝敗を簡易的に確率シミュレーションし、
/// シーズン最終順位の見込み(優勝/大陸カップ出場/降格の確率など)を算出する。
/// 実際の試合(MatchEngine)は選手個々のプレーを詳細に再現するが、ここでは
/// 数百回の試行を高速に回すため、チーム総合力ベースの簡易モデルを用いる。
class SeasonProjectionEngine {
  static const double _homeAdvantage = 4;
  static const double _drawProbability = 0.25;

  static List<TeamProjection> project(
    League league, {
    int iterations = 200,
    int continentalQualifyCount = 2,
    int relegationCount = 3,
    Random? random,
  }) {
    final rng = random ?? Random();
    final teams = league.teams;
    final ratingOf = {for (final t in teams) t.id: t.overallRating};
    final remaining = league.fixtures.where((f) => f.result == null).toList();
    final baseline = league.computeStandings();

    final rankSum = {for (final t in teams) t.id: 0};
    final rankCounts = {
      for (final t in teams) t.id: List<int>.filled(teams.length, 0)
    };
    final pointsSum = {for (final t in teams) t.id: 0};

    for (int iter = 0; iter < iterations; iter++) {
      final points = {for (final t in teams) t.id: baseline[t.id]!.points};
      final goalDiff = {for (final t in teams) t.id: baseline[t.id]!.goalDiff};

      for (final f in remaining) {
        final outcome = _sampleOutcome(
            ratingOf[f.homeTeamId]!, ratingOf[f.awayTeamId]!, rng);
        final margin = _sampleGoalMargin(outcome, rng);
        goalDiff[f.homeTeamId] = goalDiff[f.homeTeamId]! + margin;
        goalDiff[f.awayTeamId] = goalDiff[f.awayTeamId]! - margin;
        switch (outcome) {
          case _Outcome.home:
            points[f.homeTeamId] = points[f.homeTeamId]! + 3;
            break;
          case _Outcome.away:
            points[f.awayTeamId] = points[f.awayTeamId]! + 3;
            break;
          case _Outcome.draw:
            points[f.homeTeamId] = points[f.homeTeamId]! + 1;
            points[f.awayTeamId] = points[f.awayTeamId]! + 1;
            break;
        }
      }

      final order = teams.map((t) => t.id).toList()
        ..sort((a, b) {
          final p = points[b]!.compareTo(points[a]!);
          if (p != 0) return p;
          return goalDiff[b]!.compareTo(goalDiff[a]!);
        });

      for (int rank = 0; rank < order.length; rank++) {
        final id = order[rank];
        rankSum[id] = rankSum[id]! + rank + 1;
        rankCounts[id]![rank] += 1;
        pointsSum[id] = pointsSum[id]! + points[id]!;
      }
    }

    final result = teams.map((t) {
      final counts = rankCounts[t.id]!;
      final continentalCount =
          counts.take(continentalQualifyCount).fold(0, (s, c) => s + c);
      final relegationTally =
          counts.reversed.take(relegationCount).fold(0, (s, c) => s + c);
      return TeamProjection(
        teamId: t.id,
        avgFinalPoints: pointsSum[t.id]! / iterations,
        avgFinalRank: rankSum[t.id]! / iterations,
        titleProbability: counts[0] / iterations,
        continentalProbability: continentalCount / iterations,
        relegationProbability: relegationTally / iterations,
      );
    }).toList();
    result.sort((a, b) => a.avgFinalRank.compareTo(b.avgFinalRank));
    return result;
  }

  static _Outcome _sampleOutcome(int homeRating, int awayRating, Random rng) {
    final diff = (homeRating - awayRating + _homeAdvantage) / 100.0;
    final homeWinProb = (0.45 + diff).clamp(0.12, 0.72);
    final awayWinProbRaw =
        (1 - homeWinProb - _drawProbability).clamp(0.08, 0.72);
    final total = homeWinProb + _drawProbability + awayWinProbRaw;
    final normalizedHome = homeWinProb / total;
    final normalizedDraw = _drawProbability / total;

    final roll = rng.nextDouble();
    if (roll < normalizedHome) return _Outcome.home;
    if (roll < normalizedHome + normalizedDraw) return _Outcome.draw;
    return _Outcome.away;
  }

  /// 得失点差の簡易的なばらつき(順位のタイブレークを多様化させるため)。
  /// 符号はホーム視点(勝ちなら正、負けなら負)。
  static int _sampleGoalMargin(_Outcome outcome, Random rng) {
    if (outcome == _Outcome.draw) return 0;
    final magnitude = 1 + rng.nextInt(3);
    return outcome == _Outcome.home ? magnitude : -magnitude;
  }
}
