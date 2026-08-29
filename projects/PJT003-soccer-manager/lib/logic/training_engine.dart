import 'dart:math';

import '../models/attributes.dart';
import '../models/club_infrastructure.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/training_focus.dart';

export '../models/training_focus.dart';

class TrainingEngine {
  static final Random _rng = Random();

  /// メンターとして有効に扱える最低年齢。
  static const int minMentorAge = 28;

  /// 個別声かけ(GameState.talkToPlayer)のクールダウン週数。性格特性の
  /// 獲得判定([_rollPersonalityTraitAcquisition])が「監督が今週声をかけたか」
  /// を判定する際にも参照するため、ここで一元管理する。
  static const int talkCooldownWeeks = 3;

  /// チームの全選手にトレーニングを適用する。個別方針が設定されている選手は
  /// それを優先し、未設定の選手はチームの既定方針に従う。
  /// [headCoachLevel]は成長効率、[trainingGroundLevel]は成長効率と疲労回復を高める。
  /// [injuryFactor]はフィジオのレベルに応じた練習中の負傷リスク軽減係数。
  /// [careerGrowthBonus]は監督としての生涯成長(通算実績)に応じた成長効率の
  /// 追加倍率(1.0でボーナスなし)。
  static void applyWeeklyTraining(
    Team team, {
    int headCoachLevel = 1,
    int trainingGroundLevel = 1,
    int fitnessCoachLevel = 1,
    double injuryFactor = 1.0,
    double careerGrowthBonus = 1.0,
  }) {
    final growthMultiplier = ClubInfrastructure.trainingGrowthMultiplier(
          headCoachLevel,
          trainingGroundLevel,
        ) *
        careerGrowthBonus;
    final fatigueRecoveryBonus =
        ClubInfrastructure.fatigueRecoveryBonus(trainingGroundLevel) +
            ClubInfrastructure.fitnessCoachRecoveryBonus(fitnessCoachLevel);
    final byId = {for (final p in team.players) p.id: p};
    final mentorIdsUsed = <String>{};

    for (final p in team.players) {
      // 「才能開花」・特性獲得の発生有無は毎週リセットする(セーブデータには
      // 保存しない一時的なフラグ)。
      p.hadBreakthroughThisWeek = false;
      p.acquiredTraitThisWeek = null;
      final focus = _resolveFocus(p, team.defaultTrainingFocus);
      // ローン放出中の選手は貸出先で練習しているため、自クラブの施設・
      // スタッフによる成長ボーナスは適用しない。
      final isLoanedOut = p.isLoanedOut;
      final effectiveGrowthMultiplier = isLoanedOut ? 1.0 : growthMultiplier;
      final effectiveFatigueRecoveryBonus =
          isLoanedOut ? 0 : fatigueRecoveryBonus;

      final mentor = p.mentorId == null ? null : byId[p.mentorId];
      final validMentor =
          (mentor != null && mentor.id != p.id && mentor.age >= minMentorAge)
              ? mentor
              : null;
      if (validMentor != null) mentorIdsUsed.add(validMentor.id);

      _applyToPlayer(
        p,
        focus,
        effectiveGrowthMultiplier,
        effectiveFatigueRecoveryBonus,
        team.trainingIntensity,
        injuryFactor,
        validMentor != null,
      );
    }

    // 有効なメンターは指導のやりがいから士気が少し上がる。
    for (final id in mentorIdsUsed) {
      final mentor = byId[id];
      if (mentor != null) {
        mentor.happiness = (mentor.happiness + 1).clamp(0, 100);
      }
    }
  }

  /// この週に適用する方針を決める。[Player.focusRotation]が設定されて
  /// いれば個別方針より優先し、登録順に1週ごとへ切り替える(ローテーション
  /// が一巡したら最初に戻る)。未設定なら個別方針、それも未設定ならチームの
  /// 既定方針に従う(従来通り)。
  static TrainingFocus _resolveFocus(Player p, TrainingFocus teamDefault) {
    final rotation = p.focusRotation;
    if (rotation != null && rotation.isNotEmpty) {
      final index = p.rotationWeekIndex % rotation.length;
      final focus = rotation[index];
      p.rotationWeekIndex = (index + 1) % rotation.length;
      return focus;
    }
    return p.individualFocus ?? teamDefault;
  }

  static void _applyToPlayer(
    Player p,
    TrainingFocus focus,
    double growthMultiplier,
    int fatigueRecoveryBonus,
    TrainingIntensity intensity,
    double injuryFactor,
    bool hasMentor,
  ) {
    final intensityFactor = intensity.factor;
    final mentorBonus = hasMentor ? 1.2 : 1.0;
    final effectiveGrowth = growthMultiplier * intensityFactor * mentorBonus;

    switch (focus) {
      case TrainingFocus.attack:
        final primary = (p.position.group == PositionGroup.att ||
                p.position.group == PositionGroup.mid)
            ? 0.5
            : 0.15;
        for (final k in [
          AttributeKeys.finishing,
          AttributeKeys.longShots,
          AttributeKeys.dribbling,
          AttributeKeys.offTheBall,
        ]) {
          _grow(p, k, primary * effectiveGrowth);
        }
        for (final k in [
          AttributeKeys.passing,
          AttributeKeys.firstTouch,
          AttributeKeys.technique,
        ]) {
          _grow(p, k, 0.25 * effectiveGrowth);
        }
        p.fatigue = (p.fatigue + (12 * intensityFactor).round()).clamp(0, 100);
        break;
      case TrainingFocus.defense:
        if (p.position.group == PositionGroup.gk) {
          // GKはタックル/マーキングではなく、ゴールキーピング系の能力を伸ばす。
          for (final k in AttributeKeys.goalkeeping) {
            _grow(p, k, 0.5 * effectiveGrowth);
          }
        } else {
          final primary = p.position.group == PositionGroup.def ? 0.5 : 0.15;
          for (final k in [
            AttributeKeys.tackling,
            AttributeKeys.marking,
            AttributeKeys.positioning,
            AttributeKeys.anticipation,
          ]) {
            _grow(p, k, primary * effectiveGrowth);
          }
          for (final k in [
            AttributeKeys.passing,
            AttributeKeys.firstTouch,
            AttributeKeys.technique,
          ]) {
            _grow(p, k, 0.2 * effectiveGrowth);
          }
        }
        p.fatigue = (p.fatigue + (12 * intensityFactor).round()).clamp(0, 100);
        break;
      case TrainingFocus.fitness:
        for (final k in [
          AttributeKeys.stamina,
          AttributeKeys.naturalFitness,
          AttributeKeys.acceleration,
          AttributeKeys.strength,
        ]) {
          _grow(p, k, 0.45 * effectiveGrowth);
        }
        p.fatigue = (p.fatigue + (6 * intensityFactor).round()).clamp(0, 100);
        break;
      case TrainingFocus.positionSwitch:
        final targetName = p.trainingConvertTargetPosition;
        if (targetName != null) {
          // 明示的に指定した目標ポジションへ集中的にコンバートする。
          // 慣れ度が上限に達したら正式に副ポジションへ加え、目標は解除する。
          final target = Position.values.firstWhere(
            (v) => v.name == targetName,
            orElse: () => p.position,
          );
          if (target != p.position &&
              _rng.nextDouble() < (0.6 * effectiveGrowth).clamp(0, 1)) {
            p.growFamiliarity(target, amount: 3);
          }
          if (p.familiarityFor(target) >= 100 &&
              !p.secondaryPositions.contains(target)) {
            p.secondaryPositions = [...p.secondaryPositions, target];
            p.trainingConvertTargetPosition = null;
          }
        } else {
          for (final pos in p.secondaryPositions) {
            if (_rng.nextDouble() < (0.5 * effectiveGrowth).clamp(0, 1)) {
              p.growFamiliarity(pos, amount: 2);
            }
          }
        }
        p.fatigue = (p.fatigue + (8 * intensityFactor).round()).clamp(0, 100);
        break;
      case TrainingFocus.rest:
        p.fatigue = (p.fatigue - 30 - fatigueRecoveryBonus).clamp(0, 100);
        p.morale = (p.morale + 8).clamp(0, 100);
        break;
    }

    // ピンポイント特訓ドリル: フォーカスとは無関係に指定した属性を追加で伸ばす。
    // 2つ目のドリルは同時に2項目を欲張る分、成長率を1つ目より抑える。
    if (p.drillAttributeKey != null) {
      _grow(p, p.drillAttributeKey!, 0.35 * growthMultiplier * intensityFactor);
    }
    if (p.drillAttributeKey2 != null) {
      _grow(p, p.drillAttributeKey2!, 0.2 * growthMultiplier * intensityFactor);
    }

    // 特性トレーニング: 未保有の選手のみ、狙った技術特性を低確率で獲得する。
    if (p.trait == null && p.traitTrainingTarget != null) {
      _rollTraitAcquisition(p, p.traitTrainingTarget!, effectiveGrowth);
    }

    // 性格特性の習得: 練習ではなく、メンター(チームメイト)や監督の
    // 個別声かけを通じて、未保有の選手が狙った性格特性を低確率で獲得する。
    if (p.trait == null && p.personalityTraitTrainingTarget != null) {
      final talkedThisWeek = p.talkCooldownWeeks == talkCooldownWeeks;
      _rollPersonalityTraitAcquisition(
        p,
        p.personalityTraitTrainingTarget!,
        hasMentor,
        talkedThisWeek,
      );
    }

    p.fatigue = (p.fatigue - 5 - fatigueRecoveryBonus ~/ 2).clamp(0, 100);

    if (focus != TrainingFocus.rest) {
      _rollTrainingInjury(p, intensityFactor, injuryFactor);
      _rollBreakthrough(p, focus, effectiveGrowth);
    }

    if (p.age >= _declineStartAge(p.growthType) &&
        _rng.nextDouble() < _declineChance(p.growthType)) {
      _decline(p);
    }
  }

  /// 高強度の練習メニューによる軽度の負傷判定。基礎体力(naturalFitness)が
  /// 高い選手ほど負傷しにくい。試合中の負傷より短期で済む(1〜2週)。
  static void _rollTrainingInjury(
    Player p,
    double intensityFactor,
    double injuryFactor,
  ) {
    final naturalFitnessFactor =
        (1 - (p.attributeValue(AttributeKeys.naturalFitness) - 50) / 200).clamp(
      0.5,
      1.5,
    );
    final chance = (0.01 + p.fatigue / 100 * 0.015) *
        intensityFactor *
        naturalFitnessFactor *
        injuryFactor;
    if (_rng.nextDouble() < chance) {
      p.injuryWeeks = (p.injuryWeeks + 1 + _rng.nextInt(2)).clamp(1, 3);
      p.injuryType = InjuryType.muscle;
      p.injuryHistoryCounts[InjuryType.muscle.name] =
          (p.injuryHistoryCounts[InjuryType.muscle.name] ?? 0) + 1;
    }
  }

  /// 出場経験を通じたメンタル系能力の成長。試合に出場した選手に対して
  /// [MatchEngine.applyPostMatchEffects]から呼ばれ、判断力・冷静さ・視野・
  /// 予測・リーダーシップのいずれか1項目をわずかな確率で伸ばす。
  static const List<String> matchExperienceGrowthKeys = [
    AttributeKeys.composure,
    AttributeKeys.decisions,
    AttributeKeys.vision,
    AttributeKeys.anticipation,
    AttributeKeys.leadership,
  ];

  static void growFromMatchExperience(Player p) {
    final key = matchExperienceGrowthKeys[_rng.nextInt(
      matchExperienceGrowthKeys.length,
    )];
    _grow(p, key, 0.06);
  }

  /// 戦術ミーティングによる、スカッド全体のメンタル面(判断力・位置取り・
  /// チームワーク)への小さな底上げ。個別方針とは別枠のクールダウン制コマンド
  /// として扱う(呼び出し側がクールダウンを管理する)。
  static void applyTacticalMeeting(List<Player> players) {
    for (final p in players) {
      _grow(p, AttributeKeys.decisions, 0.35);
      _grow(p, AttributeKeys.positioning, 0.35);
      _grow(p, AttributeKeys.teamwork, 0.35);
    }
  }

  /// CPUクラブ向けの簡易的な週次成長。個別方針・メンター・ドリルといった
  /// ユーザー専用の仕組みは適用しないが、何もしないとユーザーだけが
  /// 育成システムで伸び続け、CPUの相対的な強さが何シーズンも停滞して
  /// しまう(=対戦相手として意味を失う)ため、ポジションに応じた基本成長を
  /// 通常のトレーニングより控えめな確率で与える。高齢選手の衰えも
  /// applyWeeklyTrainingと同様に適用する。
  static const double passiveGrowthFactor = 0.4;

  static void applyPassiveCpuGrowth(Team team) {
    for (final p in team.players) {
      if (p.isLoanedOut) continue;
      if (p.position.group == PositionGroup.gk) {
        for (final k in AttributeKeys.goalkeeping) {
          _grow(p, k, 0.5 * passiveGrowthFactor);
        }
      } else if (p.position.group == PositionGroup.def) {
        for (final k in [
          AttributeKeys.tackling,
          AttributeKeys.marking,
          AttributeKeys.positioning,
          AttributeKeys.anticipation,
        ]) {
          _grow(p, k, 0.5 * passiveGrowthFactor);
        }
      } else {
        for (final k in [
          AttributeKeys.finishing,
          AttributeKeys.longShots,
          AttributeKeys.dribbling,
          AttributeKeys.offTheBall,
        ]) {
          _grow(p, k, 0.5 * passiveGrowthFactor);
        }
      }
      if (p.age >= _declineStartAge(p.growthType) &&
          _rng.nextDouble() < _declineChance(p.growthType)) {
        _decline(p);
      }
    }
  }

  /// ユース施設のレベルに応じた昇格候補(有望株)の週次成長係数。
  /// レベルが高いほど、昇格を焦らずじっくり育てる価値が生まれる。
  static double youthAcademyGrowthFactor(int facilityLevel) =>
      0.5 + facilityLevel * 0.2;

  /// ユース昇格候補の育成方針([Player.individualFocus])に応じて伸ばす
  /// 属性群を返す。GKは方針によらずゴールキーピング系を伸ばす。方針が
  /// 未設定(null)・休養・ポジションコンバートの場合は、従来通り
  /// ポジション別の既定の属性群にフォールバックする。
  static List<String> _youthGrowthKeysFor(Player p) {
    if (p.position.group == PositionGroup.gk) {
      return AttributeKeys.goalkeeping;
    }
    switch (p.individualFocus) {
      case TrainingFocus.attack:
        return const [
          AttributeKeys.finishing,
          AttributeKeys.longShots,
          AttributeKeys.dribbling,
          AttributeKeys.offTheBall,
        ];
      case TrainingFocus.defense:
        return const [
          AttributeKeys.tackling,
          AttributeKeys.marking,
          AttributeKeys.positioning,
          AttributeKeys.anticipation,
        ];
      case TrainingFocus.fitness:
        return const [
          AttributeKeys.stamina,
          AttributeKeys.naturalFitness,
          AttributeKeys.acceleration,
          AttributeKeys.strength,
        ];
      case TrainingFocus.positionSwitch:
      case TrainingFocus.rest:
      case null:
        return p.position.group == PositionGroup.def
            ? const [
                AttributeKeys.tackling,
                AttributeKeys.marking,
                AttributeKeys.positioning,
                AttributeKeys.anticipation,
              ]
            : const [
                AttributeKeys.finishing,
                AttributeKeys.longShots,
                AttributeKeys.dribbling,
                AttributeKeys.offTheBall,
              ];
    }
  }

  /// スカウトした昇格候補は、昇格させるまでユース施設で育成され続ける。
  /// 実戦がない分CPUの週次成長よりは緩やかだが、ユース施設のレベルが
  /// 高いほど伸びが早く、昇格のタイミングを見極めるゲーム性が生まれる。
  /// [Player.individualFocus]を設定した選手は、その方針に沿った属性群が
  /// 優先的に伸びる(第一チームのトレーニング方針と同じ仕組みを流用)。
  static void applyYouthAcademyGrowth(
    List<Player> prospects,
    int facilityLevel,
  ) {
    final factor = youthAcademyGrowthFactor(facilityLevel);
    for (final p in prospects) {
      for (final k in _youthGrowthKeysFor(p)) {
        _grow(p, k, 0.5 * factor);
      }
    }
  }

  /// 成長タイプ(早熟/標準/大器晩成)に応じて衰えが始まる年齢。
  static int _declineStartAge(PlayerGrowthType type) => switch (type) {
        PlayerGrowthType.early => 28,
        PlayerGrowthType.balanced => 31,
        PlayerGrowthType.late => 34,
      };

  /// 衰え開始年齢に達した後、週次で実際に衰えが発生する確率。
  static double _declineChance(PlayerGrowthType type) => switch (type) {
        PlayerGrowthType.early => 0.12,
        PlayerGrowthType.balanced => 0.1,
        PlayerGrowthType.late => 0.08,
      };

  /// 成長タイプ・年齢に応じた伸びやすさの倍率。早熟は10代後半〜20代前半で
  /// 大きく伸びる代わりに20代後半以降は急速に伸び悩み、大器晩成はその逆に
  /// 若いうちの伸びは控えめだが20代後半〜30代前半まで高い伸びしろを保つ。
  static double _growthAgeFactor(Player p) {
    final age = p.age;
    switch (p.growthType) {
      case PlayerGrowthType.early:
        if (age <= 21) return 1.3;
        if (age <= 27) return 1.0;
        if (age <= 30) return 0.6;
        return 0.3;
      case PlayerGrowthType.balanced:
        if (age <= 27) return 1.0;
        if (age <= 30) return 0.8;
        return 0.4;
      case PlayerGrowthType.late:
        if (age <= 21) return 0.7;
        if (age <= 27) return 1.0;
        if (age <= 32) return 1.15;
        return 0.6;
    }
  }

  /// 「才能開花」(ブレイクスルー)が発生する基本確率。地道な毎週の成長
  /// ([_grow])とは別に、まれに複数の能力値が一気に伸びる特別な瞬間を
  /// 用意することで、育成の手応え・驚きを演出する。
  static const double _breakthroughBaseChance = 0.015;

  /// ブレイクスルー確率に対する、成長タイプ・年齢による倍率。早熟は若い
  /// うちに、大器晩成はより長い期間にわたって開花が起きやすい。
  static double _breakthroughAgeFactor(Player p) {
    final age = p.age;
    switch (p.growthType) {
      case PlayerGrowthType.early:
        if (age <= 23) return 1.5;
        if (age <= 27) return 0.8;
        return 0.2;
      case PlayerGrowthType.balanced:
        if (age <= 26) return 1.2;
        if (age <= 29) return 0.7;
        return 0.2;
      case PlayerGrowthType.late:
        if (age <= 24) return 0.6;
        if (age <= 30) return 1.4;
        return 0.5;
    }
  }

  /// フォーカス・ポジションに応じて、ブレイクスルーで伸ばす能力値の候補群を
  /// 返す。実際に取り組んでいる練習内容と無関係な能力が伸びると不自然な
  /// ため、通常成長([_applyToPlayer]の各focus分岐)と同じ属性群を使う。
  static List<String> _breakthroughPoolFor(Player p, TrainingFocus focus) {
    if (p.position.group == PositionGroup.gk) {
      return AttributeKeys.goalkeeping;
    }
    switch (focus) {
      case TrainingFocus.attack:
        return const [
          AttributeKeys.finishing,
          AttributeKeys.longShots,
          AttributeKeys.dribbling,
          AttributeKeys.offTheBall,
          AttributeKeys.technique,
        ];
      case TrainingFocus.defense:
        return const [
          AttributeKeys.tackling,
          AttributeKeys.marking,
          AttributeKeys.positioning,
          AttributeKeys.anticipation,
        ];
      case TrainingFocus.fitness:
        return const [
          AttributeKeys.stamina,
          AttributeKeys.naturalFitness,
          AttributeKeys.acceleration,
          AttributeKeys.strength,
        ];
      case TrainingFocus.positionSwitch:
      case TrainingFocus.rest:
        return p.position.group == PositionGroup.def
            ? const [
                AttributeKeys.tackling,
                AttributeKeys.marking,
                AttributeKeys.positioning,
                AttributeKeys.anticipation,
              ]
            : const [
                AttributeKeys.finishing,
                AttributeKeys.longShots,
                AttributeKeys.dribbling,
                AttributeKeys.offTheBall,
              ];
    }
  }

  /// 才能開花イベントの判定。発生すると、フォーカスに応じた能力値群のうち
  /// 2〜4個がまとめて+2〜4伸びる(ポテンシャル上限まで)。通常の地道な成長
  /// とは独立して判定される特別なボーナスで、[Player.hadBreakthroughThisWeek]
  /// に反映してUI側で「才能開花」として強調表示できるようにする。
  static void _rollBreakthrough(
    Player p,
    TrainingFocus focus,
    double effectiveGrowth,
  ) {
    var chance = _breakthroughBaseChance *
        _breakthroughAgeFactor(p) *
        effectiveGrowth.clamp(0.4, 2.5);
    chance *= 0.7 + p.attributeValue(AttributeKeys.determination) / 165;
    if (_rng.nextDouble() >= chance) return;

    final pool = _breakthroughPoolFor(p, focus);
    final shuffled = [...pool]..shuffle(_rng);
    final count = min(2 + _rng.nextInt(3), shuffled.length);
    for (var i = 0; i < count; i++) {
      final key = shuffled[i];
      final current = p.attributeValue(key);
      final boost = 2 + _rng.nextInt(3);
      p.setAttributeValue(key, (current + boost).clamp(1, p.potential));
    }
    p.hadBreakthroughThisWeek = true;
  }

  /// 特性未保有の選手が、狙った技術特性([target])を専用の特訓によって
  /// 獲得するかどうかの判定。闘志が高く成長に前向きな性格の選手ほど、また
  /// [traitSuitability]が高い(=その特性に元々向いている)選手ほど獲得しやすい。
  /// 獲得すると[Player.acquiredTraitThisWeek]に反映してUI側で通知できるようにする。
  /// [target]が技術カテゴリでない場合は何もしない(古いセーブデータ等に
  /// 由来する不整合な指定に対する保険)。
  static const double _traitAcquisitionBaseChance = 0.02;

  static void _rollTraitAcquisition(
    Player p,
    PlayerTrait target,
    double effectiveGrowth,
  ) {
    if (target.category != PlayerTraitCategory.technical) return;
    final chance = (_traitAcquisitionBaseChance * effectiveGrowth) *
        (0.7 + p.attributeValue(AttributeKeys.determination) / 165) *
        p.personality.growthFactor *
        traitSuitability(p, target);
    if (_rng.nextDouble() >= chance.clamp(0, 1)) return;
    p.trait = target;
    p.acquiredTraitThisWeek = target;
  }

  /// 特性未保有の選手が、狙った性格特性([target])をメンター(チームメイト)
  /// や監督の個別声かけを通じて獲得するかどうかの判定。技術特性の特訓とは
  /// 異なり練習の強度・成長効率には依存せず、有効なメンターがいるか
  /// ([hasMentor])・監督が今週声をかけたか([talkedThisWeek])のいずれかを
  /// 満たした週にのみ判定を行う(いずれも満たさない週は何も起きない)。
  /// [target]が性格カテゴリでない場合も何もしない。
  static const double _personalityTraitAcquisitionBaseChance = 0.02;

  static void _rollPersonalityTraitAcquisition(
    Player p,
    PlayerTrait target,
    bool hasMentor,
    bool talkedThisWeek,
  ) {
    if (target.category != PlayerTraitCategory.personality) return;
    if (!hasMentor && !talkedThisWeek) return;
    final chance = _personalityTraitAcquisitionBaseChance *
        (hasMentor ? 1.5 : 1.0) *
        (talkedThisWeek ? 1.3 : 1.0) *
        p.personality.growthFactor *
        traitSuitability(p, target);
    if (_rng.nextDouble() >= chance.clamp(0, 1)) return;
    p.trait = target;
    p.acquiredTraitThisWeek = target;
  }

  /// 選手特性ごとに対応する属性キー(能力値ベースで適性を判定する特性のみ)。
  static const Map<PlayerTrait, String> _traitAttributeKeys = {
    PlayerTrait.warriorSpirit: AttributeKeys.determination,
    PlayerTrait.calmHead: AttributeKeys.composure,
    PlayerTrait.leaderOnPitch: AttributeKeys.leadership,
    PlayerTrait.visionary: AttributeKeys.vision,
    PlayerTrait.paceMerchant: AttributeKeys.pace,
    PlayerTrait.powerhouse: AttributeKeys.strength,
    PlayerTrait.enginesRunning: AttributeKeys.stamina,
    PlayerTrait.silkyDribbler: AttributeKeys.dribbling,
    PlayerTrait.playmakerTrait: AttributeKeys.passing,
    PlayerTrait.ballWinner: AttributeKeys.tackling,
    PlayerTrait.shadowMarker: AttributeKeys.marking,
    PlayerTrait.clinicalFinisher: AttributeKeys.finishing,
    PlayerTrait.distanceShooter: AttributeKeys.longShots,
    PlayerTrait.aerialThreat: AttributeKeys.jumpingReach,
    PlayerTrait.showman: AttributeKeys.flair,
    PlayerTrait.sureTouch: AttributeKeys.firstTouch,
    PlayerTrait.crossSpecialist: AttributeKeys.crossing,
    PlayerTrait.setPieceMaestro: AttributeKeys.freeKick,
    PlayerTrait.clockwork: AttributeKeys.anticipation,
    PlayerTrait.decisiveMind: AttributeKeys.decisions,
    PlayerTrait.teamPlayer: AttributeKeys.teamwork,
    PlayerTrait.tirelessRunner: AttributeKeys.workRate,
    PlayerTrait.explosiveStart: AttributeKeys.acceleration,
    PlayerTrait.fearlessDefender: AttributeKeys.bravery,
  };

  /// 選手が[trait]の特訓にどれだけ向いているかを表す倍率(特訓成功率に乗算)。
  /// 対応する能力値・年齢が特性の発動条件に近い選手ほど高くなる
  /// (概ね0.3〜1.6の範囲)。対戦相手や天候・試合当日のコンディションに
  /// 依存する特性(判官びいき・天候系・波がある、等)は個人の資質だけでは
  /// 適性を判断できないため中立(1.0)を返す。
  static double traitSuitability(Player p, PlayerTrait trait) {
    final attrKey = _traitAttributeKeys[trait];
    if (attrKey != null) {
      final value = p.attributeValue(attrKey);
      return (0.5 + value / 100).clamp(0.3, 1.6);
    }
    switch (trait) {
      case PlayerTrait.wonderkid:
        return p.age <= 21
            ? 1.5
            : p.age <= 24
                ? 1.0
                : 0.3;
      case PlayerTrait.oldHead:
        return p.age >= 32
            ? 1.5
            : p.age >= 28
                ? 1.0
                : 0.3;
      case PlayerTrait.primeTime:
        return (p.age >= 26 && p.age <= 29) ? 1.5 : 0.7;
      default:
        return 1.0;
    }
  }

  static void _grow(Player p, String key, double chance) {
    final current = p.attributeValue(key);
    if (current >= p.potential) return;
    var c = chance * _growthAgeFactor(p);
    // 闘志(determination)が高い選手ほど伸びやすく、低い選手は伸びにくい。
    c *= 0.7 + p.attributeValue(AttributeKeys.determination) / 165;
    // 性格によって自主練習への取り組み方が異なり、成長効率に差が出る。
    c *= p.personality.growthFactor;
    // 出場機会が乏しく実戦感覚(マッチシャープネス)が低い選手は伸び悩む。
    if (p.matchSharpness < 40) c *= 0.7;
    // ポテンシャルに近づくほど伸びしろが少なくなり、成長は緩やかになる
    // (残り10未満から徐々に減衰する。それまでは全く減衰しない)。
    final gapToPotential = p.potential - current;
    if (gapToPotential < 10) {
      c *= (0.2 + 0.8 * gapToPotential / 10).clamp(0.2, 1.0);
    }
    if (_rng.nextDouble() > c) return;
    p.setAttributeValue(key, (current + 1).clamp(1, p.potential));
  }

  static void _decline(Player p) {
    final candidates = _declineCandidates(p);
    final key = candidates[_rng.nextInt(candidates.length)];
    final current = p.attributeValue(key);
    p.setAttributeValue(key, (current - 1).clamp(20, 99));
  }

  /// ポジションごとに衰えやすい能力値グループを重み付けした候補リストを返す。
  /// GKはGK系・フィジカル系、それ以外はフィジカル系(スピード・跳躍力等)が
  /// 優先的に(重複を増やして)選ばれやすくなる。
  static List<String> _declineCandidates(Player p) {
    const physicalHeavy = [
      AttributeKeys.pace,
      AttributeKeys.acceleration,
      AttributeKeys.agility,
      AttributeKeys.jumpingReach,
      AttributeKeys.stamina,
    ];
    if (p.position.group == PositionGroup.gk) {
      return [
        ...AttributeKeys.all,
        ...AttributeKeys.goalkeeping,
        ...AttributeKeys.goalkeeping,
        ...physicalHeavy,
      ];
    }
    return [...AttributeKeys.all, ...physicalHeavy, ...physicalHeavy];
  }
}
