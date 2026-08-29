import 'dart:math';
import '../models/match_result.dart';
import '../models/team.dart';

/// 画面に表示されないバックグラウンドの試合(裏側のディビジョン等)向けの
/// 軽量なスコア推定シミュレーション。MatchEngine.simulateは分単位で選手ごとの
/// プレーを再現するため負荷が高く、大量の試合をまとめて消化する用途には
/// 不向き(節を進めるたびに体感速度が低下する原因になっていた)。
/// ここではチーム総合力からポアソン分布で得点数を推定するだけに留め、
/// 個々の選手のイベント・怪我・成長は扱わない。
class BackgroundMatchEngine {
  static final Random _rng = Random();

  static MatchResult simulate({
    required Team home,
    required Team away,
    required int matchday,
    Random? random,
  }) {
    final rng = random ?? _rng;
    final ratingDiff = (home.overallRating - away.overallRating).toDouble();
    final homeExpected = (1.35 + ratingDiff / 90 + 0.25).clamp(0.3, 3.6);
    final awayExpected = (1.15 - ratingDiff / 90).clamp(0.2, 3.3);
    return MatchResult(
      matchday: matchday,
      homeTeamId: home.id,
      awayTeamId: away.id,
      homeGoals: _poisson(homeExpected, rng),
      awayGoals: _poisson(awayExpected, rng),
      events: const [],
    );
  }

  /// Knuthのアルゴリズムによるポアソン分布サンプリング。
  static int _poisson(double lambda, Random rng) {
    final l = exp(-lambda);
    var k = 0;
    var p = 1.0;
    do {
      k++;
      p *= rng.nextDouble();
    } while (p > l);
    return k - 1;
  }
}
