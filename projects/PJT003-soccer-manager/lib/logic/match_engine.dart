import 'dart:math';

import '../models/attributes.dart';
import '../models/formation.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/match_result.dart';
import '../models/weather.dart';
import 'lineup_utils.dart';
import 'training_engine.dart';

/// この枚数の警告が貯まると次節出場停止になる(退場は即1試合出場停止)。
const int yellowCardSuspensionThreshold = 5;

/// 分単位区間([MatchEngine.simulateMinutes])1回分のスコア・イベント。
class HalfResult {
  final int homeGoals;
  final int awayGoals;
  final List<MatchEvent> events;
  final int homeShots;
  final int awayShots;
  final int homeShotsOnTarget;
  final int awayShotsOnTarget;

  /// この半で評価された各チャンスのhomeShare(ホームがそのチャンスを
  /// 迎える確率)の合計。ポゼッション率の算出に使う。
  final double possessionShareSum;
  final int chanceCount;

  const HalfResult({
    required this.homeGoals,
    required this.awayGoals,
    required this.events,
    this.homeShots = 0,
    this.awayShots = 0,
    this.homeShotsOnTarget = 0,
    this.awayShotsOnTarget = 0,
    this.possessionShareSum = 0,
    this.chanceCount = 0,
  });
}

/// 攻撃側の決定機での選択(シュート/パス/ロングシュート)と、守備側の
/// 決定機での選択(積極的にタックル/カバーリングに専念)をまとめた列挙。
/// [PendingChanceDecision.context]に応じてどちらの値を渡すべきかが決まる
/// (不適切な値を渡した場合は既定の安全な選択にフォールバックする)。
enum ChanceDecision { shoot, pass, longShot, aggressiveTackle, coverSpace }

/// [PendingChanceDecision]が攻撃側の決定機か守備側の決定機かを表す。
enum ChanceContext { attack, defense }

/// オープンプレーの決定機で、ユーザーチームに判断を求めるための情報。
/// [context]が[ChanceContext.attack]の場合はシュート/パス/ロングシュートを
/// (各選択肢の成功率を[shootChance]/[passChance]/[longShotChance]として
/// 事前に提示する)、[ChanceContext.defense]の場合は積極的にタックルに
/// 行くかカバーリングに専念するかを([aggressiveChanceAgainst]/
/// [safeChanceAgainst]として相手の成功率を提示しつつ)選べる。
class PendingChanceDecision {
  final int minute;
  final ChanceContext context;

  // attackコンテキストのみ有効。
  final Player? shooter;
  final Player? passTarget;
  final double? shootChance;
  final double? passChance;
  final double? longShotChance;

  // defenseコンテキストのみ有効。相手チーム視点の得点成功率を示す。
  final Player? attacker;
  final double? aggressiveChanceAgainst;
  final double? safeChanceAgainst;

  const PendingChanceDecision.attack({
    required this.minute,
    required Player this.shooter,
    this.passTarget,
    required double this.shootChance,
    this.passChance,
    required double this.longShotChance,
  })  : context = ChanceContext.attack,
        attacker = null,
        aggressiveChanceAgainst = null,
        safeChanceAgainst = null;

  const PendingChanceDecision.defense({
    required this.minute,
    required Player this.attacker,
    required double this.aggressiveChanceAgainst,
    required double this.safeChanceAgainst,
  })  : context = ChanceContext.defense,
        shooter = null,
        passTarget = null,
        shootChance = null,
        passChance = null,
        longShotChance = null;
}

/// [MatchEngine.beginInteractiveHalf]/[MatchEngine.resolvePendingChance]が
/// 進行状況を保持するための可変状態。[pending]がセットされている間は
/// 進行が止まっており、[MatchEngine.resolvePendingChance]で解決されるまで
/// 再開しない。
class InteractiveHalfState {
  final Team home;
  final Team away;
  final String interactiveTeamId;
  final List<Player> homeLineup;
  final List<Player> awayLineup;
  final double homeAttackBase;
  final double awayAttackBase;
  final double homeDefenseBase;
  final double awayDefenseBase;
  final List<int> chanceMinutes;
  final List<MatchEvent> events;

  // 決定機の中でカード(警告・退場)が出た場合に更新されるため、
  // 事前生成分と合わせて可変にしている。
  int? homeRedMinute;
  int? awayRedMinute;

  int chanceIndex = 0;
  int homeGoals = 0;
  int awayGoals = 0;
  double homeMomentum = 0;
  double awayMomentum = 0;
  int homeShots = 0;
  int awayShots = 0;
  int homeShotsOnTarget = 0;
  int awayShotsOnTarget = 0;
  double possessionShareSum = 0;

  PendingChanceDecision? pending;
  // pending解決に必要な文脈(次のresolvePendingChance呼び出しでのみ使う)。
  bool? pendingIsHomeChance;

  /// 直近の[MatchEngine.resolvePendingChance]呼び出しで、この決定機の結果
  /// として実際に発生したイベント(得点・惜しいチャンス・カード)。何も
  /// 起きなかった(攻撃が不発に終わった)場合はnull。UI側の即時フィード
  /// バック表示に使う。
  MatchEvent? lastDecisionEvent;

  InteractiveHalfState({
    required this.home,
    required this.away,
    required this.interactiveTeamId,
    required this.homeLineup,
    required this.awayLineup,
    required this.homeAttackBase,
    required this.awayAttackBase,
    required this.homeDefenseBase,
    required this.awayDefenseBase,
    required this.homeRedMinute,
    required this.awayRedMinute,
    required this.chanceMinutes,
    required this.events,
  });

  /// このハーフの進行が(判断待ちなく)完了したかどうか。
  bool get isFinished => pending == null && chanceIndex >= chanceMinutes.length;

  HalfResult toHalfResult() {
    final sorted = [...events]..sort((a, b) => a.minute.compareTo(b.minute));
    return HalfResult(
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      events: sorted,
      homeShots: homeShots,
      awayShots: awayShots,
      homeShotsOnTarget: homeShotsOnTarget,
      awayShotsOnTarget: awayShotsOnTarget,
      possessionShareSum: possessionShareSum,
      chanceCount: chanceMinutes.length,
    );
  }
}

class MatchEngine {
  static final Random _rng = Random();

  static double _condition(Player p) =>
      (1 - p.fatigue / 250) *
      (0.85 + p.morale / 500) *
      (0.8 + p.matchSharpness / 500) *
      p.matchFormMultiplier;

  static double _avgOverall(List<Player> lineup) => lineup.isEmpty
      ? 50
      : lineup.fold<int>(0, (s, p) => s + p.overall) / lineup.length;

  /// 選手特性による、この試合限りのパフォーマンス倍率を算出する。
  /// [selfAvg]は自チーム、[oppAvg]は相手チームの先発平均総合力。
  /// [isHome]はこの選手のチームがホームかどうか、[weather]はこの試合の天候。
  static double _traitFormMultiplier(
    Player p, {
    required double selfAvg,
    required double oppAvg,
    required bool isHome,
    required Weather weather,
  }) {
    final trait = p.trait;
    if (trait == null) return 1.0;
    final diff = selfAvg - oppAvg;
    double attr(String key) => p.attributeValue(key).toDouble();
    switch (trait) {
      // 対戦相手との相対的な実力差
      case PlayerTrait.giantKiller:
        return -diff >= 5 ? 1.08 : 1.0;
      case PlayerTrait.frontRunner:
        return diff >= 5 ? 1.08 : 1.0;
      case PlayerTrait.underdogSpirit:
        return -diff >= 10 ? 1.13 : 1.0;
      case PlayerTrait.dominantForce:
        return diff >= 10 ? 1.13 : 1.0;
      // 対戦相手の絶対的な実力
      case PlayerTrait.bigGameHunter:
        return oppAvg >= 75 ? 1.10 : 1.0;
      case PlayerTrait.bullyBall:
        return oppAvg <= 55 ? 1.06 : 1.0;
      // ホーム/アウェイ
      case PlayerTrait.homeBoy:
        return isHome ? 1.05 : 1.0;
      case PlayerTrait.roadWarrior:
        return !isHome ? 1.05 : 1.0;
      // 天候
      case PlayerTrait.rainMaster:
        return weather == Weather.rain ? 1.08 : 1.0;
      case PlayerTrait.windMaster:
        return weather == Weather.wind ? 1.09 : 1.0;
      case PlayerTrait.heatwaveMaster:
        return weather == Weather.heatwave ? 1.10 : 1.0;
      case PlayerTrait.snowMaster:
        return weather == Weather.snow ? 1.14 : 1.0;
      case PlayerTrait.fairWeatherPlayer:
        return weather == Weather.clear ? 1.05 : 1.0;
      // 疲労・コンディション
      case PlayerTrait.ironLungs:
        return p.fatigue >= 70 ? 1.07 : 1.0;
      case PlayerTrait.freshLegs:
        return p.fatigue <= 20 ? 1.08 : 1.0;
      case PlayerTrait.confidentMind:
        return p.morale >= 80 ? 1.06 : 1.0;
      case PlayerTrait.clutchNerves:
        return p.morale <= 30 ? 1.10 : 1.0;
      case PlayerTrait.contentPlayer:
        return p.happiness >= 80 ? 1.05 : 1.0;
      case PlayerTrait.sharpShooter:
        return p.matchSharpness >= 90 ? 1.09 : 1.0;
      case PlayerTrait.rustyButReady:
        return p.matchSharpness <= 40 ? 1.08 : 1.0;
      // 年齢
      case PlayerTrait.wonderkid:
        return p.age <= 21 ? 1.08 : 1.0;
      case PlayerTrait.oldHead:
        return p.age >= 32 ? 1.08 : 1.0;
      case PlayerTrait.primeTime:
        return p.age >= 26 && p.age <= 29 ? 1.05 : 1.0;
      // メンタル属性依存
      case PlayerTrait.warriorSpirit:
        return attr(AttributeKeys.determination) >= 80 ? 1.09 : 1.0;
      case PlayerTrait.calmHead:
        return attr(AttributeKeys.composure) >= 80 ? 1.09 : 1.0;
      case PlayerTrait.leaderOnPitch:
        return attr(AttributeKeys.leadership) >= 80 ? 1.09 : 1.0;
      // 波・安定性
      case PlayerTrait.streaky:
        return 0.8 + _rng.nextDouble() * 0.4;
      case PlayerTrait.volatileTalent:
        return 0.7 + _rng.nextDouble() * 0.6;
      case PlayerTrait.metronome:
        return 0.95 + _rng.nextDouble() * 0.1;
      // 技術・フィジカル属性依存
      case PlayerTrait.visionary:
        return attr(AttributeKeys.vision) >= 80 ? 1.07 : 1.0;
      case PlayerTrait.paceMerchant:
        return attr(AttributeKeys.pace) >= 80 ? 1.07 : 1.0;
      case PlayerTrait.powerhouse:
        return attr(AttributeKeys.strength) >= 80 ? 1.07 : 1.0;
      case PlayerTrait.enginesRunning:
        return attr(AttributeKeys.stamina) >= 80 ? 1.07 : 1.0;
      case PlayerTrait.silkyDribbler:
        return attr(AttributeKeys.dribbling) >= 80 ? 1.07 : 1.0;
      case PlayerTrait.playmakerTrait:
        return attr(AttributeKeys.passing) >= 80 ? 1.07 : 1.0;
      case PlayerTrait.ballWinner:
        return attr(AttributeKeys.tackling) >= 80 ? 1.07 : 1.0;
      case PlayerTrait.shadowMarker:
        return attr(AttributeKeys.marking) >= 80 ? 1.07 : 1.0;
      case PlayerTrait.clinicalFinisher:
        return attr(AttributeKeys.finishing) >= 80 ? 1.07 : 1.0;
      case PlayerTrait.distanceShooter:
        return attr(AttributeKeys.longShots) >= 80 ? 1.07 : 1.0;
      case PlayerTrait.aerialThreat:
        return attr(AttributeKeys.jumpingReach) >= 80 ? 1.07 : 1.0;
      case PlayerTrait.showman:
        return attr(AttributeKeys.flair) >= 80 ? 1.07 : 1.0;
      case PlayerTrait.sureTouch:
        return attr(AttributeKeys.firstTouch) >= 80 ? 1.06 : 1.0;
      case PlayerTrait.crossSpecialist:
        return attr(AttributeKeys.crossing) >= 80 ? 1.06 : 1.0;
      case PlayerTrait.setPieceMaestro:
        return attr(AttributeKeys.freeKick) >= 80 ? 1.06 : 1.0;
      case PlayerTrait.clockwork:
        return attr(AttributeKeys.anticipation) >= 80 ? 1.06 : 1.0;
      case PlayerTrait.decisiveMind:
        return attr(AttributeKeys.decisions) >= 80 ? 1.06 : 1.0;
      case PlayerTrait.teamPlayer:
        return attr(AttributeKeys.teamwork) >= 80 ? 1.06 : 1.0;
      case PlayerTrait.tirelessRunner:
        return attr(AttributeKeys.workRate) >= 80 ? 1.06 : 1.0;
      case PlayerTrait.explosiveStart:
        return attr(AttributeKeys.acceleration) >= 80 ? 1.06 : 1.0;
      case PlayerTrait.fearlessDefender:
        return attr(AttributeKeys.bravery) >= 80 ? 1.06 : 1.0;
    }
  }

  /// 試合開始時(前半開始時)に、両チームの全選手の「今試合分の算出済み」
  /// フラグをリセットしたうえで、先発選手の特性由来のパフォーマンス倍率を
  /// 算出して[Player.matchFormMultiplier]に格納する。
  static void _rollMatchForm(Team home, Team away, Weather weather) {
    for (final p in home.players) {
      p.matchFormRolledThisMatch = false;
    }
    for (final p in away.players) {
      p.matchFormRolledThisMatch = false;
    }
    _rollMatchFormForCurrentLineup(home, away, weather);
  }

  /// その時点のスタメン([lineupOf])のうち、まだ今試合分の倍率を
  /// 算出していない選手だけに算出する。前半に出場しなかった選手が
  /// 後半途中出場で初めて[lineupOf]に現れた場合(交代・負傷者の穴埋め等)
  /// にも、この試合用の値を正しく算出できるようにするための下位関数。
  /// 既に算出済みの選手は前後半を通して同じ値を使い続ける(再算出しない)。
  static void _rollMatchFormForCurrentLineup(
    Team home,
    Team away,
    Weather weather,
  ) {
    final homeLineup = lineupOf(home);
    final awayLineup = lineupOf(away);
    final homeAvg = _avgOverall(homeLineup);
    final awayAvg = _avgOverall(awayLineup);
    for (final p in homeLineup) {
      if (p.matchFormRolledThisMatch) continue;
      p.matchFormMultiplier = _traitFormMultiplier(
        p,
        selfAvg: homeAvg,
        oppAvg: awayAvg,
        isHome: true,
        weather: weather,
      );
      p.matchFormRolledThisMatch = true;
    }
    for (final p in awayLineup) {
      if (p.matchFormRolledThisMatch) continue;
      p.matchFormMultiplier = _traitFormMultiplier(
        p,
        selfAvg: awayAvg,
        oppAvg: homeAvg,
        isHome: false,
        weather: weather,
      );
      p.matchFormRolledThisMatch = true;
    }
  }

  /// 先発11人を解決する。未設定・不整合な場合は負傷者を除いた総合力上位11人で代用する。
  static List<Player> lineupOf(Team t) {
    if (t.startingXI.isNotEmpty) {
      final byId = {for (final p in t.players) p.id: p};
      final lineup = t.startingXI
          .map((id) => byId[id])
          .whereType<Player>()
          .where(
            (p) =>
                !p.isInjured &&
                !p.isOnInternationalDuty &&
                !p.isLoanedOut &&
                !p.isSuspended,
          )
          .toList();
      if (lineup.length >= 7) return lineup;
    }
    final available = t.players
        .where(
          (p) =>
              !p.isInjured &&
              !p.isOnInternationalDuty &&
              !p.isLoanedOut &&
              !p.isSuspended,
        )
        .toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    return available.take(11).toList();
  }

  /// スカウティングレポート・マンマーク指令の対象となる「キープレイヤー」
  /// (出場想定メンバーの中で最も総合力が高い選手)を1人特定する。
  static Player? identifyKeyPlayer(List<Player> lineup) {
    Player? keyPlayer;
    for (final p in lineup) {
      if (keyPlayer == null || p.overall > keyPlayer.overall) keyPlayer = p;
    }
    return keyPlayer;
  }

  /// デューティ(攻撃的/バランス/守備的)による攻撃貢献度の補正。
  static double dutyAttackMultiplier(PlayerDuty duty) => switch (duty) {
        PlayerDuty.attack => 1.20,
        PlayerDuty.support => 1.0,
        PlayerDuty.defend => 0.80,
      };

  /// デューティによる守備貢献度の補正(攻撃的デューティは守備が手薄になる)。
  static double dutyDefenseMultiplier(PlayerDuty duty) => switch (duty) {
        PlayerDuty.defend => 1.20,
        PlayerDuty.support => 1.0,
        PlayerDuty.attack => 0.80,
      };

  /// ロールに応じた貢献度補正。ロールが重視する能力値の平均が選手本来の
  /// 攻撃力/守備力より高ければボーナス、低ければペナルティになる
  /// (=適性の合わないロールを割り当てると損をする)。
  static double roleMultiplier(Player p, {required bool forAttack}) {
    final keyAttributes = p.role.keyAttributes;
    if (keyAttributes.isEmpty) return 1.0;
    final base = forAttack ? p.attack : p.defense;
    final roleRating =
        keyAttributes.fold<int>(0, (s, k) => s + p.attributeValue(k)) /
            keyAttributes.length;
    return (1 + (roleRating - base) / 130).clamp(0.8, 1.3);
  }

  /// 本職以外のポジションで起用された際の貢献度ペナルティ。副ポジションと
  /// して登録済みなら軽微(慣れが増すほど解消)、それ以外(同グループの
  /// 代役)はより大きなペナルティになる。
  static double positionFitMultiplier(Player p, Position assignedSlot) {
    if (assignedSlot == p.position) return 1.0;
    final familiarity = p.familiarityFor(assignedSlot) / 100;
    if (p.secondaryPositions.contains(assignedSlot)) {
      return 0.90 + 0.10 * familiarity;
    }
    return 0.75 + 0.15 * familiarity;
  }

  /// スカッド崩壊などで該当グループの選手が1人もいない場合の攻守力。
  /// フォーメーション上想定されない稀なケースの安全策であり、通常の
  /// チーム(40〜90程度)と互角に渡り合えてしまわないよう、明確に低い
  /// 値にする(先発全体も空なら、なお一段と低い値にする)。
  static double _emptyGroupPower(List<Player> lineup) =>
      lineup.isEmpty ? 8 : 15;

  static double _attackPower(
    Team t,
    List<Player> lineup, {
    String? suppressedId,
  }) {
    final relevant = lineup
        .where(
          (p) =>
              p.position.group == PositionGroup.att ||
              p.position.group == PositionGroup.mid,
        )
        .toList();
    if (relevant.isEmpty) return _emptyGroupPower(lineup);
    final slotById = LineupUtils.assignedSlotByPlayerId(t);
    final total = relevant.fold<double>(
      0,
      (s, p) =>
          s +
          p.attack *
              _condition(p) *
              dutyAttackMultiplier(p.duty) *
              roleMultiplier(p, forAttack: true) *
              positionFitMultiplier(p, slotById[p.id] ?? p.position) *
              (p.id == suppressedId ? 0.8 : 1.0),
    );
    final avgStamina = _avgAttribute(lineup, AttributeKeys.stamina);
    final result = (total / relevant.length) *
        t.formation.attackBias *
        lineHeightAttackFactor(t.lineHeight) *
        widthAttackFactor(t.width) *
        tempoAttackFactor(t.tempo, avgStamina);
    return t.timeWastingMode ? result * 0.92 : result;
  }

  static double _defensePower(Team t, List<Player> lineup) {
    final relevant = lineup
        .where(
          (p) =>
              p.position.group == PositionGroup.def ||
              p.position.group == PositionGroup.gk,
        )
        .toList();
    if (relevant.isEmpty) return _emptyGroupPower(lineup);
    final slotById = LineupUtils.assignedSlotByPlayerId(t);
    final total = relevant.fold<double>(
      0,
      (s, p) =>
          s +
          p.defense *
              _condition(p) *
              dutyDefenseMultiplier(p.duty) *
              roleMultiplier(p, forAttack: false) *
              positionFitMultiplier(p, slotById[p.id] ?? p.position),
    );
    final avgWorkRate = _avgAttribute(lineup, AttributeKeys.workRate);
    final result = (total / relevant.length) *
        t.formation.defenseBias *
        pressingDefenseFactor(t.pressing, avgWorkRate) *
        lineHeightDefenseRiskFactor(t.lineHeight) *
        widthDefenseRiskFactor(t.width);
    return t.timeWastingMode ? result * 1.08 : result;
  }

  /// [markingTeam]がマンマーク役を出場させている場合、[targetLineup]の
  /// キープレイヤーのIDを返す(攻撃力算出時にそのプレイヤーの貢献を抑える)。
  static String? markedTargetId(
    Team markingTeam,
    List<Player> markingLineup,
    List<Player> targetLineup,
  ) {
    final markerId = markingTeam.manMarkerId;
    if (markerId == null) return null;
    final markerActive = markingLineup.any((p) => p.id == markerId);
    if (!markerActive) return null;
    return identifyKeyPlayer(targetLineup)?.id;
  }

  static Player? _pickScorer(List<Player> lineup) {
    final candidates = lineup
        .where(
          (p) =>
              p.position.group == PositionGroup.att ||
              p.position.group == PositionGroup.mid,
        )
        .toList();
    if (candidates.isEmpty) return lineup.isNotEmpty ? lineup.first : null;
    final total = candidates.fold<int>(0, (s, p) => s + p.attack);
    if (total <= 0) return candidates[_rng.nextInt(candidates.length)];
    int r = _rng.nextInt(total);
    for (final p in candidates) {
      if (r < p.attack) return p;
      r -= p.attack;
    }
    return candidates.last;
  }

  /// 得点者以外のラインナップから、パス能力で重み付けしてアシスト選手を
  /// 選出する。ゴールの一定割合は個人技によるものとして、そもそも
  /// アシストなし(null)になる。
  static Player? _pickAssist(List<Player> lineup, Player? scorer) {
    if (_rng.nextDouble() < 0.22) return null;
    final candidates =
        lineup.where((p) => scorer == null || p.id != scorer.id).toList();
    if (candidates.isEmpty) return null;
    final total = candidates.fold<int>(
      0,
      (s, p) => s + p.attributeValue(AttributeKeys.passing),
    );
    if (total <= 0) return candidates[_rng.nextInt(candidates.length)];
    int r = _rng.nextInt(total);
    for (final p in candidates) {
      final w = p.attributeValue(AttributeKeys.passing);
      if (r < w) return p;
      r -= w;
    }
    return candidates.last;
  }

  static bool _isRightWide(Position p) =>
      p == Position.dr ||
      p == Position.wbr ||
      p == Position.mr ||
      p == Position.amr;
  static bool _isLeftWide(Position p) =>
      p == Position.dl ||
      p == Position.wbl ||
      p == Position.ml ||
      p == Position.aml;

  /// 攻撃側のサイドで仕掛ける選手を1人選ぶ(右サイド/左サイドはランダムに
  /// 決める)。ワイドなポジションの選手がいなければnull(中央からの
  /// 崩ししか起こらないフォーメーションを想定)。
  static Player? _pickWideAttacker(List<Player> lineup, bool right) {
    final candidates = lineup
        .where(
          (p) => right ? _isRightWide(p.position) : _isLeftWide(p.position),
        )
        .toList();
    if (candidates.isEmpty) return null;
    final total = candidates.fold<int>(0, (s, p) => s + p.attack);
    if (total <= 0) return candidates[_rng.nextInt(candidates.length)];
    int r = _rng.nextInt(total);
    for (final p in candidates) {
      if (r < p.attack) return p;
      r -= p.attack;
    }
    return candidates.last;
  }

  /// 攻撃側の仕掛けと同サイドを守る守備者を探す(最も守備寄りの選手を
  /// マーカーとみなす)。同サイドに守備者がいなければnull(=数的優位)。
  static Player? _findSameSideDefender(List<Player> lineup, bool right) {
    final candidates = lineup
        .where(
          (p) => right ? _isRightWide(p.position) : _isLeftWide(p.position),
        )
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.defense.compareTo(a.defense));
    return candidates.first;
  }

  /// サイドでの1対1(スピード・ドリブル・ひらめき vs スピード・対応・
  /// ポジショニング)の突破成功率。対面の守備者がいなければ数的優位として
  /// 高確率で突破できる。
  static double _wideDuelWinProb(Player attacker, Player? defender) {
    final attackSkill = attacker.attributeValue(AttributeKeys.pace) * 0.4 +
        attacker.attributeValue(AttributeKeys.dribbling) * 0.4 +
        attacker.attributeValue(AttributeKeys.flair) * 0.2;
    if (defender == null) return 0.85;
    final defendSkill = defender.attributeValue(AttributeKeys.pace) * 0.35 +
        defender.attributeValue(AttributeKeys.tackling) * 0.4 +
        defender.attributeValue(AttributeKeys.positioning) * 0.25;
    return (0.5 + (attackSkill - defendSkill) / 150).clamp(0.15, 0.9);
  }

  /// クロスに合わせる標的を、ヘディング・ジャンプ力で重み付けして選ぶ。
  static Player? _pickAerialTarget(List<Player> lineup, {String? excludeId}) {
    final candidates = lineup
        .where(
          (p) => p.position.group == PositionGroup.att && p.id != excludeId,
        )
        .toList();
    if (candidates.isEmpty) {
      return lineup.where((p) => p.id != excludeId).isEmpty
          ? null
          : lineup.firstWhere((p) => p.id != excludeId);
    }
    final total = candidates.fold<int>(
      0,
      (s, p) =>
          s +
          p.attributeValue(AttributeKeys.heading) +
          p.attributeValue(AttributeKeys.jumpingReach),
    );
    if (total <= 0) return candidates[_rng.nextInt(candidates.length)];
    int r = _rng.nextInt(total);
    for (final p in candidates) {
      final w = p.attributeValue(AttributeKeys.heading) +
          p.attributeValue(AttributeKeys.jumpingReach);
      if (r < w) return p;
      r -= w;
    }
    return candidates.last;
  }

  /// 相手最終ラインの中で最も空中戦に強い選手をマーカーとみなし、標的との
  /// 空中戦の優劣をスコア確率への倍率(0.7〜1.3)として返す。
  static double _aerialDuelFactor(Player target, List<Player> defendingLineup) {
    final defenders = defendingLineup
        .where((p) => p.position.group == PositionGroup.def)
        .toList();
    if (defenders.isEmpty) return 1.0;
    Player marker = defenders.first;
    for (final d in defenders) {
      final dSkill = d.attributeValue(AttributeKeys.heading) +
          d.attributeValue(AttributeKeys.jumpingReach);
      final mSkill = marker.attributeValue(AttributeKeys.heading) +
          marker.attributeValue(AttributeKeys.jumpingReach);
      if (dSkill > mSkill) marker = d;
    }
    final targetSkill = target.attributeValue(AttributeKeys.heading) +
        target.attributeValue(AttributeKeys.jumpingReach);
    final markerSkill = marker.attributeValue(AttributeKeys.heading) +
        marker.attributeValue(AttributeKeys.jumpingReach);
    return (1 + (targetSkill - markerSkill) / 300).clamp(0.7, 1.3);
  }

  /// クロスに合わせるヘディングシュートの質(フィニッシュ属性ではなく
  /// ヘディング・ジャンプ力・冷静さを基準にする)。
  static double _applyHeaderQuality(double scoreProb, Player? scorer) {
    if (scorer == null) return scoreProb;
    final quality = scorer.attributeValue(AttributeKeys.heading) * 0.5 +
        scorer.attributeValue(AttributeKeys.jumpingReach) * 0.3 +
        scorer.attributeValue(AttributeKeys.composure) * 0.2;
    return (scoreProb * (1 + (quality - 50) / 150)).clamp(0.05, 0.85);
  }

  /// セットプレー担当に指名された選手を出場中のメンバーから探す。
  /// 指名なし、または指名選手が出場していない(負傷・出場停止など)場合はnull。
  static Player? _pickSetPieceTaker(String? takerId, List<Player> lineup) {
    if (takerId == null) return null;
    for (final p in lineup) {
      if (p.id == takerId) return p;
    }
    return null;
  }

  static void _applyFatigue(
    Team t,
    List<Player> lineup, {
    double weatherFactor = 1.0,
    double intensity = 1.0,
  }) {
    final timeWastingFactor = t.timeWastingMode ? 0.85 : 1.0;
    for (final p in lineup) {
      final gain = (12 + _rng.nextInt(8)) *
          pressingFatigueFactor(t.pressing) *
          tempoFatigueFactor(t.tempo) *
          weatherFactor *
          timeWastingFactor *
          intensity;
      p.fatigue = (p.fatigue + gain.round()).clamp(0, 100);
    }
  }

  /// ライン高さがチームの攻撃力に与える倍率(高いラインほど攻撃的)。
  static double lineHeightAttackFactor(int lineHeight) =>
      1 + (lineHeight - 50) / 400;

  /// 攻撃の幅がチームの攻撃力に与える倍率。
  static double widthAttackFactor(int width) => 1 + (width - 50) / 500;

  /// 選手のある能力値の、出場メンバー内での平均値。
  static double _avgAttribute(List<Player> lineup, String key) {
    if (lineup.isEmpty) return 50;
    final total = lineup.fold<double>(0, (s, p) => s + p.attributeValue(key));
    return total / lineup.length;
  }

  /// 戦術とスカッドの適性係数(0.7〜1.3)。狙った戦術に必要な能力値が
  /// 高い選手が多いほど、その戦術のボーナス(またはリスク)がより強く出る。
  /// 低いと「やろうとしていることに選手がついていけない」形で減衰する。
  static double tacticalFitFactor(double avgAttribute) =>
      (0.7 + avgAttribute / 165).clamp(0.7, 1.3);

  /// テンポがチームの攻撃力に与える倍率。スタミナの高い選手が多いほど
  /// 高テンポのメリットを最大限に活かせる。
  static double tempoAttackFactor(int tempo, [double avgStamina = 50]) =>
      1 + (tempo - 50) / 500 * tacticalFitFactor(avgStamina);

  /// プレッシングがチームの守備力(ボール奪取)に与える倍率。労働量
  /// (workRate)の高い選手が多いほど、狙い通りにボールを奪いにいける。
  static double pressingDefenseFactor(
    int pressing, [
    double avgWorkRate = 50,
  ]) =>
      1 + (pressing - 50) / 400 * tacticalFitFactor(avgWorkRate);

  /// ライン高さがチームの守備力に与えるリスク倍率(高いラインほど守備が手薄になる)。
  static double lineHeightDefenseRiskFactor(int lineHeight) =>
      1 + (50 - lineHeight) / 500;

  /// 攻撃の幅がチームの守備力に与えるリスク倍率(幅が広いほど守備が手薄になる)。
  static double widthDefenseRiskFactor(int width) => 1 - (width - 50) / 800;

  /// プレッシングが1試合あたりの疲労蓄積に与える倍率。
  static double pressingFatigueFactor(int pressing) =>
      1 + (pressing - 50) / 200;

  /// テンポが1試合あたりの疲労蓄積に与える倍率。
  static double tempoFatigueFactor(int tempo) => 1 + (tempo - 50) / 300;

  /// 現在の戦術スライダー設定が攻撃力・守備力・疲労蓄積にどれだけ影響しているかを
  /// 倍率として要約する(戦術画面での定量的なフィードバック用)。
  static ({
    double attackMultiplier,
    double defenseMultiplier,
    double fatigueMultiplier,
  }) tacticalImpact(Team t) {
    final lineup = lineupOf(t);
    final avgStamina = _avgAttribute(lineup, AttributeKeys.stamina);
    final avgWorkRate = _avgAttribute(lineup, AttributeKeys.workRate);
    return (
      attackMultiplier: lineHeightAttackFactor(t.lineHeight) *
          widthAttackFactor(t.width) *
          tempoAttackFactor(t.tempo, avgStamina),
      defenseMultiplier: pressingDefenseFactor(t.pressing, avgWorkRate) *
          lineHeightDefenseRiskFactor(t.lineHeight) *
          widthDefenseRiskFactor(t.width),
      fatigueMultiplier:
          pressingFatigueFactor(t.pressing) * tempoFatigueFactor(t.tempo),
    );
  }

  /// 前半終了時点(ハーフタイム)で、そこまでの運動量に応じた疲労を先に
  /// 反映する。従来は試合終了後にまとめて疲労を加算していたため、後半の
  /// シミュレーションが前半の運動量を全く考慮しないという問題があった。
  /// ここで前半分(intensity 0.5)を反映し、残り半分は
  /// [applyPostMatchEffects]で後半終了時にまとめて反映する。
  static void applyHalfTimeFatigue({
    required Team home,
    required Team away,
    Weather weather = Weather.clear,
  }) {
    final homeLineup = lineupOf(home);
    final awayLineup = lineupOf(away);
    _applyFatigue(
      home,
      homeLineup,
      weatherFactor: weather.fatigueMultiplier,
      intensity: 0.5,
    );
    _applyFatigue(
      away,
      awayLineup,
      weatherFactor: weather.fatigueMultiplier,
      intensity: 0.5,
    );
  }

  /// 本職外のスロットで出場した選手のポジション慣れ度を積み増す。
  static void _growPositionFamiliarity(Team t, List<Player> lineup) {
    final slotById = LineupUtils.assignedSlotByPlayerId(t);
    for (final p in lineup) {
      final slot = slotById[p.id];
      if (slot == null) continue;
      p.growFamiliarity(slot);
    }
  }

  /// 出場した選手はマッチシャープネスが上昇し、出場しなかった選手は
  /// 緩やかに低下する(下限あり)。
  static void _updateMatchSharpness(Team t, List<Player> lineup) {
    final lineupIds = lineup.map((p) => p.id).toSet();
    for (final p in t.players) {
      if (lineupIds.contains(p.id)) {
        p.matchSharpness = (p.matchSharpness + 6).clamp(0, 100);
      } else {
        p.matchSharpness = (p.matchSharpness - 3).clamp(30, 100);
      }
    }
  }

  static void _rollInjuries(List<Player> lineup, double injuryFactor) {
    for (final p in lineup) {
      // 基礎体力(naturalFitness)が高い選手ほど負傷しにくい。
      final naturalFitnessFactor =
          (1 - (p.attributeValue(AttributeKeys.naturalFitness) - 50) / 200)
              .clamp(0.5, 1.5);
      final chance = (0.03 + (p.fatigue / 100) * 0.05) *
          injuryFactor *
          naturalFitnessFactor;
      if (_rng.nextDouble() < chance) {
        final type = _rollInjuryType(p);
        final range = type.durationRange;
        final weeks =
            (range.$1 + _rng.nextInt(range.$2 - range.$1 + 1)) * injuryFactor;
        p.injuryWeeks = weeks.round().clamp(1, range.$2);
        p.injuryType = type;
        p.injuryHistoryCounts[type.name] =
            (p.injuryHistoryCounts[type.name] ?? 0) + 1;
      }
    }
  }

  /// 負傷の種類を重み付き抽選で決める。同じ種類を過去に負ったことが
  /// あると再発しやすい(重みが増す)。
  static InjuryType _rollInjuryType(Player p) {
    final weights = <InjuryType, double>{
      InjuryType.bruise: 3.0,
      InjuryType.muscle: 2.0,
      InjuryType.ligament: 1.0,
    };
    for (final type in InjuryType.values) {
      final history = p.injuryHistoryCounts[type.name] ?? 0;
      if (history > 0) weights[type] = weights[type]! * (1 + 0.3 * history);
    }
    final total = weights.values.fold<double>(0, (s, w) => s + w);
    var r = _rng.nextDouble() * total;
    for (final entry in weights.entries) {
      if (r < entry.value) return entry.key;
      r -= entry.value;
    }
    return InjuryType.bruise;
  }

  /// 規律ボーナスの対象となるリーダーを探す。キャプテンが出場していれば
  /// それを、出場していなければ(負傷・出場停止・ベンチ等で)副キャプテンを
  /// 代わりに用いる。どちらも出場していなければnull。
  static Player? _findCaptainOrVice(Team team, List<Player> lineup) {
    if (team.captainId != null) {
      for (final p in lineup) {
        if (p.id == team.captainId) return p;
      }
    }
    if (team.viceCaptainId != null) {
      for (final p in lineup) {
        if (p.id == team.viceCaptainId) return p;
      }
    }
    return null;
  }

  static Player? _pickCardTarget(List<Player> lineup) {
    final candidates =
        lineup.where((p) => p.position.group != PositionGroup.gk).toList();
    if (candidates.isEmpty) return null;
    final weights = candidates
        .map(
          (p) =>
              1 +
              p.attributeValue(AttributeKeys.aggression) ~/ 10 +
              (100 - p.attributeValue(AttributeKeys.composure)) ~/ 25,
        )
        .toList();
    final total = weights.fold<int>(0, (s, w) => s + w);
    if (total <= 0) return candidates[_rng.nextInt(candidates.length)];
    int r = _rng.nextInt(total);
    for (int i = 0; i < candidates.length; i++) {
      if (r < weights[i]) return candidates[i];
      r -= weights[i];
    }
    return candidates.last;
  }

  /// [startMinute]〜[endMinute](両端含む)の区間だけをシミュレートする。
  /// ハーフタイムでの交代・戦術変更を反映できるよう、前半・後半を別々に
  /// 呼び出せるようにするための下位レベルAPI。疲労・負傷はここでは
  /// 適用しない([applyPostMatchEffects]を試合終了後に別途呼ぶこと)。
  static HalfResult simulateMinutes({
    required Team home,
    required Team away,
    required int startMinute,
    required int endMinute,
    Weather weather = Weather.clear,
    double homeAdvantageFactor = 1.06,
  }) {
    // 前半開始時に全選手のフラグをリセットして先発の倍率を算出する。
    // 後半開始時は、前半に出場せず後半で初めて起用された選手(途中出場の
    // 交代選手・負傷者の穴埋め等)にのみ改めて算出する。
    if (startMinute == 1) {
      _rollMatchForm(home, away, weather);
    } else {
      _rollMatchFormForCurrentLineup(home, away, weather);
    }
    // この半で誰がまだ警告を受けていないかを判定するため、半の開始ごとに
    // リセットする(2枚目の警告=退場という判定に使う。前半・後半は
    // それぞれ独立してカウントする)。
    for (final p in home.players) {
      p.yellowCardedThisHalf = false;
    }
    for (final p in away.players) {
      p.yellowCardedThisHalf = false;
    }

    final homeLineup = lineupOf(home);
    final awayLineup = lineupOf(away);

    final homeMarkedId = markedTargetId(away, awayLineup, homeLineup);
    final awayMarkedId = markedTargetId(home, homeLineup, awayLineup);

    final homeAttackBase =
        _attackPower(home, homeLineup, suppressedId: homeMarkedId) *
            homeAdvantageFactor *
            weather.attackMultiplier;
    final awayAttackBase =
        _attackPower(away, awayLineup, suppressedId: awayMarkedId) *
            weather.attackMultiplier;
    final homeDefenseBase =
        _defensePower(home, homeLineup) * weather.defenseMultiplier;
    final awayDefenseBase =
        _defensePower(away, awayLineup) * weather.defenseMultiplier;

    final events = <MatchEvent>[];
    int homeGoals = 0;
    int awayGoals = 0;
    final span = endMinute - startMinute + 1;
    final minutesUsed = <int>{};

    // カードイベント(警告・退場)を先に生成し、退場が発生した分数を記録する。
    // ゴールチャンスの評価時にこの分数以降は数的不利として攻守力を下げる。
    int? homeRedMinute;
    int? awayRedMinute;
    final cardChances = ((1 + _rng.nextInt(4)) * span / 90).round().clamp(0, 6);
    for (int i = 0; i < cardChances; i++) {
      final minute = startMinute + _rng.nextInt(span);
      if (minutesUsed.contains(minute)) continue;
      minutesUsed.add(minute);
      final isHomeTeam = _rng.nextBool();
      final lineup = isHomeTeam ? homeLineup : awayLineup;
      final team = isHomeTeam ? home : away;
      // キャプテン(不在なら副キャプテン)が出場しているチームは規律が保たれ、
      // カードをやや受けにくい。効果の大きさはそのリーダーのleadership値で
      // 変わる(値が高いほど効果的、というのはグロッサリーの説明にも合わせる)。
      final leader = _findCaptainOrVice(team, lineup);
      if (leader != null &&
          _rng.nextDouble() <
              (0.15 + leader.attributeValue(AttributeKeys.leadership) / 400)) {
        continue;
      }
      final target = _pickCardTarget(lineup);
      if (target == null) continue;
      // 同じ半で既に警告を受けている選手が再びカード対象に選ばれた場合、
      // 実際のルール通り2枚目の警告は退場(レッドカード)として扱う。
      final isSecondYellow = target.yellowCardedThisHalf;
      final isRed = isSecondYellow || _rng.nextDouble() < 0.08;
      if (!isRed) target.yellowCardedThisHalf = true;
      events.add(
        MatchEvent(
          minute: minute,
          teamId: team.id,
          scorerName: target.name,
          scorerId: target.id,
          type: isRed ? MatchEventType.redCard : MatchEventType.yellowCard,
        ),
      );
      if (isRed) {
        if (isHomeTeam) {
          homeRedMinute =
              homeRedMinute == null ? minute : min(homeRedMinute, minute);
        } else {
          awayRedMinute =
              awayRedMinute == null ? minute : min(awayRedMinute, minute);
        }
      }
      // 警告・退場の累積処理は試合終了後にapplyPostMatchEffectsでまとめて行う
      // (出場停止の消化判定より後に反映しないと、今節退場した選手の出場停止が
      // 同じ試合の後処理で即座に解除されてしまうため)。
    }

    // 時間稼ぎモードは疲労軽減の恩恵がある一方、遅延行為として審判の
    // 目を引きやすくなるリスクを負う(追加の警告チャンスを1回だけ判定)。
    for (final t in [home, away]) {
      if (!t.timeWastingMode) continue;
      if (_rng.nextDouble() >= 0.18 * span / 90) continue;
      final minute = startMinute + _rng.nextInt(span);
      if (minutesUsed.contains(minute)) continue;
      final lineup = t.id == home.id ? homeLineup : awayLineup;
      final target = _pickCardTarget(lineup);
      if (target == null) continue;
      minutesUsed.add(minute);
      final isHomeTeam = t.id == home.id;
      // ここも同じ半で既に警告済みの選手が対象になった場合は退場扱いにする。
      final isSecondYellow = target.yellowCardedThisHalf;
      if (!isSecondYellow) target.yellowCardedThisHalf = true;
      events.add(
        MatchEvent(
          minute: minute,
          teamId: t.id,
          scorerName: target.name,
          scorerId: target.id,
          type: isSecondYellow
              ? MatchEventType.redCard
              : MatchEventType.yellowCard,
        ),
      );
      if (isSecondYellow) {
        if (isHomeTeam) {
          homeRedMinute =
              homeRedMinute == null ? minute : min(homeRedMinute, minute);
        } else {
          awayRedMinute =
              awayRedMinute == null ? minute : min(awayRedMinute, minute);
        }
      }
    }

    // ゴールチャンスは時系列(分)順に評価し、退場による数的不利と
    // 直近の得点による「勢い」を反映する。
    final totalChances =
        ((9 + _rng.nextInt(8)) * span / 90 * weather.chanceCountMultiplier)
            .round()
            .clamp(1, 20);
    final chanceMinutes = <int>[];
    for (int i = 0; i < totalChances; i++) {
      int minute = startMinute;
      var guard = 0;
      do {
        minute = startMinute + _rng.nextInt(span);
        guard++;
      } while (minutesUsed.contains(minute) && guard < 50);
      minutesUsed.add(minute);
      chanceMinutes.add(minute);
    }
    chanceMinutes.sort();

    double homeMomentum = 0;
    double awayMomentum = 0;
    int homeShots = 0;
    int awayShots = 0;
    int homeShotsOnTarget = 0;
    int awayShotsOnTarget = 0;
    double possessionShareSum = 0;
    for (final minute in chanceMinutes) {
      final homeRedActive = homeRedMinute != null && minute > homeRedMinute;
      final awayRedActive = awayRedMinute != null && minute > awayRedMinute;
      final homeAttack = homeAttackBase * (homeRedActive ? 0.85 : 1.0);
      final awayAttack = awayAttackBase * (awayRedActive ? 0.85 : 1.0);
      final homeDefense = homeDefenseBase * (homeRedActive ? 0.82 : 1.0);
      final awayDefense = awayDefenseBase * (awayRedActive ? 0.82 : 1.0);

      final homeShare = homeAttack / (homeAttack + awayAttack);
      possessionShareSum += homeShare;
      final isHomeChance = _rng.nextDouble() < homeShare;
      if (isHomeChance) {
        homeShots++;
      } else {
        awayShots++;
      }
      final attackingLineup = isHomeChance ? homeLineup : awayLineup;
      final defendingLineup = isHomeChance ? awayLineup : homeLineup;
      final attackingTeam = isHomeChance ? home : away;
      final defendingTeam = isHomeChance ? away : home;
      final defendingDefense = isHomeChance ? awayDefense : homeDefense;
      final attackingPower = isHomeChance ? homeAttack : awayAttack;
      final momentum = isHomeChance ? homeMomentum : awayMomentum;

      final diff = attackingPower - defendingDefense;
      var scoreProb = (0.30 + diff / 220 + momentum).clamp(0.05, 0.75);
      Player? scorer;
      Player? forcedAssist;
      bool isPenalty = false;
      bool isDirectFreeKick = false;
      if (_rng.nextDouble() < 0.25) {
        // セットプレー(PK・直接FK・CK)由来のチャンス。担当に指名された選手が
        // いれば優先的に関わり、専門の能力値でチャンスの質が変わる。
        final subRoll = _rng.nextDouble();
        if (subRoll < 0.15) {
          isPenalty = true;
          scorer = _pickSetPieceTaker(
                attackingTeam.penaltyTakerId,
                attackingLineup,
              ) ??
              _pickScorer(attackingLineup);
          final penaltyAttr =
              scorer?.attributeValue(AttributeKeys.penalties) ?? 50;
          scoreProb = (0.55 + (penaltyAttr - 50) / 200).clamp(0.5, 0.9);
        } else if (subRoll < 0.55) {
          isDirectFreeKick = true;
          scorer = _pickSetPieceTaker(
                attackingTeam.freeKickTakerId,
                attackingLineup,
              ) ??
              _pickScorer(attackingLineup);
          final freeKickAttr =
              scorer?.attributeValue(AttributeKeys.freeKick) ?? 50;
          scoreProb = (0.18 + (freeKickAttr - 50) / 300).clamp(0.05, 0.35);
          scoreProb = applySetPieceDefense(
            scoreProb,
            defendingTeam,
            defendingLineup,
          );
        } else {
          final cornerTaker = _pickSetPieceTaker(
            attackingTeam.cornerTakerId,
            attackingLineup,
          );
          // コーナーは実際の得点シーンと同様、ヘディングに強い選手が
          // 合わせるケースを主として扱う(蹴った選手がそのままアシストになる)。
          scorer = _pickAerialTarget(
            attackingLineup,
            excludeId: cornerTaker?.id,
          );
          forcedAssist = cornerTaker;
          if (cornerTaker != null) {
            final cornersAttr = cornerTaker.attributeValue(
              AttributeKeys.corners,
            );
            // ロングスローもコーナーと同様に、ワイドからの精度あるボールの
            // 供給という点で質に少し寄与させる(コーナーの専門性を主としつつ)。
            final longThrowsAttr = cornerTaker.attributeValue(
              AttributeKeys.longThrows,
            );
            final deliveryQuality =
                (cornersAttr * 0.8 + longThrowsAttr * 0.2).round();
            scoreProb = (scoreProb * (1 + (deliveryQuality - 50) / 200)).clamp(
              0.05,
              0.75,
            );
          }
          scoreProb = applySetPieceDefense(
            scoreProb,
            defendingTeam,
            defendingLineup,
          );
          scoreProb = _applyHeaderQuality(scoreProb, scorer);
        }
      } else {
        // オープンプレー: まずサイドでの1対1を判定する。ワイドな選手が
        // いれば、対面の守備者とのデュエルに勝った場合のみクロス→空中戦の
        // 流れになり、負ければ質の落ちた通常の崩しに留まる。
        final right = _rng.nextBool();
        final wideAttacker = _pickWideAttacker(attackingLineup, right);
        final isWidePlay = wideAttacker != null && _rng.nextDouble() < 0.55;
        if (isWidePlay) {
          final marker = _findSameSideDefender(defendingLineup, right);
          final wonDuel =
              _rng.nextDouble() < _wideDuelWinProb(wideAttacker, marker);
          if (wonDuel) {
            scorer = _pickAerialTarget(
              attackingLineup,
              excludeId: wideAttacker.id,
            );
            forcedAssist = wideAttacker;
            final crossQuality = wideAttacker.attributeValue(
              AttributeKeys.crossing,
            );
            scoreProb = (scoreProb * (1 + (crossQuality - 50) / 250)).clamp(
              0.05,
              0.8,
            );
            if (scorer != null) {
              scoreProb =
                  scoreProb * _aerialDuelFactor(scorer, defendingLineup);
            }
            scoreProb = _applyHeaderQuality(scoreProb, scorer);
          } else {
            scorer = _pickScorer(attackingLineup);
            scoreProb = (scoreProb * 0.7).clamp(0.05, 0.75);
            scoreProb = _applyFinisherQuality(scoreProb, scorer);
          }
        } else {
          scorer = _pickScorer(attackingLineup);
          scoreProb = _applyFinisherQuality(scoreProb, scorer);
        }
      }
      if (_rng.nextDouble() < scoreProb) {
        final assist = (isPenalty || isDirectFreeKick)
            ? null
            : (forcedAssist ?? _pickAssist(attackingLineup, scorer));
        events.add(
          MatchEvent(
            minute: minute,
            teamId: attackingTeam.id,
            scorerName: scorer?.name,
            scorerId: scorer?.id,
            assistName: assist?.name,
            assistId: assist?.id,
          ),
        );
        if (isHomeChance) {
          homeGoals++;
          homeShotsOnTarget++;
          homeMomentum = (homeMomentum + 0.05).clamp(-0.08, 0.08);
          awayMomentum = (awayMomentum - 0.02).clamp(-0.08, 0.08);
        } else {
          awayGoals++;
          awayShotsOnTarget++;
          awayMomentum = (awayMomentum + 0.05).clamp(-0.08, 0.08);
          homeMomentum = (homeMomentum - 0.02).clamp(-0.08, 0.08);
        }
      } else if (_rng.nextDouble() < 0.45) {
        // 得点には至らなかった惜しいチャンスを実況として記録する(枠内シュート)。
        final shooter = _pickScorer(attackingLineup);
        if (isHomeChance) {
          homeShotsOnTarget++;
        } else {
          awayShotsOnTarget++;
        }
        events.add(
          MatchEvent(
            minute: minute,
            teamId: attackingTeam.id,
            scorerName: shooter?.name,
            scorerId: shooter?.id,
            type: MatchEventType.chance,
          ),
        );
      }
      homeMomentum *= 0.9;
      awayMomentum *= 0.9;
    }

    events.sort((a, b) => a.minute.compareTo(b.minute));
    return HalfResult(
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      events: events,
      homeShots: homeShots,
      awayShots: awayShots,
      homeShotsOnTarget: homeShotsOnTarget,
      awayShotsOnTarget: awayShotsOnTarget,
      possessionShareSum: possessionShareSum,
      chanceCount: chanceMinutes.length,
    );
  }

  /// 相手が守備セットプレー担当を指名して出場させている場合、その選手の
  /// ヘディング・ジャンプ力に応じてセットプレー由来のチャンスの質を下げる。
  static double applySetPieceDefense(
    double scoreProb,
    Team defendingTeam,
    List<Player> defendingLineup,
  ) {
    final defender = _pickSetPieceTaker(
      defendingTeam.setPieceDefenderId,
      defendingLineup,
    );
    if (defender == null) return scoreProb;
    final defSkill = (defender.attributeValue(AttributeKeys.heading) +
            defender.attributeValue(AttributeKeys.jumpingReach)) /
        2;
    return (scoreProb * (1 - (defSkill - 50) / 250)).clamp(0.05, 0.9);
  }

  /// オープンプレー・コーナーのチャンスにおいて、実際にそのチャンスを迎えた
  /// 選手個人のフィニッシュの質(決定力・冷静さ・オフザボール)を得点確率に
  /// 反映する。チーム総合力の平均値だけでチャンスの成否が決まってしまうと、
  /// 個々の選手の能力(誰がその1本を任されるか)が結果に表れなくなるため、
  /// PK・FKの専門能力反映と同じ考え方をオープンプレーにも適用する。
  static double _applyFinisherQuality(double scoreProb, Player? scorer) {
    if (scorer == null) return scoreProb;
    final quality = (scorer.attributeValue(AttributeKeys.finishing) * 0.5 +
        scorer.attributeValue(AttributeKeys.composure) * 0.3 +
        scorer.attributeValue(AttributeKeys.offTheBall) * 0.2);
    return (scoreProb * (1 + (quality - 50) / 150)).clamp(0.05, 0.85);
  }

  /// 試合終了後に一度だけ呼ぶ、疲労蓄積・負傷判定・出場停止の消化と新規カードの反映。
  /// [events]はこの試合(前後半通し)で発生した全イベント。
  static void applyPostMatchEffects({
    required Team home,
    required Team away,
    double homeInjuryFactor = 1.0,
    double awayInjuryFactor = 1.0,
    List<MatchEvent> events = const [],
    Weather weather = Weather.clear,
  }) {
    final homeLineup = lineupOf(home);
    final awayLineup = lineupOf(away);
    // 前半分の疲労は既にapplyHalfTimeFatigueで反映済みのため、ここでは
    // 後半分(intensity 0.5)のみを加算する。
    _applyFatigue(
      home,
      homeLineup,
      weatherFactor: weather.fatigueMultiplier,
      intensity: 0.5,
    );
    _applyFatigue(
      away,
      awayLineup,
      weatherFactor: weather.fatigueMultiplier,
      intensity: 0.5,
    );
    _rollInjuries(homeLineup, homeInjuryFactor);
    _rollInjuries(awayLineup, awayInjuryFactor);
    _growPositionFamiliarity(home, homeLineup);
    _growPositionFamiliarity(away, awayLineup);
    _updateMatchSharpness(home, homeLineup);
    _updateMatchSharpness(away, awayLineup);
    for (final p in [...homeLineup, ...awayLineup]) {
      TrainingEngine.growFromMatchExperience(p);
    }
    // 出場停止の消化は既存の出場停止(前節以前に受けたもの)にのみ適用し、
    // その後で今節に新たに受けたカードを反映する。
    _advanceSuspensions(home, homeLineup);
    _advanceSuspensions(away, awayLineup);
    _applyCardAccumulation(home, away, events);
    _applyCareerStats(homeLineup, awayLineup, events);
  }

  /// 出場選手の通算出場数・通算得点数を加算する(親善試合はこの関数を
  /// 呼ばないため対象外)。
  static void _applyCareerStats(
    List<Player> homeLineup,
    List<Player> awayLineup,
    List<MatchEvent> events,
  ) {
    final lineupIds = <String, Player>{
      for (final p in [...homeLineup, ...awayLineup]) p.id: p,
    };
    for (final p in lineupIds.values) {
      p.careerAppearances += 1;
    }
    for (final e in events) {
      if (e.type != MatchEventType.goal) continue;
      lineupIds[e.scorerId]?.careerGoals += 1;
    }
  }

  /// 出場停止選手のうち、今節の対象外だった(実際に1試合を消化した)選手だけ
  /// 出場停止試合数を1減らす。今節新たに出場停止となった選手(今節は出場して
  /// カードを受けた側)は対象外で、次節から出場停止が適用される。
  static void _advanceSuspensions(Team t, List<Player> lineup) {
    final lineupIds = lineup.map((p) => p.id).toSet();
    for (final p in t.players) {
      if (p.suspendedMatches > 0 && !lineupIds.contains(p.id)) {
        p.suspendedMatches -= 1;
      }
    }
  }

  /// 今節発生した警告・退場イベントを選手の累積数に反映する。
  static void _applyCardAccumulation(
    Team home,
    Team away,
    List<MatchEvent> events,
  ) {
    final byId = {
      for (final p in [...home.players, ...away.players]) p.id: p,
    };
    for (final e in events) {
      if (e.type != MatchEventType.yellowCard &&
          e.type != MatchEventType.redCard) {
        continue;
      }
      final target = byId[e.scorerId];
      if (target == null) continue;
      if (e.type == MatchEventType.redCard) {
        target.suspendedMatches += 1;
      } else {
        target.yellowCards += 1;
        if (target.yellowCards >= yellowCardSuspensionThreshold) {
          target.yellowCards = 0;
          target.suspendedMatches += 1;
        }
      }
    }
  }

  /// 出場した選手の試合内採点(1.0〜10.0)を算出する。基準点6.0から、得点・
  /// 決定機創出でプラス、警告・退場でマイナス、所属チームの勝敗で補正する。
  static Map<String, double> computePlayerRatings({
    required Team home,
    required Team away,
    required List<MatchEvent> events,
    required int homeGoals,
    required int awayGoals,
  }) {
    final homeLineup = lineupOf(home);
    final awayLineup = lineupOf(away);
    final ratings = <String, double>{};
    for (final p in [...homeLineup, ...awayLineup]) {
      ratings[p.id] = 6.0;
    }

    for (final e in events) {
      final id = e.scorerId;
      if (id != null && ratings.containsKey(id)) {
        switch (e.type) {
          case MatchEventType.goal:
            ratings[id] = ratings[id]! + 1.0;
            break;
          case MatchEventType.chance:
            ratings[id] = ratings[id]! + 0.3;
            break;
          case MatchEventType.yellowCard:
            ratings[id] = ratings[id]! - 0.5;
            break;
          case MatchEventType.redCard:
            ratings[id] = ratings[id]! - 1.5;
            break;
        }
      }
      // アシスト提供者にも得点者ほどではないが小幅な採点ボーナスを与える。
      final assistId = e.assistId;
      if (e.type == MatchEventType.goal &&
          assistId != null &&
          ratings.containsKey(assistId)) {
        ratings[assistId] = ratings[assistId]! + 0.5;
      }
    }

    final resultBonus = homeGoals > awayGoals
        ? 0.4
        : homeGoals < awayGoals
            ? -0.4
            : 0.0;
    for (final p in homeLineup) {
      ratings[p.id] = ratings[p.id]! + resultBonus;
    }
    for (final p in awayLineup) {
      ratings[p.id] = ratings[p.id]! - resultBonus;
    }

    return ratings.map(
      (id, r) => MapEntry(id, (r.clamp(1.0, 10.0) * 2).round() / 2),
    );
  }

  /// 前半・後半をまとめて一括シミュレートする(CPU同士の試合・カップ戦など、
  /// ハーフタイム操作が不要な場合に使う)。
  /// マンマーク指令が未指定のチームに対し、相手のキープレイヤーが自チームの
  /// 平均総合力を大きく上回る場合に限り、守備力最高の選手へ自動で指令する。
  /// 既に指名済み(=ユーザーが手動で指名した、または前節までに自動指令済み)
  /// の場合は上書きしない。CPUクラブが一切マンマークを使わず、ユーザーの
  /// キープレイヤーが常にノーマークになる一方的な状況を防ぐための処置。
  static void _maybeAutoAssignManMarker(Team team, List<Player> oppLineup) {
    if (team.manMarkerId != null) return;
    if (team.players.isEmpty) return;
    final keyPlayer = identifyKeyPlayer(oppLineup);
    if (keyPlayer == null) return;
    final avgOverall = team.players.fold<int>(0, (s, p) => s + p.overall) /
        team.players.length;
    if (keyPlayer.overall - avgOverall < 8) return;
    Player? marker;
    for (final p in team.players) {
      if (marker == null || p.defense > marker.defense) marker = p;
    }
    team.manMarkerId = marker?.id;
  }

  // ============================================================
  // インタラクティブ進行(自クラブの試合でシュート/パスを選べるモード)
  //
  // 以下は[simulateMinutes]/[simulate]とは完全に独立した並行実装。
  // 既存の一括シミュレーション(CPU同士の試合・カップ戦・クイックシム)は
  // 引き続き[simulateMinutes]/[simulate]をそのまま使い、一切変更しない。
  // ここでは、ユーザーが出場する試合のオープンプレーの決定機でのみ
  // [InteractiveHalfState.pending]に判断材料をセットして進行を一時停止し、
  // [resolvePendingChance]で選んだ結果を反映して再開できるようにする。
  // ============================================================

  /// パス/シュートの選択を求める判断材料。ダイアログ表示に使う。
  static const double _passWeightAttack = 1.0;

  /// パスでチャンスを継続する際につなぐ味方を選ぶ。攻撃力で重み付けし、
  /// 現状シュートする予定の選手は除外する(つなげる相手がいなければnull)。
  static Player? _pickPassTarget(List<Player> lineup, {String? excludeId}) {
    final candidates = lineup
        .where(
          (p) =>
              p.id != excludeId &&
              (p.position.group == PositionGroup.att ||
                  p.position.group == PositionGroup.mid),
        )
        .toList();
    if (candidates.isEmpty) return null;
    final total = candidates.fold<int>(
      0,
      (s, p) => s + (p.attack * _passWeightAttack).round(),
    );
    if (total <= 0) return candidates[_rng.nextInt(candidates.length)];
    int r = _rng.nextInt(total);
    for (final p in candidates) {
      final w = (p.attack * _passWeightAttack).round();
      if (r < w) return p;
      r -= w;
    }
    return candidates.last;
  }

  /// このチャンスを最終的な成功率([scoreProb])で判定し、結果に応じた
  /// イベントを[s.events]に追加する。実際に発生したイベント(得点/惜しい
  /// チャンス)を返す。何も起きなかった場合はnull。
  static MatchEvent? _finalizeChance(
    InteractiveHalfState s, {
    required int minute,
    required bool isHomeChance,
    required Team attackingTeam,
    required Player? scorer,
    required Player? forcedAssist,
    required double scoreProb,
    required bool isPenalty,
    required bool isDirectFreeKick,
  }) {
    final attackingLineup = isHomeChance ? s.homeLineup : s.awayLineup;
    MatchEvent? produced;
    if (_rng.nextDouble() < scoreProb) {
      final assist = (isPenalty || isDirectFreeKick)
          ? null
          : (forcedAssist ?? _pickAssist(attackingLineup, scorer));
      produced = MatchEvent(
        minute: minute,
        teamId: attackingTeam.id,
        scorerName: scorer?.name,
        scorerId: scorer?.id,
        assistName: assist?.name,
        assistId: assist?.id,
      );
      s.events.add(produced);
      if (isHomeChance) {
        s.homeGoals++;
        s.homeShotsOnTarget++;
        s.homeMomentum = (s.homeMomentum + 0.05).clamp(-0.08, 0.08);
        s.awayMomentum = (s.awayMomentum - 0.02).clamp(-0.08, 0.08);
      } else {
        s.awayGoals++;
        s.awayShotsOnTarget++;
        s.awayMomentum = (s.awayMomentum + 0.05).clamp(-0.08, 0.08);
        s.homeMomentum = (s.homeMomentum - 0.02).clamp(-0.08, 0.08);
      }
    } else if (_rng.nextDouble() < 0.45) {
      if (isHomeChance) {
        s.homeShotsOnTarget++;
      } else {
        s.awayShotsOnTarget++;
      }
      produced = MatchEvent(
        minute: minute,
        teamId: attackingTeam.id,
        scorerName: scorer?.name,
        scorerId: scorer?.id,
        type: MatchEventType.chance,
      );
      s.events.add(produced);
    }
    s.homeMomentum *= 0.9;
    s.awayMomentum *= 0.9;
    return produced;
  }

  /// 決定機の対象になった選手のオープンプレー基礎成功率([baseScoreProb])
  /// から、ロングシュートを選んだ場合の成功率を算出する。近距離のシュート
  /// より成功率は下がる一方、ロングシュート適性(longShots・technique)が
  /// 高い選手ほどその下げ幅が小さくなる。
  static double _applyLongShotQuality(double baseScoreProb, Player? shooter) {
    final reduced = (baseScoreProb * 0.55).clamp(0.03, 0.4);
    if (shooter == null) return reduced;
    final quality = shooter.attributeValue(AttributeKeys.longShots) * 0.65 +
        shooter.attributeValue(AttributeKeys.technique) * 0.35;
    return (reduced * (1 + (quality - 50) / 120)).clamp(0.03, 0.55);
  }

  /// 守備側が「積極的にタックル」を選んだ場合に、相手の得点成功率へ乗じる
  /// 倍率。より大きく下げる代わり、後述の警告/退場リスクを伴う。
  static const double _aggressiveTackleReduction = 0.72;

  /// 守備側が「カバーリングに専念」を選んだ場合の、相手の得点成功率への
  /// 倍率。下げ幅は控えめだが警告/退場のリスクを負わない安全な選択肢。
  static const double _coverSpaceReduction = 0.90;

  /// 積極的にタックルへ行った際に警告(まれに退場)を受ける基礎確率。
  static const double _aggressiveTackleCardChance = 0.16;

  /// [simulateMinutes]と同じ区間シミュレーションのセットアップ(カード生成・
  /// チャンス発生分の抽選・攻守力算出)を行い、チャンス評価に進む前の
  /// [InteractiveHalfState]を返す。呼び出し直後に内部で最初のチャンス評価まで
  /// 進めるため、[interactiveTeamId]の決定機が最初のチャンスにあれば
  /// 即座に[InteractiveHalfState.pending]がセットされた状態で返る。
  static InteractiveHalfState beginInteractiveHalf({
    required Team home,
    required Team away,
    required int startMinute,
    required int endMinute,
    required String interactiveTeamId,
    Weather weather = Weather.clear,
    double homeAdvantageFactor = 1.06,
  }) {
    if (startMinute == 1) {
      _rollMatchForm(home, away, weather);
    } else {
      _rollMatchFormForCurrentLineup(home, away, weather);
    }
    for (final p in home.players) {
      p.yellowCardedThisHalf = false;
    }
    for (final p in away.players) {
      p.yellowCardedThisHalf = false;
    }

    final homeLineup = lineupOf(home);
    final awayLineup = lineupOf(away);
    final homeMarkedId = markedTargetId(away, awayLineup, homeLineup);
    final awayMarkedId = markedTargetId(home, homeLineup, awayLineup);

    final homeAttackBase =
        _attackPower(home, homeLineup, suppressedId: homeMarkedId) *
            homeAdvantageFactor *
            weather.attackMultiplier;
    final awayAttackBase =
        _attackPower(away, awayLineup, suppressedId: awayMarkedId) *
            weather.attackMultiplier;
    final homeDefenseBase =
        _defensePower(home, homeLineup) * weather.defenseMultiplier;
    final awayDefenseBase =
        _defensePower(away, awayLineup) * weather.defenseMultiplier;

    final events = <MatchEvent>[];
    final span = endMinute - startMinute + 1;
    final minutesUsed = <int>{};

    int? homeRedMinute;
    int? awayRedMinute;
    final cardChances = ((1 + _rng.nextInt(4)) * span / 90).round().clamp(0, 6);
    for (int i = 0; i < cardChances; i++) {
      final minute = startMinute + _rng.nextInt(span);
      if (minutesUsed.contains(minute)) continue;
      minutesUsed.add(minute);
      final isHomeTeam = _rng.nextBool();
      final lineup = isHomeTeam ? homeLineup : awayLineup;
      final team = isHomeTeam ? home : away;
      final leader = _findCaptainOrVice(team, lineup);
      if (leader != null &&
          _rng.nextDouble() <
              (0.15 + leader.attributeValue(AttributeKeys.leadership) / 400)) {
        continue;
      }
      final target = _pickCardTarget(lineup);
      if (target == null) continue;
      final isSecondYellow = target.yellowCardedThisHalf;
      final isRed = isSecondYellow || _rng.nextDouble() < 0.08;
      if (!isRed) target.yellowCardedThisHalf = true;
      events.add(
        MatchEvent(
          minute: minute,
          teamId: team.id,
          scorerName: target.name,
          scorerId: target.id,
          type: isRed ? MatchEventType.redCard : MatchEventType.yellowCard,
        ),
      );
      if (isRed) {
        if (isHomeTeam) {
          homeRedMinute =
              homeRedMinute == null ? minute : min(homeRedMinute, minute);
        } else {
          awayRedMinute =
              awayRedMinute == null ? minute : min(awayRedMinute, minute);
        }
      }
    }

    for (final t in [home, away]) {
      if (!t.timeWastingMode) continue;
      if (_rng.nextDouble() >= 0.18 * span / 90) continue;
      final minute = startMinute + _rng.nextInt(span);
      if (minutesUsed.contains(minute)) continue;
      final lineup = t.id == home.id ? homeLineup : awayLineup;
      final target = _pickCardTarget(lineup);
      if (target == null) continue;
      minutesUsed.add(minute);
      final isHomeTeam = t.id == home.id;
      final isSecondYellow = target.yellowCardedThisHalf;
      if (!isSecondYellow) target.yellowCardedThisHalf = true;
      events.add(
        MatchEvent(
          minute: minute,
          teamId: t.id,
          scorerName: target.name,
          scorerId: target.id,
          type: isSecondYellow
              ? MatchEventType.redCard
              : MatchEventType.yellowCard,
        ),
      );
      if (isSecondYellow) {
        if (isHomeTeam) {
          homeRedMinute =
              homeRedMinute == null ? minute : min(homeRedMinute, minute);
        } else {
          awayRedMinute =
              awayRedMinute == null ? minute : min(awayRedMinute, minute);
        }
      }
    }

    final totalChances =
        ((9 + _rng.nextInt(8)) * span / 90 * weather.chanceCountMultiplier)
            .round()
            .clamp(1, 20);
    final chanceMinutes = <int>[];
    for (int i = 0; i < totalChances; i++) {
      int minute = startMinute;
      var guard = 0;
      do {
        minute = startMinute + _rng.nextInt(span);
        guard++;
      } while (minutesUsed.contains(minute) && guard < 50);
      minutesUsed.add(minute);
      chanceMinutes.add(minute);
    }
    chanceMinutes.sort();

    final state = InteractiveHalfState(
      home: home,
      away: away,
      interactiveTeamId: interactiveTeamId,
      homeLineup: homeLineup,
      awayLineup: awayLineup,
      homeAttackBase: homeAttackBase,
      awayAttackBase: awayAttackBase,
      homeDefenseBase: homeDefenseBase,
      awayDefenseBase: awayDefenseBase,
      homeRedMinute: homeRedMinute,
      awayRedMinute: awayRedMinute,
      chanceMinutes: chanceMinutes,
      events: events,
    );
    _advanceInteractiveHalf(state);
    return state;
  }

  static void _advanceInteractiveHalf(InteractiveHalfState s) {
    while (s.chanceIndex < s.chanceMinutes.length) {
      final minute = s.chanceMinutes[s.chanceIndex];
      final homeRedActive =
          s.homeRedMinute != null && minute > s.homeRedMinute!;
      final awayRedActive =
          s.awayRedMinute != null && minute > s.awayRedMinute!;
      final homeAttack = s.homeAttackBase * (homeRedActive ? 0.85 : 1.0);
      final awayAttack = s.awayAttackBase * (awayRedActive ? 0.85 : 1.0);
      final homeDefense = s.homeDefenseBase * (homeRedActive ? 0.82 : 1.0);
      final awayDefense = s.awayDefenseBase * (awayRedActive ? 0.82 : 1.0);

      final homeShare = homeAttack / (homeAttack + awayAttack);
      s.possessionShareSum += homeShare;
      final isHomeChance = _rng.nextDouble() < homeShare;
      if (isHomeChance) {
        s.homeShots++;
      } else {
        s.awayShots++;
      }
      final attackingLineup = isHomeChance ? s.homeLineup : s.awayLineup;
      final defendingLineup = isHomeChance ? s.awayLineup : s.homeLineup;
      final attackingTeam = isHomeChance ? s.home : s.away;
      final defendingTeam = isHomeChance ? s.away : s.home;
      final defendingDefense = isHomeChance ? awayDefense : homeDefense;
      final attackingPower = isHomeChance ? homeAttack : awayAttack;
      final momentum = isHomeChance ? s.homeMomentum : s.awayMomentum;

      final diff = attackingPower - defendingDefense;
      var scoreProb = (0.30 + diff / 220 + momentum).clamp(0.05, 0.75);
      Player? scorer;
      Player? forcedAssist;
      bool isPenalty = false;
      bool isDirectFreeKick = false;
      bool isInteractiveOpenPlay = false;

      if (_rng.nextDouble() < 0.25) {
        // セットプレー(PK・直接FK・CK): 従来通り即座に解決する
        // (シュート/パスの選択はオープンプレーの通常シュートに限定する)。
        final subRoll = _rng.nextDouble();
        if (subRoll < 0.15) {
          isPenalty = true;
          scorer = _pickSetPieceTaker(
                attackingTeam.penaltyTakerId,
                attackingLineup,
              ) ??
              _pickScorer(attackingLineup);
          final penaltyAttr =
              scorer?.attributeValue(AttributeKeys.penalties) ?? 50;
          scoreProb = (0.55 + (penaltyAttr - 50) / 200).clamp(0.5, 0.9);
        } else if (subRoll < 0.55) {
          isDirectFreeKick = true;
          scorer = _pickSetPieceTaker(
                attackingTeam.freeKickTakerId,
                attackingLineup,
              ) ??
              _pickScorer(attackingLineup);
          final freeKickAttr =
              scorer?.attributeValue(AttributeKeys.freeKick) ?? 50;
          scoreProb = (0.18 + (freeKickAttr - 50) / 300).clamp(0.05, 0.35);
          scoreProb = applySetPieceDefense(
            scoreProb,
            defendingTeam,
            defendingLineup,
          );
        } else {
          final cornerTaker = _pickSetPieceTaker(
            attackingTeam.cornerTakerId,
            attackingLineup,
          );
          scorer = _pickAerialTarget(
            attackingLineup,
            excludeId: cornerTaker?.id,
          );
          forcedAssist = cornerTaker;
          if (cornerTaker != null) {
            final cornersAttr = cornerTaker.attributeValue(
              AttributeKeys.corners,
            );
            final longThrowsAttr = cornerTaker.attributeValue(
              AttributeKeys.longThrows,
            );
            final deliveryQuality =
                (cornersAttr * 0.8 + longThrowsAttr * 0.2).round();
            scoreProb = (scoreProb * (1 + (deliveryQuality - 50) / 200)).clamp(
              0.05,
              0.75,
            );
          }
          scoreProb = applySetPieceDefense(
            scoreProb,
            defendingTeam,
            defendingLineup,
          );
          scoreProb = _applyHeaderQuality(scoreProb, scorer);
        }
      } else {
        // オープンプレー: サイドでの1対1をまず判定する。
        final right = _rng.nextBool();
        final wideAttacker = _pickWideAttacker(attackingLineup, right);
        final isWidePlay = wideAttacker != null && _rng.nextDouble() < 0.55;
        if (isWidePlay) {
          final marker = _findSameSideDefender(defendingLineup, right);
          final wonDuel =
              _rng.nextDouble() < _wideDuelWinProb(wideAttacker, marker);
          if (wonDuel) {
            // クロス→ヘディング: 従来通り即座に解決する(選択の対象外)。
            scorer = _pickAerialTarget(
              attackingLineup,
              excludeId: wideAttacker.id,
            );
            forcedAssist = wideAttacker;
            final crossQuality = wideAttacker.attributeValue(
              AttributeKeys.crossing,
            );
            scoreProb = (scoreProb * (1 + (crossQuality - 50) / 250)).clamp(
              0.05,
              0.8,
            );
            if (scorer != null) {
              scoreProb =
                  scoreProb * _aerialDuelFactor(scorer, defendingLineup);
            }
            scoreProb = _applyHeaderQuality(scoreProb, scorer);
          } else {
            scorer = _pickScorer(attackingLineup);
            scoreProb = (scoreProb * 0.7).clamp(0.05, 0.75);
            isInteractiveOpenPlay = true;
          }
        } else {
          scorer = _pickScorer(attackingLineup);
          isInteractiveOpenPlay = true;
        }
      }

      if (isInteractiveOpenPlay) {
        if (attackingTeam.id == s.interactiveTeamId) {
          // 自クラブの攻撃側決定機: シュート/パス/ロングシュートを選べる。
          final passTarget = _pickPassTarget(
            attackingLineup,
            excludeId: scorer?.id,
          );
          s.pending = PendingChanceDecision.attack(
            minute: minute,
            shooter: scorer!,
            passTarget: passTarget,
            shootChance: _applyFinisherQuality(scoreProb, scorer).clamp(
              0.0,
              1.0,
            ),
            passChance: passTarget != null
                ? _applyFinisherQuality(scoreProb, passTarget).clamp(0.0, 1.0)
                : null,
            longShotChance: _applyLongShotQuality(scoreProb, scorer).clamp(
              0.0,
              1.0,
            ),
          );
          s.pendingIsHomeChance = isHomeChance;
          return; // ここで一時停止。再開はresolvePendingChanceから。
        }
        if (defendingTeam.id == s.interactiveTeamId) {
          // 自クラブの守備側決定機: 積極的にタックルに行くか、カバーリングに
          // 専念するかを選べる(相手の得点成功率が変わる)。
          final baseAgainst = _applyFinisherQuality(scoreProb, scorer);
          s.pending = PendingChanceDecision.defense(
            minute: minute,
            attacker: scorer!,
            aggressiveChanceAgainst:
                (baseAgainst * _aggressiveTackleReduction).clamp(0.0, 1.0),
            safeChanceAgainst: (baseAgainst * _coverSpaceReduction).clamp(
              0.0,
              1.0,
            ),
          );
          s.pendingIsHomeChance = isHomeChance;
          return; // ここで一時停止。再開はresolvePendingChanceから。
        }
        // 理論上どちらのチームもinteractiveTeamIdでない場合の安全策として、
        // 従来通りシュートとして即座に解決する。
        scoreProb = _applyFinisherQuality(scoreProb, scorer);
      }

      _finalizeChance(
        s,
        minute: minute,
        isHomeChance: isHomeChance,
        attackingTeam: attackingTeam,
        scorer: scorer,
        forcedAssist: forcedAssist,
        scoreProb: scoreProb,
        isPenalty: isPenalty,
        isDirectFreeKick: isDirectFreeKick,
      );
      s.chanceIndex++;
    }
  }

  /// [state.pending]をユーザーの選択([decision])に基づいて解決し、次の決定機
  /// (または半終了)まで進行を再開する。攻撃側の決定機でパスを選んでも
  /// つなげる味方がいない場合や、文脈に合わない選択(例えば守備側の決定機に
  /// シュートを渡した場合)は既定の安全な選択(シュート/カバーリング)に
  /// フォールバックする。この決定機の結果として実際に発生したイベント
  /// (得点・惜しいチャンス・積極的タックルによるカード)を返す。何も
  /// 起きなかった場合はnull。UI側の即時フィードバック表示に使う。
  static MatchEvent? resolvePendingChance(
    InteractiveHalfState state,
    ChanceDecision decision,
  ) {
    final pending = state.pending;
    if (pending == null) return null;
    final isHomeChance = state.pendingIsHomeChance!;
    final attackingTeam = isHomeChance ? state.home : state.away;
    final defendingTeam = isHomeChance ? state.away : state.home;
    final defendingLineup = isHomeChance ? state.awayLineup : state.homeLineup;

    state.pending = null;
    state.pendingIsHomeChance = null;

    MatchEvent? produced;
    if (pending.context == ChanceContext.attack) {
      Player finalScorer;
      Player? forcedAssist;
      double finalScoreProb;
      if (decision == ChanceDecision.pass && pending.passTarget != null) {
        finalScorer = pending.passTarget!;
        forcedAssist = pending.shooter;
        finalScoreProb = pending.passChance!;
      } else if (decision == ChanceDecision.longShot) {
        finalScorer = pending.shooter!;
        forcedAssist = null;
        finalScoreProb = pending.longShotChance!;
      } else {
        finalScorer = pending.shooter!;
        forcedAssist = null;
        finalScoreProb = pending.shootChance!;
      }
      produced = _finalizeChance(
        state,
        minute: pending.minute,
        isHomeChance: isHomeChance,
        attackingTeam: attackingTeam,
        scorer: finalScorer,
        forcedAssist: forcedAssist,
        scoreProb: finalScoreProb,
        isPenalty: false,
        isDirectFreeKick: false,
      );
    } else {
      // 守備側の決定機: attackerは相手チームの選手で、選んだ対応に応じた
      // 成功率でそのまま相手の攻撃を判定する。
      final aggressive = decision == ChanceDecision.aggressiveTackle;
      final finalScoreProb = aggressive
          ? pending.aggressiveChanceAgainst!
          : pending.safeChanceAgainst!;
      produced = _finalizeChance(
        state,
        minute: pending.minute,
        isHomeChance: isHomeChance,
        attackingTeam: attackingTeam,
        scorer: pending.attacker,
        forcedAssist: null,
        scoreProb: finalScoreProb,
        isPenalty: false,
        isDirectFreeKick: false,
      );
      if (aggressive && _rng.nextDouble() < _aggressiveTackleCardChance) {
        final tackler = _pickCardTarget(defendingLineup);
        if (tackler != null) {
          final isSecondYellow = tackler.yellowCardedThisHalf;
          final isRed = isSecondYellow || _rng.nextDouble() < 0.12;
          if (!isRed) tackler.yellowCardedThisHalf = true;
          final cardEvent = MatchEvent(
            minute: pending.minute,
            teamId: defendingTeam.id,
            scorerName: tackler.name,
            scorerId: tackler.id,
            type: isRed ? MatchEventType.redCard : MatchEventType.yellowCard,
          );
          state.events.add(cardEvent);
          if (isRed) {
            if (isHomeChance) {
              state.awayRedMinute = state.awayRedMinute == null
                  ? pending.minute
                  : min(state.awayRedMinute!, pending.minute);
            } else {
              state.homeRedMinute = state.homeRedMinute == null
                  ? pending.minute
                  : min(state.homeRedMinute!, pending.minute);
            }
          }
          // 得点が発生していなければ、カードをこの決定機の結果として扱う。
          produced ??= cardEvent;
        }
      }
    }

    state.lastDecisionEvent = produced;
    state.chanceIndex++;
    _advanceInteractiveHalf(state);
    return produced;
  }

  static MatchResult simulate({
    required Team home,
    required Team away,
    required int matchday,
    double homeInjuryFactor = 1.0,
    double awayInjuryFactor = 1.0,
    Weather weather = Weather.clear,
    double homeAdvantageFactor = 1.06,
  }) {
    _maybeAutoAssignManMarker(home, lineupOf(away));
    _maybeAutoAssignManMarker(away, lineupOf(home));
    final first = simulateMinutes(
      home: home,
      away: away,
      startMinute: 1,
      endMinute: 45,
      weather: weather,
      homeAdvantageFactor: homeAdvantageFactor,
    );
    applyHalfTimeFatigue(home: home, away: away, weather: weather);
    final second = simulateMinutes(
      home: home,
      away: away,
      startMinute: 46,
      endMinute: 90,
      weather: weather,
      homeAdvantageFactor: homeAdvantageFactor,
    );
    final allEvents = [...first.events, ...second.events];
    final homeGoals = first.homeGoals + second.homeGoals;
    final awayGoals = first.awayGoals + second.awayGoals;
    final homeShots = first.homeShots + second.homeShots;
    final awayShots = first.awayShots + second.awayShots;
    final homeShotsOnTarget =
        first.homeShotsOnTarget + second.homeShotsOnTarget;
    final awayShotsOnTarget =
        first.awayShotsOnTarget + second.awayShotsOnTarget;
    final totalChanceCount = first.chanceCount + second.chanceCount;
    final homePossession = totalChanceCount > 0
        ? ((first.possessionShareSum + second.possessionShareSum) /
                totalChanceCount *
                100)
            .round()
            .clamp(0, 100)
        : 50;
    final awayPossession = 100 - homePossession;
    // 採点は今節の出場停止・負傷が反映される前(=今節の出場者がまだ
    // lineupOfに残っている状態)で算出する必要があるため、
    // applyPostMatchEffectsより先に計算する。
    final ratings = computePlayerRatings(
      home: home,
      away: away,
      events: allEvents,
      homeGoals: homeGoals,
      awayGoals: awayGoals,
    );
    applyPostMatchEffects(
      home: home,
      away: away,
      homeInjuryFactor: homeInjuryFactor,
      awayInjuryFactor: awayInjuryFactor,
      events: allEvents,
      weather: weather,
    );

    return MatchResult(
      matchday: matchday,
      homeTeamId: home.id,
      awayTeamId: away.id,
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      events: allEvents,
      playerRatings: ratings,
      weather: weather,
      homePossession: homePossession,
      awayPossession: awayPossession,
      homeShots: homeShots,
      awayShots: awayShots,
      homeShotsOnTarget: homeShotsOnTarget,
      awayShotsOnTarget: awayShotsOnTarget,
    );
  }
}
