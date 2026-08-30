import '../models/attributes.dart';
import '../models/player.dart';
import '../models/team.dart';

/// 戦術スタイルの効果を計算するエンジン。
///
/// - 適性: スタイルごとの関連能力値をスカッド(先発のフィールド選手)が
///   どれだけ備えているか(0.0〜1.0)。適性が高いほどスタイルの
///   攻守補正([powerFactor])が大きくなり、低いスタイルを選ぶと
///   逆にマイナス補正になる。柔軟スタイルは常に中立(1.0)。
/// - 相性: 5つの専門スタイルは一方向の循環で有利不利を持ち
///   ([beats])、有利な側は攻撃力にボーナス、不利な側はペナルティを
///   受ける([matchupAttackFactor])。柔軟はどのスタイルとも中立。
class StyleEngine {
  /// スタイルごとの適性判定に使う関連能力値。
  static const Map<TacticalStyle, List<String>> keyAttributes = {
    TacticalStyle.possession: [
      AttributeKeys.passing,
      AttributeKeys.firstTouch,
      AttributeKeys.technique,
      AttributeKeys.vision,
    ],
    TacticalStyle.gegenpress: [
      AttributeKeys.workRate,
      AttributeKeys.stamina,
      AttributeKeys.aggression,
      AttributeKeys.teamwork,
    ],
    TacticalStyle.counter: [
      AttributeKeys.pace,
      AttributeKeys.acceleration,
      AttributeKeys.offTheBall,
      AttributeKeys.anticipation,
    ],
    TacticalStyle.longBall: [
      AttributeKeys.heading,
      AttributeKeys.jumpingReach,
      AttributeKeys.strength,
      AttributeKeys.bravery,
    ],
    TacticalStyle.wingPlay: [
      AttributeKeys.crossing,
      AttributeKeys.dribbling,
      AttributeKeys.pace,
      AttributeKeys.offTheBall,
    ],
  };

  /// 相性の循環(キーのスタイルは値のスタイルに対して有利)。
  /// ゲーゲンプレスは後方でつなぐポゼッションをハメて奪い、
  /// ポゼッションはボールを渡さずカウンターを機能させず、
  /// カウンターは攻め上がるウイングプレーのサイド裏を突き、
  /// ウイングプレーは中央に固めるロングボール勢の手薄なサイドを崩し、
  /// ロングボールは頭上を越す一発でゲーゲンプレスを無力化する。
  static const Map<TacticalStyle, TacticalStyle> beats = {
    TacticalStyle.gegenpress: TacticalStyle.possession,
    TacticalStyle.possession: TacticalStyle.counter,
    TacticalStyle.counter: TacticalStyle.wingPlay,
    TacticalStyle.wingPlay: TacticalStyle.longBall,
    TacticalStyle.longBall: TacticalStyle.gegenpress,
  };

  /// 相性で有利な側の攻撃力ボーナス/不利な側のペナルティ。
  static const double matchupBonus = 1.06;
  static const double matchupPenalty = 0.95;

  /// [team]の現在の先発(未設定なら全選手)から、[style]への適性を
  /// 0.0〜1.0で返す。GKは除外して評価する。柔軟スタイルは概念上
  /// 適性を持たないため中立の0.5を返す。
  static double suitability(
    Team team,
    TacticalStyle style, {
    List<Player>? lineup,
  }) {
    if (style == TacticalStyle.flexible) return 0.5;
    final keys = keyAttributes[style]!;
    var pool = lineup ??
        [
          for (final id in team.startingXI)
            for (final p in team.players)
              if (p.id == id) p,
        ];
    if (pool.isEmpty) pool = team.players;
    final outfield =
        pool.where((p) => p.position.group != PositionGroup.gk).toList();
    if (outfield.isEmpty) return 0.5;
    var sum = 0.0;
    for (final p in outfield) {
      var playerSum = 0;
      for (final k in keys) {
        playerSum += p.attributeValue(k);
      }
      sum += playerSum / keys.length;
    }
    final avg = sum / outfield.length;
    // 平均能力値30で適性0、80で適性1.0になる線形マッピング。
    return ((avg - 30) / 50).clamp(0.0, 1.0);
  }

  /// スタイル適性に応じた攻守共通の補正(0.92〜1.08)。適性0.5(平均的な
  /// スカッド)でちょうど中立になり、向いていないスタイルを選ぶと
  /// マイナスに働く。柔軟は常に1.0。
  static double powerFactor(
    Team team, {
    List<Player>? lineup,
  }) {
    if (team.tacticalStyle == TacticalStyle.flexible) return 1.0;
    final fit = suitability(team, team.tacticalStyle, lineup: lineup);
    return 0.92 + 0.16 * fit;
  }

  /// 自分のスタイル[self]が相手のスタイル[opp]に対して持つ攻撃力補正。
  static double matchupAttackFactor(TacticalStyle self, TacticalStyle opp) {
    if (beats[self] == opp) return matchupBonus;
    if (beats[opp] == self) return matchupPenalty;
    return 1.0;
  }
}
