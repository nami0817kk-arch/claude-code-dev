import 'dart:math';

import '../models/attributes.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../data/name_pool.dart';
import 'training_engine.dart';

class PlayerGenerator {
  static final Random _rng = Random();
  static int _idCounter = 0;
  static final RegExp _idPattern = RegExp(r'^pl(\d+)$');

  /// ロード直後に呼び出し、既存セーブ内の選手IDと衝突しないよう
  /// カウンターを引き上げる(プロセス再起動でカウンターが0に戻ると、
  /// 新規生成した選手が既存選手と同じIDを持ってしまうため)。
  static void ensureIdCounterAbove(Iterable<String> existingIds) {
    for (final id in existingIds) {
      final match = _idPattern.firstMatch(id);
      if (match == null) continue;
      final n = int.tryParse(match.group(1)!);
      if (n != null && n >= _idCounter) _idCounter = n + 1;
    }
  }

  static const _gkStrong = {
    AttributeKeys.handling,
    AttributeKeys.reflexes,
    AttributeKeys.commandOfArea,
    AttributeKeys.aerialReach,
    AttributeKeys.kicking,
    AttributeKeys.oneOnOnes,
  };
  static const _gkWeakOutfield = {
    AttributeKeys.finishing,
    AttributeKeys.longShots,
    AttributeKeys.dribbling,
    AttributeKeys.crossing,
    AttributeKeys.pace,
    AttributeKeys.acceleration,
  };
  static const _gkModestDefensive = {
    AttributeKeys.tackling,
    AttributeKeys.marking,
    AttributeKeys.positioning,
    AttributeKeys.anticipation,
    AttributeKeys.concentration,
  };

  static const Map<Position, Set<String>> _strongByPosition = {
    Position.dc: {
      AttributeKeys.tackling,
      AttributeKeys.marking,
      AttributeKeys.positioning,
      AttributeKeys.strength,
      AttributeKeys.heading,
      AttributeKeys.aggression,
      AttributeKeys.anticipation,
      AttributeKeys.bravery,
    },
    Position.dr: {
      AttributeKeys.tackling,
      AttributeKeys.marking,
      AttributeKeys.crossing,
      AttributeKeys.pace,
      AttributeKeys.acceleration,
      AttributeKeys.stamina,
      AttributeKeys.workRate,
      AttributeKeys.positioning,
    },
    Position.dl: {
      AttributeKeys.tackling,
      AttributeKeys.marking,
      AttributeKeys.crossing,
      AttributeKeys.pace,
      AttributeKeys.acceleration,
      AttributeKeys.stamina,
      AttributeKeys.workRate,
      AttributeKeys.positioning,
    },
    Position.wbr: {
      AttributeKeys.crossing,
      AttributeKeys.pace,
      AttributeKeys.acceleration,
      AttributeKeys.stamina,
      AttributeKeys.workRate,
      AttributeKeys.dribbling,
      AttributeKeys.tackling,
    },
    Position.wbl: {
      AttributeKeys.crossing,
      AttributeKeys.pace,
      AttributeKeys.acceleration,
      AttributeKeys.stamina,
      AttributeKeys.workRate,
      AttributeKeys.dribbling,
      AttributeKeys.tackling,
    },
    Position.dm: {
      AttributeKeys.tackling,
      AttributeKeys.marking,
      AttributeKeys.positioning,
      AttributeKeys.passing,
      AttributeKeys.anticipation,
      AttributeKeys.workRate,
      AttributeKeys.teamwork,
      AttributeKeys.decisions,
    },
    Position.mr: {
      AttributeKeys.passing,
      AttributeKeys.crossing,
      AttributeKeys.dribbling,
      AttributeKeys.pace,
      AttributeKeys.stamina,
      AttributeKeys.workRate,
      AttributeKeys.technique,
      AttributeKeys.firstTouch,
    },
    Position.ml: {
      AttributeKeys.passing,
      AttributeKeys.crossing,
      AttributeKeys.dribbling,
      AttributeKeys.pace,
      AttributeKeys.stamina,
      AttributeKeys.workRate,
      AttributeKeys.technique,
      AttributeKeys.firstTouch,
    },
    Position.mc: {
      AttributeKeys.passing,
      AttributeKeys.vision,
      AttributeKeys.firstTouch,
      AttributeKeys.technique,
      AttributeKeys.decisions,
      AttributeKeys.stamina,
      AttributeKeys.workRate,
      AttributeKeys.teamwork,
    },
    Position.amr: {
      AttributeKeys.dribbling,
      AttributeKeys.pace,
      AttributeKeys.crossing,
      AttributeKeys.finishing,
      AttributeKeys.flair,
      AttributeKeys.offTheBall,
      AttributeKeys.technique,
      AttributeKeys.acceleration,
    },
    Position.aml: {
      AttributeKeys.dribbling,
      AttributeKeys.pace,
      AttributeKeys.crossing,
      AttributeKeys.finishing,
      AttributeKeys.flair,
      AttributeKeys.offTheBall,
      AttributeKeys.technique,
      AttributeKeys.acceleration,
    },
    Position.amc: {
      AttributeKeys.passing,
      AttributeKeys.vision,
      AttributeKeys.technique,
      AttributeKeys.decisions,
      AttributeKeys.flair,
      AttributeKeys.finishing,
      AttributeKeys.offTheBall,
      AttributeKeys.composure,
    },
    Position.st: {
      AttributeKeys.finishing,
      AttributeKeys.longShots,
      AttributeKeys.offTheBall,
      AttributeKeys.composure,
      AttributeKeys.pace,
      AttributeKeys.acceleration,
      AttributeKeys.flair,
      AttributeKeys.heading,
    },
  };

  static const Map<Position, Set<String>> _weakByPosition = {
    Position.dc: {
      AttributeKeys.dribbling,
      AttributeKeys.finishing,
      AttributeKeys.longShots,
      AttributeKeys.crossing,
      AttributeKeys.flair,
    },
    Position.dr: {AttributeKeys.finishing, AttributeKeys.heading},
    Position.dl: {AttributeKeys.finishing, AttributeKeys.heading},
    Position.wbr: {AttributeKeys.marking, AttributeKeys.heading},
    Position.wbl: {AttributeKeys.marking, AttributeKeys.heading},
    Position.dm: {AttributeKeys.finishing, AttributeKeys.flair},
    Position.mr: {AttributeKeys.tackling, AttributeKeys.heading},
    Position.ml: {AttributeKeys.tackling, AttributeKeys.heading},
    Position.mc: {AttributeKeys.finishing, AttributeKeys.pace},
    Position.amr: {
      AttributeKeys.tackling,
      AttributeKeys.marking,
      AttributeKeys.strength,
    },
    Position.aml: {
      AttributeKeys.tackling,
      AttributeKeys.marking,
      AttributeKeys.strength,
    },
    Position.amc: {
      AttributeKeys.tackling,
      AttributeKeys.marking,
      AttributeKeys.strength,
    },
    Position.st: {
      AttributeKeys.tackling,
      AttributeKeys.marking,
      AttributeKeys.passing,
    },
  };

  static const Map<Position, List<Position>> _secondaryCandidates = {
    Position.gk: [],
    Position.dr: [Position.wbr, Position.dc],
    Position.dc: [Position.dm],
    Position.dl: [Position.wbl, Position.dc],
    Position.wbr: [Position.dr, Position.mr],
    Position.wbl: [Position.dl, Position.ml],
    Position.dm: [Position.dc, Position.mc],
    Position.mr: [Position.wbr, Position.amr],
    Position.mc: [Position.dm, Position.amc],
    Position.ml: [Position.wbl, Position.aml],
    Position.amr: [Position.mr, Position.st],
    Position.amc: [Position.mc, Position.amr, Position.aml],
    Position.aml: [Position.ml, Position.st],
    Position.st: [Position.amc],
  };

  static AttributeCategory _categoryOfKey(String key) {
    if (AttributeKeys.technical.contains(key)) {
      return AttributeCategory.technical;
    }
    if (AttributeKeys.mental.contains(key)) return AttributeCategory.mental;
    if (AttributeKeys.physical.contains(key)) return AttributeCategory.physical;
    return AttributeCategory.goalkeeping;
  }

  static int _positionBonus(String key, Position position) {
    if (position == Position.gk) {
      if (_gkStrong.contains(key)) return 25;
      if (_gkModestDefensive.contains(key)) return 5;
      if (_gkWeakOutfield.contains(key)) return -20;
      return -5;
    }
    if (AttributeKeys.goalkeeping.contains(key)) return -40;
    final strong = _strongByPosition[position] ?? const {};
    if (strong.contains(key)) return 15;
    final weak = _weakByPosition[position] ?? const {};
    if (weak.contains(key)) return -9;
    return 0;
  }

  /// 指定ポジションの選手が、現実的に無理なくこなせるようになりうる
  /// 副ポジションの候補一覧(ポジションコンバート特訓の対象選択にも使う)。
  static List<Position> secondaryCandidatesFor(Position position) =>
      _secondaryCandidates[position] ?? const [];

  static List<Position> _generateSecondaryPositions(Position position) {
    final candidates = _secondaryCandidates[position] ?? const [];
    if (candidates.isEmpty) return [];
    final roll = _rng.nextDouble();
    if (roll < 0.35) return [];
    final shuffled = [...candidates]..shuffle(_rng);
    final count = roll < 0.85 ? 1 : min(2, shuffled.length);
    return shuffled.take(count).toList();
  }

  static Player generate({
    required Position position,
    required int strengthTier,
    int? ageOverride,
  }) {
    final id = 'pl${_idCounter++}';
    final age = ageOverride ?? (17 + _rng.nextInt(18));
    final potential = (strengthTier + _rng.nextInt(21) - 10).clamp(40, 99);

    double ageFactor;
    if (age < 24) {
      ageFactor = 0.55 + (age - 17) * 0.045;
    } else if (age <= 29) {
      ageFactor = 0.9 + _rng.nextDouble() * 0.1;
    } else {
      ageFactor = (0.95 - (age - 29) * 0.03);
    }
    final baseAbility = (potential * ageFactor).round().clamp(25, 99);

    // カテゴリ(技術/メンタル/フィジカル/GK)ごとに共通のバイアスを1回だけ
    // ロールする。個々の属性を完全に独立乱数にすると「技術は高いのに
    // メンタルは低い」といった一貫性のない選手ばかりになるため、同じ
    // カテゴリの属性はある程度連動して高め/低めに振れるようにし、
    // 「技術系がまとまって高い選手」「フィジカルが弱い選手」のような
    // 一貫した個性が出るようにする。
    final categoryBias = {
      for (final category in AttributeCategory.values)
        category: _rng.nextInt(9) - 4, // -4 〜 +4
    };

    final attributes = <String, int>{};
    for (final key in AttributeKeys.all) {
      final variance = _rng.nextInt(11) - 5; // -5 〜 +5(カテゴリバイアス分、個別ノイズは縮小)
      final bias = categoryBias[_categoryOfKey(key)]!;
      final value =
          baseAbility + _positionBonus(key, position) + bias + variance;
      // ポテンシャルは成長の上限のはずなので、生成直後の能力値がそれを
      // 超えてしまわないようにする(ポジションボーナス・分散を足した後の
      // 値がpotentialを上回るケースがあったため)。
      attributes[key] = value.clamp(1, min(99, potential));
    }

    final player = Player(
      id: id,
      name: NamePool.randomPlayerName(),
      age: age,
      position: position,
      secondaryPositions: _generateSecondaryPositions(position),
      attributes: attributes,
      potential: potential,
      fatigue: _rng.nextInt(15),
      morale: 65 + _rng.nextInt(25),
      personality: _pickPersonality(),
      happiness: 55 + _rng.nextInt(30),
    );
    player.wage = (player.marketValue / 40).round().clamp(5, 500);
    player.contractYearsRemaining = 1 + _rng.nextInt(4);
    player.role = _pickRole(player);
    player.duty = _pickDuty(player);
    player.trait = _pickTraitFor(player);
    player.growthType = _pickGrowthType();
    return player;
  }

  /// 性格の出現重み。かつては全20種類から一様に抽選していたため、
  /// 「模範選手」や「クラブの伝説肌」のような極端に恵まれた/珍しい気質が
  /// ごく普通の気質と同じ頻度で現れていた。中庸な性格を厚く、効果の
  /// 極端な性格(良くも悪くも)を薄くすることで、珍しい性格の選手に
  /// 出会えたときの特別感を生む。
  static const Map<PlayerPersonality, int> _personalityWeights = {
    PlayerPersonality.balanced: 3,
    PlayerPersonality.fairlyProfessional: 3,
    PlayerPersonality.spirited: 3,
    PlayerPersonality.resolute: 3,
    PlayerPersonality.professional: 2,
    PlayerPersonality.loyal: 2,
    PlayerPersonality.ambitious: 2,
    PlayerPersonality.determined: 2,
    PlayerPersonality.driven: 2,
    PlayerPersonality.laidBack: 2,
    PlayerPersonality.perfectionist: 2,
    PlayerPersonality.temperamental: 2,
    PlayerPersonality.unambitious: 2,
    PlayerPersonality.easilyDiscouraged: 2,
    PlayerPersonality.modelCitizen: 1,
    PlayerPersonality.veryAmbitious: 1,
    PlayerPersonality.mercenary: 1,
    PlayerPersonality.volatile: 1,
    PlayerPersonality.lowDetermination: 1,
    PlayerPersonality.clubLegendType: 1,
  };

  static PlayerPersonality _pickPersonality() {
    final total = _personalityWeights.values.fold<int>(0, (s, w) => s + w);
    var pick = _rng.nextInt(total);
    for (final entry in _personalityWeights.entries) {
      pick -= entry.value;
      if (pick < 0) return entry.key;
    }
    return PlayerPersonality.balanced;
  }

  /// 選手特性(PlayerTrait、全54種類)のいずれかを一定確率で割り当てる。
  /// 能力値が近い選手同士でも試合結果に差が出るようにするための要素で、
  /// 持たない選手の方が多い。
  ///
  /// かつては全特性から一様に抽選していたため、「フィールドプレーヤーに
  /// GKの反応速度依存の特性」「30歳にワンダーキッド(21歳以下でのみ発動)」
  /// のような、その選手には一生発動し得ない特性が付くことがあった。
  /// ポジション・年齢的にあり得ない特性を除外したうえで、その選手の資質
  /// ([TrainingEngine.traitSuitability])に比例した重みで抽選する。
  static PlayerTrait? _pickTraitFor(Player p) {
    final roll = _rng.nextDouble();
    if (roll >= 0.35) return null;

    final isGk = p.position.group == PositionGroup.gk;
    final candidates = <PlayerTrait>[];
    final weights = <double>[];
    var totalWeight = 0.0;
    for (final trait in PlayerTrait.values) {
      if (!traitPlausibleAtGeneration(p, trait, isGk: isGk)) continue;
      final w = TrainingEngine.traitSuitability(p, trait);
      candidates.add(trait);
      weights.add(w);
      totalWeight += w;
    }
    if (candidates.isEmpty) return null;
    var pick = _rng.nextDouble() * totalWeight;
    for (var i = 0; i < candidates.length; i++) {
      pick -= weights[i];
      if (pick <= 0) return candidates[i];
    }
    return candidates.last;
  }

  /// 生成時にその選手へ[trait]を割り当てるのが妥当かどうか。
  /// 「一生発動し得ない特性」だけを弾く最小限のフィルタで、
  /// 「今は条件に届かないが鍛えれば発動する」特性(能力値80以上系など)は
  /// 育てがいのある個性として許容する。
  static bool traitPlausibleAtGeneration(
    Player p,
    PlayerTrait trait, {
    required bool isGk,
  }) {
    // 発動条件の年齢上限を過ぎた特性は二度と発動しない(年齢は増える一方)。
    if (trait == PlayerTrait.wonderkid && p.age > 21) return false;
    if (trait == PlayerTrait.primeTime && p.age > 29) return false;

    final attrKey = TrainingEngine.traitAttributeKeyOf(trait);
    if (attrKey == null) return true;
    final isGkAttr = AttributeKeys.goalkeeping.contains(attrKey);
    // GK能力値依存の特性はGK以外には発動機会がなく、逆にGKへ
    // フィールドの技術/フィジカル依存の特性を付けても実態と噛み合わない
    // (GKのメンタル依存特性 — リーダーシップ・冷静さ等 — は許容する)。
    if (isGkAttr && !isGk) return false;
    if (isGk && !isGkAttr && !AttributeKeys.mental.contains(attrKey)) {
      return false;
    }
    return true;
  }

  /// 成長タイプ(早熟/標準/大器晩成)を割り当てる。大半は標準で、
  /// 早熟・大器晩成はそれぞれ4分の1程度の確率で発生する。
  static PlayerGrowthType _pickGrowthType() {
    final roll = _rng.nextDouble();
    if (roll < 0.25) return PlayerGrowthType.early;
    if (roll < 0.5) return PlayerGrowthType.late;
    return PlayerGrowthType.balanced;
  }

  /// 選手のポジション・能力値からロール(プレースタイル)を割り当てる。
  /// CPU選手は手動でロールを設定できないため、ここで割り当てないと
  /// duty/roleに基づく戦術ボーナス・ペナルティがユーザー専用のまま
  /// 一方的になってしまう。適性(keyAttributes平均)が基礎能力を明確に
  /// 上回るロールがなければstandardのまま(無理に決め打ちしない)。
  static PlayerRole _pickRole(Player p) {
    final candidates = PlayerRole.values
        .where(
          (r) =>
              r != PlayerRole.standard &&
              r.allowedGroups.contains(p.position.group),
        )
        .toList();
    if (candidates.isEmpty) return PlayerRole.standard;
    PlayerRole? best;
    double bestAvg = -1;
    for (final r in candidates) {
      final avg =
          r.keyAttributes.fold<int>(0, (s, k) => s + p.attributeValue(k)) /
              r.keyAttributes.length;
      if (avg > bestAvg) {
        bestAvg = avg;
        best = r;
      }
    }
    if (best == null || bestAvg < p.overall + 5) return PlayerRole.standard;
    return best;
  }

  /// ロールが持つ攻守の性格。-1に近いほど守備的、+1に近いほど攻撃的な
  /// ロールであることを表す(未設定・中間的なロールは0)。デューティの
  /// 割り当てをロールの性格と連動させるために使う。
  static double _roleDutyLean(PlayerRole role) => switch (role) {
        PlayerRole.stopper => -0.4,
        PlayerRole.libero => -0.3,
        PlayerRole.anchorMan => -0.6,
        PlayerRole.ballPlayingDefender => 0.2,
        PlayerRole.fullBack => 0.5,
        PlayerRole.wingBack => 0.6,
        PlayerRole.playmaker => 0.3,
        PlayerRole.wideMidfielder => 0.4,
        PlayerRole.mezzala => 0.4,
        PlayerRole.deepLyingForward => -0.3,
        _ => 0.0,
      };

  /// 選手のポジション大分類から、デューティ(攻守の重心)を確率的に割り当てる。
  /// 既に割り当て済みのロール(プレースタイル)が明確に攻撃的/守備的な
  /// 性格を持つ場合は、その傾向にデューティも寄せる(例:アンカーマンは
  /// 守備的デューティになりやすく、ウィングバックは攻撃的デューティに
  /// なりやすい)ことで、ロールとデューティの矛盾を減らす。
  static PlayerDuty _pickDuty(Player p) {
    final roll = _rng.nextDouble();
    final lean = _roleDutyLean(p.role);
    switch (p.position.group) {
      case PositionGroup.gk:
        return PlayerDuty.support;
      case PositionGroup.def:
        final defendThreshold = (0.7 - lean * 0.3).clamp(0.4, 0.9);
        return roll < defendThreshold ? PlayerDuty.defend : PlayerDuty.support;
      case PositionGroup.mid:
        // support比率は据え置き、残り半分をattack/defendの間でleanに応じて
        // 配分し直す(leanが正なら攻撃寄りに、負なら守備寄りに配分を移す)。
        const supportThreshold = 0.5;
        if (roll < supportThreshold) return PlayerDuty.support;
        final attackThreshold =
            (supportThreshold + 0.25 + lean * 0.2).clamp(supportThreshold, 1.0);
        return roll < attackThreshold ? PlayerDuty.attack : PlayerDuty.defend;
      case PositionGroup.att:
        final attackThreshold = (0.7 + lean * 0.2).clamp(0.4, 0.9);
        return roll < attackThreshold ? PlayerDuty.attack : PlayerDuty.support;
    }
  }

  /// 1チーム分のスカッド構成（計23名）。
  static const Map<Position, int> _squadComposition = {
    Position.gk: 2,
    Position.dc: 3,
    Position.dr: 2,
    Position.dl: 2,
    Position.wbr: 1,
    Position.wbl: 1,
    Position.dm: 2,
    Position.mc: 2,
    Position.mr: 1,
    Position.ml: 1,
    Position.amc: 1,
    Position.amr: 1,
    Position.aml: 1,
    Position.st: 3,
  };

  static Team generateSquad({
    required String id,
    required String name,
    required int strengthTier,
  }) {
    final players = <Player>[];
    _squadComposition.forEach((position, count) {
      for (int i = 0; i < count; i++) {
        players.add(generate(position: position, strengthTier: strengthTier));
      }
    });
    return Team(id: id, name: name, players: players);
  }
}
