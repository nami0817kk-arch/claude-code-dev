import 'dart:math';

import '../models/attributes.dart';
import '../models/player.dart';
import 'training_engine.dart';

/// ユース練習試合での選手1人の出来。
class YouthMatchPerformance {
  final Player player;
  final int goals;
  final double rating;

  const YouthMatchPerformance({
    required this.player,
    required this.goals,
    required this.rating,
  });
}

/// ユース練習試合1試合の結果。
class YouthMatchReport {
  final int teamGoals;
  final int opponentGoals;
  final int opponentRating;
  final List<YouthMatchPerformance> performances;

  const YouthMatchReport({
    required this.teamGoals,
    required this.opponentGoals,
    required this.opponentRating,
    required this.performances,
  });

  bool get isWin => teamGoals > opponentGoals;
  bool get isDraw => teamGoals == opponentGoals;

  String get scoreLabel => '$teamGoals-$opponentGoals';
}

/// ユース昇格候補たちが毎週こなす練習試合(近隣クラブのユースとの対戦)を
/// シミュレートするエンジン。施設内の座学的な育成
/// ([TrainingEngine.applyYouthAcademyGrowth])に対して、こちらは
/// 「実戦の場」を提供する: 全員が出場数・実戦感覚を積み、評点が付き、
/// 活躍(高評点)した選手はその勢いで能力が伸びる。昇格のタイミングを
/// 見極める判断材料にもなる。
class YouthMatchEngine {
  static final Random _rng = Random();

  /// この評点以上なら「活躍」とみなし、追加の成長ボーナスを与える。
  static const double standoutRatingThreshold = 7.5;

  /// 活躍時に伸びる能力値の個数。
  static const int standoutGrowthCount = 2;

  /// 候補が1人もいなければnullを返す。それ以外は試合をシミュレートし、
  /// 各候補の出場数・得点・直近評点を更新して結果を返す。
  static YouthMatchReport? playWeekly(List<Player> prospects) {
    if (prospects.isEmpty) return null;

    final avg =
        prospects.fold<int>(0, (s, p) => s + p.overall) / prospects.length;
    // 相手は自分たちと同水準のユースが中心だが、毎週ばらつく。
    final opponentRating = (avg + _rng.nextInt(11) - 5).round().clamp(20, 90);
    final diff = avg - opponentRating;

    int rollGoals(double expected) {
      var goals = 0;
      // 期待値を確率に分解した簡易ポアソン(最大6点)。
      for (var i = 0; i < 6; i++) {
        if (_rng.nextDouble() < (expected / 6).clamp(0.0, 0.95)) goals++;
      }
      return goals;
    }

    final teamGoals = rollGoals(1.4 + diff / 12);
    final opponentGoals = rollGoals(1.4 - diff / 12);

    // 得点者は攻撃寄りの候補ほど選ばれやすい。
    final scorerCounts = <String, int>{};
    final attackers =
        prospects.where((p) => p.position.group != PositionGroup.gk).toList();
    for (var g = 0; g < teamGoals && attackers.isNotEmpty; g++) {
      final total = attackers.fold<int>(0, (s, p) => s + max(1, p.attack));
      var r = _rng.nextInt(total);
      for (final p in attackers) {
        r -= max(1, p.attack);
        if (r < 0) {
          scorerCounts[p.id] = (scorerCounts[p.id] ?? 0) + 1;
          break;
        }
      }
    }

    final performances = <YouthMatchPerformance>[];
    for (final p in prospects) {
      final goals = scorerCounts[p.id] ?? 0;
      var rating = 6.0 + (p.overall - opponentRating) / 20 + goals * 0.8;
      rating += _rng.nextDouble() * 2.0 - 1.0;
      if (teamGoals > opponentGoals) rating += 0.3;
      if (teamGoals < opponentGoals) rating -= 0.3;
      rating = double.parse(rating.clamp(4.0, 10.0).toStringAsFixed(1));

      p.youthMatchApps++;
      p.youthMatchGoals += goals;
      p.lastYouthMatchRating = rating;
      p.matchSharpness = (p.matchSharpness + 6).clamp(0, 100);
      TrainingEngine.growFromMatchExperience(p);
      if (rating >= standoutRatingThreshold) {
        _applyStandoutGrowth(p);
      }

      performances.add(
        YouthMatchPerformance(player: p, goals: goals, rating: rating),
      );
    }

    performances.sort((a, b) => b.rating.compareTo(a.rating));
    return YouthMatchReport(
      teamGoals: teamGoals,
      opponentGoals: opponentGoals,
      opponentRating: opponentRating,
      performances: performances,
    );
  }

  /// 活躍した候補はその勢いで、ポジションに合った能力値が数個伸びる
  /// (ポテンシャル上限まで)。
  static void _applyStandoutGrowth(Player p) {
    final pool = switch (p.position.group) {
      PositionGroup.gk => AttributeKeys.goalkeeping,
      PositionGroup.def => const [
          AttributeKeys.tackling,
          AttributeKeys.marking,
          AttributeKeys.positioning,
          AttributeKeys.anticipation,
        ],
      _ => const [
          AttributeKeys.finishing,
          AttributeKeys.dribbling,
          AttributeKeys.offTheBall,
          AttributeKeys.passing,
        ],
    };
    final shuffled = [...pool]..shuffle(_rng);
    for (var i = 0; i < standoutGrowthCount && i < shuffled.length; i++) {
      final key = shuffled[i];
      final current = p.attributeValue(key);
      if (current >= p.potential) continue;
      p.setAttributeValue(key, (current + 1).clamp(1, p.potential));
    }
  }
}
