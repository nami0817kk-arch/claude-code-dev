import 'dart:math';

import 'attributes.dart';
import 'enum_json.dart';
import 'training_focus.dart';

/// Football Manager風の詳細ポジション（14種類）。
enum Position { gk, dr, dc, dl, wbr, wbl, dm, mr, mc, ml, amr, amc, aml, st }

/// 負傷の種類。種類ごとに典型的な療養期間が異なる。
enum InjuryType { bruise, muscle, ligament }

extension InjuryTypeInfo on InjuryType {
  String get label => switch (this) {
        InjuryType.bruise => '打撲',
        InjuryType.muscle => '肉離れ',
        InjuryType.ligament => '靭帯損傷',
      };

  /// 典型的な療養期間(週)の範囲。
  (int min, int max) get durationRange => switch (this) {
        InjuryType.bruise => (1, 2),
        InjuryType.muscle => (2, 5),
        InjuryType.ligament => (4, 10),
      };
}

/// 大分類（GK/DEF/MID/ATT）。試合シミュレーションの攻撃力・守備力算出や
/// トレーニング成長率の判定など、粗い分類で十分な処理に用いる。
enum PositionGroup { gk, def, mid, att }

extension PositionLabel on Position {
  String get label {
    switch (this) {
      case Position.gk:
        return 'GK';
      case Position.dr:
        return 'DR';
      case Position.dc:
        return 'DC';
      case Position.dl:
        return 'DL';
      case Position.wbr:
        return 'WBR';
      case Position.wbl:
        return 'WBL';
      case Position.dm:
        return 'DM';
      case Position.mr:
        return 'MR';
      case Position.mc:
        return 'MC';
      case Position.ml:
        return 'ML';
      case Position.amr:
        return 'AMR';
      case Position.amc:
        return 'AMC';
      case Position.aml:
        return 'AML';
      case Position.st:
        return 'ST';
    }
  }

  /// 日本語での正式名称。
  String get fullLabel {
    switch (this) {
      case Position.gk:
        return 'ゴールキーパー';
      case Position.dr:
        return '右サイドバック';
      case Position.dc:
        return 'センターバック';
      case Position.dl:
        return '左サイドバック';
      case Position.wbr:
        return '右ウイングバック';
      case Position.wbl:
        return '左ウイングバック';
      case Position.dm:
        return '守備的MF';
      case Position.mr:
        return '右MF';
      case Position.mc:
        return 'センターMF';
      case Position.ml:
        return '左MF';
      case Position.amr:
        return '右トップ下';
      case Position.amc:
        return 'トップ下';
      case Position.aml:
        return '左トップ下';
      case Position.st:
        return 'ストライカー';
    }
  }

  PositionGroup get group {
    switch (this) {
      case Position.gk:
        return PositionGroup.gk;
      case Position.dr:
      case Position.dc:
      case Position.dl:
      case Position.wbr:
      case Position.wbl:
        return PositionGroup.def;
      case Position.dm:
      case Position.mr:
      case Position.mc:
      case Position.ml:
        return PositionGroup.mid;
      case Position.amr:
      case Position.amc:
      case Position.aml:
      case Position.st:
        return PositionGroup.att;
    }
  }
}

/// 選手の戦術上のデューティ(役割の重心)。攻撃/守備の貢献度に補正がかかる。
enum PlayerDuty { defend, support, attack }

/// スカッド・ステータス(出場機会の約束)。選手にどの立場を約束するかで、
/// ベンチに置いたときの不満の増え方と、契約交渉で求める週給が変わる。
enum SquadStatus { keyPlayer, regular, rotation, prospect }

extension SquadStatusInfo on SquadStatus {
  String get label => switch (this) {
        SquadStatus.keyPlayer => 'キープレイヤー',
        SquadStatus.regular => '主力',
        SquadStatus.rotation => 'ローテーション',
        SquadStatus.prospect => '育成枠',
      };

  String get description => switch (this) {
        SquadStatus.keyPlayer => '毎試合の出場を約束。外すと大きく不満だが、週給要求も高い',
        SquadStatus.regular => '基本的に出場を想定する標準の立場',
        SquadStatus.rotation => '出場は状況次第。ベンチでも不満が溜まりにくい',
        SquadStatus.prospect => '出場より育成優先。不満はほぼ溜まらず週給も控えめ',
      };

  /// ベンチに置いたときの不満増加に掛かる倍率。
  double get benchExpectationFactor => switch (this) {
        SquadStatus.keyPlayer => 1.6,
        SquadStatus.regular => 1.0,
        SquadStatus.rotation => 0.5,
        SquadStatus.prospect => 0.2,
      };

  /// 契約交渉で求める週給に掛かる倍率(立場が上なほど高い)。
  double get wageFactor => switch (this) {
        SquadStatus.keyPlayer => 1.15,
        SquadStatus.regular => 1.0,
        SquadStatus.rotation => 0.92,
        SquadStatus.prospect => 0.85,
      };
}

extension PlayerDutyInfo on PlayerDuty {
  String get label => switch (this) {
        PlayerDuty.defend => '守備的',
        PlayerDuty.support => 'バランス',
        PlayerDuty.attack => '攻撃的',
      };

  String get description => switch (this) {
        PlayerDuty.defend => '守備力にボーナスが付く代わりに攻撃力が手薄になる。守備を安定させたい選手向け。',
        PlayerDuty.support => '攻守どちらにも偏らない標準設定。',
        PlayerDuty.attack => '攻撃力にボーナスが付く代わりに守備力が手薄になる。得点への関与を増やしたい選手向け。',
      };
}

/// 選手のプレースタイル(ロール)。デューティ(攻守の重心)とは別に、
/// どの能力値を活かしたプレーを得意とするかを表す。役割に適した能力値が
/// 高いほど攻撃/守備への貢献度にボーナスが、低いと逆にペナルティがかかる。
enum PlayerRole {
  standard,
  sweeperKeeper,
  shotStopper,
  commandingKeeper,
  ballPlayingDefender,
  stopper,
  libero,
  fullBack,
  wingBack,
  playmaker,
  boxToBox,
  anchorMan,
  wideMidfielder,
  mezzala,
  poacher,
  targetMan,
  insideForward,
  wingerCrosser,
  deepLyingForward,
  completeForward,
}

extension PlayerRoleInfo on PlayerRole {
  String get label => switch (this) {
        PlayerRole.standard => '標準',
        PlayerRole.sweeperKeeper => 'スイーパーキーパー',
        PlayerRole.shotStopper => 'シュートストッパー',
        PlayerRole.commandingKeeper => '制空型GK',
        PlayerRole.ballPlayingDefender => 'ビルドアップCB',
        PlayerRole.stopper => 'ストッパー',
        PlayerRole.libero => 'リベロ',
        PlayerRole.fullBack => '攻撃参加型SB',
        PlayerRole.wingBack => '突破型WB',
        PlayerRole.playmaker => 'プレーメイカー',
        PlayerRole.boxToBox => 'ボックストゥボックス',
        PlayerRole.anchorMan => 'アンカー',
        PlayerRole.wideMidfielder => 'ワイドMF',
        PlayerRole.mezzala => 'インサイドハーフ',
        PlayerRole.poacher => 'ポーチャー',
        PlayerRole.targetMan => 'ターゲットマン',
        PlayerRole.insideForward => 'カットインアタッカー',
        PlayerRole.wingerCrosser => 'クロッサー',
        PlayerRole.deepLyingForward => '偽9番',
        PlayerRole.completeForward => 'オールラウンドFW',
      };

  String get description => switch (this) {
        PlayerRole.standard => '特定のプレースタイルを指定しない',
        PlayerRole.sweeperKeeper => 'キック・ハンドリングを活かしたビルドアップ参加型のGK',
        PlayerRole.shotStopper => '反射神経とワン・オン・ワンの強さで難しいシュートを止めるGK',
        PlayerRole.commandingKeeper => '空中戦の制圧力でクロス・セットプレーに強いGK',
        PlayerRole.ballPlayingDefender => 'パス・視野を活かして後方から組み立てるCB',
        PlayerRole.stopper => 'タックル・積極性を活かして潰しにかかるCB',
        PlayerRole.libero => '読みの鋭さでカバーリングし、危機を未然に防ぐDF',
        PlayerRole.fullBack => 'スタミナを活かして上下動を繰り返す攻撃参加型のSB/WB',
        PlayerRole.wingBack => 'スピードと仕掛けでサイドを切り裂くWB',
        PlayerRole.playmaker => 'パス・視野で崩しの起点となるMF',
        PlayerRole.boxToBox => 'スタミナ・運動量で攻守にわたって働くMF',
        PlayerRole.anchorMan => 'タックルとポジショニングで潰し役に徹する守備的MF',
        PlayerRole.wideMidfielder => 'クロスとスピードでサイドからチャンスを演出するMF',
        PlayerRole.mezzala => 'ドリブルで持ち運び、攻撃参加するインサイドハーフ',
        PlayerRole.poacher => 'フィニッシュ・オフザボールで得点を狙うFW',
        PlayerRole.targetMan => 'ヘディング・強さを活かした起点となるFW',
        PlayerRole.insideForward => 'ドリブルと中央への仕掛けでゴールに迫るFW',
        PlayerRole.wingerCrosser => 'クロスとスピードでチャンスを供給するウイング',
        PlayerRole.deepLyingForward => '下がってパス・視野で組み立てに参加するFW',
        PlayerRole.completeForward => '技術と冷静さを兼ね備えたオールラウンドなFW',
      };

  /// このロールを選択できるポジション大分類(standardは全ポジション共通)。
  List<PositionGroup> get allowedGroups => switch (this) {
        PlayerRole.standard => PositionGroup.values,
        PlayerRole.sweeperKeeper ||
        PlayerRole.shotStopper ||
        PlayerRole.commandingKeeper =>
          [PositionGroup.gk],
        PlayerRole.ballPlayingDefender ||
        PlayerRole.stopper ||
        PlayerRole.libero ||
        PlayerRole.fullBack ||
        PlayerRole.wingBack =>
          [PositionGroup.def],
        PlayerRole.playmaker ||
        PlayerRole.boxToBox ||
        PlayerRole.anchorMan ||
        PlayerRole.wideMidfielder ||
        PlayerRole.mezzala =>
          [PositionGroup.mid],
        PlayerRole.poacher ||
        PlayerRole.targetMan ||
        PlayerRole.insideForward ||
        PlayerRole.wingerCrosser ||
        PlayerRole.deepLyingForward ||
        PlayerRole.completeForward =>
          [PositionGroup.att],
      };

  /// このロールの適性を判定する際に重視する能力値(2項目の平均で評価)。
  List<String> get keyAttributes => switch (this) {
        PlayerRole.standard => const [],
        PlayerRole.sweeperKeeper => const [
            AttributeKeys.kicking,
            AttributeKeys.commandOfArea,
          ],
        PlayerRole.shotStopper => const [
            AttributeKeys.reflexes,
            AttributeKeys.oneOnOnes,
          ],
        PlayerRole.commandingKeeper => const [
            AttributeKeys.aerialReach,
            AttributeKeys.handling,
          ],
        PlayerRole.ballPlayingDefender => const [
            AttributeKeys.passing,
            AttributeKeys.vision,
          ],
        PlayerRole.stopper => const [
            AttributeKeys.tackling,
            AttributeKeys.aggression,
          ],
        PlayerRole.libero => const [
            AttributeKeys.anticipation,
            AttributeKeys.positioning,
          ],
        PlayerRole.fullBack => const [
            AttributeKeys.crossing,
            AttributeKeys.stamina,
          ],
        PlayerRole.wingBack => const [
            AttributeKeys.pace,
            AttributeKeys.dribbling
          ],
        PlayerRole.playmaker => const [
            AttributeKeys.vision,
            AttributeKeys.passing
          ],
        PlayerRole.boxToBox => const [
            AttributeKeys.stamina,
            AttributeKeys.workRate,
          ],
        PlayerRole.anchorMan => const [
            AttributeKeys.tackling,
            AttributeKeys.positioning,
          ],
        PlayerRole.wideMidfielder => const [
            AttributeKeys.crossing,
            AttributeKeys.pace,
          ],
        PlayerRole.mezzala => const [
            AttributeKeys.dribbling,
            AttributeKeys.offTheBall,
          ],
        PlayerRole.poacher => const [
            AttributeKeys.finishing,
            AttributeKeys.offTheBall,
          ],
        PlayerRole.targetMan => const [
            AttributeKeys.heading,
            AttributeKeys.strength,
          ],
        PlayerRole.insideForward => const [
            AttributeKeys.dribbling,
            AttributeKeys.longShots,
          ],
        PlayerRole.wingerCrosser => const [
            AttributeKeys.crossing,
            AttributeKeys.pace,
          ],
        PlayerRole.deepLyingForward => const [
            AttributeKeys.passing,
            AttributeKeys.vision,
          ],
        PlayerRole.completeForward => const [
            AttributeKeys.technique,
            AttributeKeys.composure,
          ],
      };
}

/// 選手の性格。不満度(happiness)の変動しやすさや移籍希望の出やすさに影響する。
enum PlayerPersonality {
  professional,
  balanced,
  ambitious,
  temperamental,
  loyal,
  modelCitizen,
  resolute,
  spirited,
  determined,
  driven,
  perfectionist,
  laidBack,
  easilyDiscouraged,
  volatile,
  unambitious,
  lowDetermination,
  fairlyProfessional,
  veryAmbitious,
  mercenary,
  clubLegendType,
}

extension PlayerPersonalityInfo on PlayerPersonality {
  String get label => switch (this) {
        PlayerPersonality.professional => 'プロフェッショナル',
        PlayerPersonality.balanced => 'バランス型',
        PlayerPersonality.ambitious => '野心家',
        PlayerPersonality.temperamental => '気分屋',
        PlayerPersonality.loyal => '忠誠心の強い選手',
        PlayerPersonality.modelCitizen => '模範選手',
        PlayerPersonality.resolute => '動じない性格',
        PlayerPersonality.spirited => '闘争心旺盛',
        PlayerPersonality.determined => '負けず嫌い',
        PlayerPersonality.driven => '成り上がり志向',
        PlayerPersonality.perfectionist => '完璧主義',
        PlayerPersonality.laidBack => 'おおらか',
        PlayerPersonality.easilyDiscouraged => 'メンタルが弱い',
        PlayerPersonality.volatile => '非常に不安定',
        PlayerPersonality.unambitious => '向上心が低い',
        PlayerPersonality.lowDetermination => '根性がない',
        PlayerPersonality.fairlyProfessional => 'まずまず堅実',
        PlayerPersonality.veryAmbitious => '非常に野心的',
        PlayerPersonality.mercenary => '契約至上主義',
        PlayerPersonality.clubLegendType => '生え抜き気質',
      };

  String get description => switch (this) {
        PlayerPersonality.professional => '不満が溜まりにくく、安定した意欲を保つ',
        PlayerPersonality.balanced => '標準的な反応を示す',
        PlayerPersonality.ambitious => 'ベンチや低成績にすぐ不満を抱く',
        PlayerPersonality.temperamental => '状況次第で気分が大きく変動する',
        PlayerPersonality.loyal => '多少の不満があってもクラブに留まりやすい',
        PlayerPersonality.modelCitizen => '常に高い意欲を保ち、若手の手本となる',
        PlayerPersonality.resolute => '逆境でも動揺せず冷静さを保つ',
        PlayerPersonality.spirited => '困難な状況でも闘争心を燃やして奮起する',
        PlayerPersonality.determined => '結果へのこだわりが強く、成長への意欲も高い',
        PlayerPersonality.driven => '自らの評価・待遇の向上に強くこだわる',
        PlayerPersonality.perfectionist => 'ベンチや低評価に強い不満を抱く一方、自己研鑽への意欲は高い',
        PlayerPersonality.laidBack => '何事にも動じないが、向上心もやや控えめ',
        PlayerPersonality.easilyDiscouraged => '結果が振るわないとすぐに意気消沈する',
        PlayerPersonality.volatile => '気分の浮き沈みが極端で、扱いが難しい',
        PlayerPersonality.unambitious => '現状に満足しやすく、成長への意欲は控えめ',
        PlayerPersonality.lowDetermination => '困難な状況で粘り強さに欠ける',
        PlayerPersonality.fairlyProfessional => 'プロフェッショナルとバランス型の中間的な気質',
        PlayerPersonality.veryAmbitious => '常により高みを目指し、現状への不満を抱きやすい',
        PlayerPersonality.mercenary => '待遇・移籍金への関心が非常に強い',
        PlayerPersonality.clubLegendType => 'クラブへの忠誠心が非常に強く、多少の不満では移籍を望まない',
      };

  double get benchSensitivity => switch (this) {
        PlayerPersonality.professional => 0.6,
        PlayerPersonality.balanced => 1.0,
        PlayerPersonality.ambitious => 1.5,
        PlayerPersonality.temperamental => 1.3,
        PlayerPersonality.loyal => 0.8,
        PlayerPersonality.modelCitizen => 0.5,
        PlayerPersonality.resolute => 0.65,
        PlayerPersonality.spirited => 0.9,
        PlayerPersonality.determined => 0.7,
        PlayerPersonality.driven => 1.1,
        PlayerPersonality.perfectionist => 1.2,
        PlayerPersonality.laidBack => 0.6,
        PlayerPersonality.easilyDiscouraged => 1.4,
        PlayerPersonality.volatile => 1.6,
        PlayerPersonality.unambitious => 0.7,
        PlayerPersonality.lowDetermination => 1.0,
        PlayerPersonality.fairlyProfessional => 0.8,
        PlayerPersonality.veryAmbitious => 1.7,
        PlayerPersonality.mercenary => 1.2,
        PlayerPersonality.clubLegendType => 0.55,
      };

  double get wageSensitivity => switch (this) {
        PlayerPersonality.professional => 0.7,
        PlayerPersonality.balanced => 1.0,
        PlayerPersonality.ambitious => 1.3,
        PlayerPersonality.temperamental => 1.2,
        PlayerPersonality.loyal => 0.7,
        PlayerPersonality.modelCitizen => 0.6,
        PlayerPersonality.resolute => 0.85,
        PlayerPersonality.spirited => 0.95,
        PlayerPersonality.determined => 0.9,
        PlayerPersonality.driven => 1.35,
        PlayerPersonality.perfectionist => 1.0,
        PlayerPersonality.laidBack => 0.6,
        PlayerPersonality.easilyDiscouraged => 1.1,
        PlayerPersonality.volatile => 1.3,
        PlayerPersonality.unambitious => 0.6,
        PlayerPersonality.lowDetermination => 1.0,
        PlayerPersonality.fairlyProfessional => 0.85,
        PlayerPersonality.veryAmbitious => 1.5,
        PlayerPersonality.mercenary => 1.6,
        PlayerPersonality.clubLegendType => 0.65,
      };

  double get resultSensitivity => switch (this) {
        PlayerPersonality.professional => 0.7,
        PlayerPersonality.balanced => 1.0,
        PlayerPersonality.ambitious => 1.4,
        PlayerPersonality.temperamental => 1.2,
        PlayerPersonality.loyal => 0.8,
        PlayerPersonality.modelCitizen => 0.6,
        PlayerPersonality.resolute => 0.65,
        PlayerPersonality.spirited => 0.85,
        PlayerPersonality.determined => 0.7,
        PlayerPersonality.driven => 1.15,
        PlayerPersonality.perfectionist => 1.1,
        PlayerPersonality.laidBack => 0.6,
        PlayerPersonality.easilyDiscouraged => 1.5,
        PlayerPersonality.volatile => 1.5,
        PlayerPersonality.unambitious => 0.7,
        PlayerPersonality.lowDetermination => 1.0,
        PlayerPersonality.fairlyProfessional => 0.85,
        PlayerPersonality.veryAmbitious => 1.6,
        PlayerPersonality.mercenary => 1.1,
        PlayerPersonality.clubLegendType => 0.7,
      };

  /// 不満度がこの値を下回ると移籍を希望し始める。
  int get transferRequestThreshold => switch (this) {
        PlayerPersonality.loyal => 10,
        PlayerPersonality.professional => 15,
        PlayerPersonality.balanced => 20,
        PlayerPersonality.temperamental => 25,
        PlayerPersonality.ambitious => 30,
        PlayerPersonality.modelCitizen => 8,
        PlayerPersonality.resolute => 12,
        PlayerPersonality.spirited => 18,
        PlayerPersonality.determined => 14,
        PlayerPersonality.driven => 28,
        PlayerPersonality.perfectionist => 20,
        PlayerPersonality.laidBack => 15,
        PlayerPersonality.easilyDiscouraged => 22,
        PlayerPersonality.volatile => 28,
        PlayerPersonality.unambitious => 10,
        PlayerPersonality.lowDetermination => 18,
        PlayerPersonality.fairlyProfessional => 17,
        PlayerPersonality.veryAmbitious => 35,
        PlayerPersonality.mercenary => 38,
        PlayerPersonality.clubLegendType => 5,
      };

  /// トレーニングでの成長効率倍率。プロフェッショナルな選手ほど自主練習に
  /// 励んで伸びやすく、気分屋は取り組みにムラがあり伸び悩みやすい。
  double get growthFactor => switch (this) {
        PlayerPersonality.professional => 1.15,
        PlayerPersonality.ambitious => 1.08,
        PlayerPersonality.balanced => 1.0,
        PlayerPersonality.loyal => 0.97,
        PlayerPersonality.temperamental => 0.85,
        PlayerPersonality.modelCitizen => 1.2,
        PlayerPersonality.resolute => 1.05,
        PlayerPersonality.spirited => 1.12,
        PlayerPersonality.determined => 1.18,
        PlayerPersonality.driven => 1.1,
        PlayerPersonality.perfectionist => 1.15,
        PlayerPersonality.laidBack => 0.85,
        PlayerPersonality.easilyDiscouraged => 0.85,
        PlayerPersonality.volatile => 0.8,
        PlayerPersonality.unambitious => 0.8,
        PlayerPersonality.lowDetermination => 0.78,
        PlayerPersonality.fairlyProfessional => 1.08,
        PlayerPersonality.veryAmbitious => 1.05,
        PlayerPersonality.mercenary => 0.95,
        PlayerPersonality.clubLegendType => 0.98,
      };

  /// 想定移籍金への性格による倍率。プロ意識・野心の高さは他クラブからの
  /// 評価(=市場価値)を押し上げ、気分屋は「扱いにくさ」を敬遠されて
  /// 割り引かれる。忠誠心は移籍する気の薄さから買い手がつきにくい。
  double get marketValueFactor => switch (this) {
        PlayerPersonality.professional => 1.1,
        PlayerPersonality.ambitious => 1.08,
        PlayerPersonality.balanced => 1.0,
        PlayerPersonality.loyal => 0.95,
        PlayerPersonality.temperamental => 0.88,
        PlayerPersonality.modelCitizen => 1.12,
        PlayerPersonality.resolute => 1.03,
        PlayerPersonality.spirited => 1.05,
        PlayerPersonality.determined => 1.05,
        PlayerPersonality.driven => 1.1,
        PlayerPersonality.perfectionist => 1.05,
        PlayerPersonality.laidBack => 0.95,
        PlayerPersonality.easilyDiscouraged => 0.9,
        PlayerPersonality.volatile => 0.85,
        PlayerPersonality.unambitious => 0.9,
        PlayerPersonality.lowDetermination => 0.95,
        PlayerPersonality.fairlyProfessional => 1.03,
        PlayerPersonality.veryAmbitious => 1.12,
        PlayerPersonality.mercenary => 1.15,
        PlayerPersonality.clubLegendType => 0.9,
      };
}

/// 選手の特性。性格(不満度・成長)とは別に、試合の内容(相手の力量差・
/// ホーム/アウェイ・天候・コンディション・年齢・各種能力値の高さ・
/// 調子の波)によって当日のパフォーマンスに補正がかかる。能力値が同じ
/// 選手同士でも結果に差が出るようにするための要素。持たない選手も多い。
enum PlayerTrait {
  // 対戦相手との相対的な実力差
  giantKiller,
  frontRunner,
  underdogSpirit,
  dominantForce,
  // 対戦相手の絶対的な実力
  bigGameHunter,
  bullyBall,
  // ホーム/アウェイ
  homeBoy,
  roadWarrior,
  // 天候
  rainMaster,
  windMaster,
  heatwaveMaster,
  snowMaster,
  fairWeatherPlayer,
  // 疲労・コンディション
  ironLungs,
  freshLegs,
  confidentMind,
  clutchNerves,
  contentPlayer,
  sharpShooter,
  rustyButReady,
  // 年齢
  wonderkid,
  oldHead,
  primeTime,
  // メンタル属性依存
  warriorSpirit,
  calmHead,
  leaderOnPitch,
  // 波・安定性
  streaky,
  volatileTalent,
  metronome,
  // 技術・フィジカル属性依存
  visionary,
  paceMerchant,
  powerhouse,
  enginesRunning,
  silkyDribbler,
  playmakerTrait,
  ballWinner,
  shadowMarker,
  clinicalFinisher,
  distanceShooter,
  aerialThreat,
  showman,
  sureTouch,
  crossSpecialist,
  setPieceMaestro,
  clockwork,
  decisiveMind,
  teamPlayer,
  tirelessRunner,
  explosiveStart,
  fearlessDefender,
  // サッカー漫画のような劇的な特性(複合条件・GK属性の活用)
  divineReflexes,
  awayDayHero,
  risingPhoenix,
  veteranAce,
}

extension PlayerTraitInfo on PlayerTrait {
  String get label => switch (this) {
        PlayerTrait.giantKiller => '格上キラー',
        PlayerTrait.frontRunner => '横綱相撲',
        PlayerTrait.underdogSpirit => '判官びいき',
        PlayerTrait.dominantForce => '圧倒的優位',
        PlayerTrait.bigGameHunter => 'ビッグゲームハンター',
        PlayerTrait.bullyBall => '弱者いじめ',
        PlayerTrait.homeBoy => '我が家が一番',
        PlayerTrait.roadWarrior => '遠征上等',
        PlayerTrait.rainMaster => '雨のスペシャリスト',
        PlayerTrait.windMaster => '強風マイスター',
        PlayerTrait.heatwaveMaster => '猛暑をものともせず',
        PlayerTrait.snowMaster => '雪上のアーティスト',
        PlayerTrait.fairWeatherPlayer => '快晴主義',
        PlayerTrait.ironLungs => '鉄の肺',
        PlayerTrait.freshLegs => 'フレッシュレッグ',
        PlayerTrait.confidentMind => '自信家',
        PlayerTrait.clutchNerves => '逆境をはねのける',
        PlayerTrait.contentPlayer => '満ち足りた心',
        PlayerTrait.sharpShooter => '絶好調',
        PlayerTrait.rustyButReady => '錆びついても衰えぬ',
        PlayerTrait.wonderkid => '若き才能',
        PlayerTrait.oldHead => '百戦錬磨',
        PlayerTrait.primeTime => '脂の乗った時期',
        PlayerTrait.warriorSpirit => '闘将',
        PlayerTrait.calmHead => '冷静沈着',
        PlayerTrait.leaderOnPitch => 'ピッチの統率者',
        PlayerTrait.streaky => '波がある',
        PlayerTrait.volatileTalent => '気分屋の天才',
        PlayerTrait.metronome => 'メトロノーム',
        PlayerTrait.visionary => '視野の魔術師',
        PlayerTrait.paceMerchant => 'スピードスター',
        PlayerTrait.powerhouse => 'パワーハウス',
        PlayerTrait.enginesRunning => '尽きぬスタミナ',
        PlayerTrait.silkyDribbler => '華麗なドリブラー',
        PlayerTrait.playmakerTrait => '司令塔の才',
        PlayerTrait.ballWinner => 'ボールハンター',
        PlayerTrait.shadowMarker => '影のマーカー',
        PlayerTrait.clinicalFinisher => '冷徹なフィニッシャー',
        PlayerTrait.distanceShooter => 'ロングレンジシューター',
        PlayerTrait.aerialThreat => '空中戦の脅威',
        PlayerTrait.showman => 'ショーマン',
        PlayerTrait.sureTouch => '確かなファーストタッチ',
        PlayerTrait.crossSpecialist => 'クロスの名手',
        PlayerTrait.setPieceMaestro => 'セットプレーの達人',
        PlayerTrait.clockwork => '予測の天才',
        PlayerTrait.decisiveMind => '的確な判断',
        PlayerTrait.teamPlayer => '献身的なチームワーク',
        PlayerTrait.tirelessRunner => '尽きせぬ運動量',
        PlayerTrait.explosiveStart => '爆発的な加速',
        PlayerTrait.fearlessDefender => '恐れを知らぬ守備',
        PlayerTrait.divineReflexes => '神がかった反応',
        PlayerTrait.awayDayHero => 'アウェイの逆境児',
        PlayerTrait.risingPhoenix => '不屈の闘志',
        PlayerTrait.veteranAce => '伝説のベテランエース',
      };

  String get description => switch (this) {
        PlayerTrait.giantKiller => '自チームより格上の相手との試合でパフォーマンスが上がる。',
        PlayerTrait.frontRunner => '自チームより格下の相手との試合でパフォーマンスが上がる。',
        PlayerTrait.underdogSpirit => '大きく格上の相手との大金星がかかる試合で、特に奮起する。',
        PlayerTrait.dominantForce => '大きく格下の相手に対し、危なげなく実力を発揮する。',
        PlayerTrait.bigGameHunter => '相手の実力が高いほど燃えるタイプで、強豪との試合で輝く。',
        PlayerTrait.bullyBall => '実力の劣る相手には容赦なく、着実に力を発揮する。',
        PlayerTrait.homeBoy => 'ホームゲームで観客の後押しを受けて力を発揮する。',
        PlayerTrait.roadWarrior => 'アウェイゲームでも物怖じせず、普段通りの力を出せる。',
        PlayerTrait.rainMaster => '雨天の試合でも足元が乱れず、パフォーマンスを落とさない。',
        PlayerTrait.windMaster => '強風下でもボールコントロールを乱さない。',
        PlayerTrait.heatwaveMaster => '猛暑の試合でも運動量が落ちにくい。',
        PlayerTrait.snowMaster => '雪の中でも普段以上の輝きを見せる稀有な選手。',
        PlayerTrait.fairWeatherPlayer => '天候の良い試合でこそ本領を発揮する。',
        PlayerTrait.ironLungs => '疲労が溜まった状態でも動きが落ちない。',
        PlayerTrait.freshLegs => '疲労が少ない状態では特に鋭さを増す。',
        PlayerTrait.confidentMind => '士気が高いときにさらに調子を上げる。',
        PlayerTrait.clutchNerves => '士気が落ち込んでいてもむしろ闘志を燃やす。',
        PlayerTrait.contentPlayer => 'クラブへの満足度が高いと安定した力を発揮する。',
        PlayerTrait.sharpShooter => 'マッチシャープネスが最高潮のときに爆発的な力を見せる。',
        PlayerTrait.rustyButReady => '実戦感覚が鈍っていても崩れない安定感を持つ。',
        PlayerTrait.wonderkid => '若さゆえの勢いでプレーに勢いが出る。',
        PlayerTrait.oldHead => '豊富な経験に裏打ちされた読みでプレーする。',
        PlayerTrait.primeTime => '選手としての全盛期にひときわ輝く。',
        PlayerTrait.warriorSpirit => '闘志の高さがそのままプレーの迫力に変わる。',
        PlayerTrait.calmHead => '冷静さが持ち味で、大舞台でも動じない。',
        PlayerTrait.leaderOnPitch => '統率力の高さでチーム全体を引っ張る。',
        PlayerTrait.streaky => '調子の波が激しく、試合ごとのパフォーマンスのブレが大きい。',
        PlayerTrait.volatileTalent => '極端に調子の良し悪しが分かれる、より波の激しいタイプ。',
        PlayerTrait.metronome => '常に安定したパフォーマンスを崩さない。',
        PlayerTrait.visionary => '卓越した視野でチャンスを作り出す。',
        PlayerTrait.paceMerchant => 'スピードを活かしたプレーで違いを生む。',
        PlayerTrait.powerhouse => '圧倒的なフィジカルの強さで相手を圧倒する。',
        PlayerTrait.enginesRunning => '豊富なスタミナで最後まで運動量を落とさない。',
        PlayerTrait.silkyDribbler => '卓越したドリブルで局面を打開する。',
        PlayerTrait.playmakerTrait => '高いパス精度でチームの攻撃を組み立てる。',
        PlayerTrait.ballWinner => '鋭いタックルで相手からボールを奪う。',
        PlayerTrait.shadowMarker => '高いマーキング能力で相手を封じ込める。',
        PlayerTrait.clinicalFinisher => '決定力の高さでチャンスを確実に決めきる。',
        PlayerTrait.distanceShooter => '遠目からのシュートで違いを見せる。',
        PlayerTrait.aerialThreat => '高い制空力でセットプレーの脅威となる。',
        PlayerTrait.showman => '閃きのあるプレーで観客を沸かせる。',
        PlayerTrait.sureTouch => '正確なファーストタッチでプレーの精度を高める。',
        PlayerTrait.crossSpecialist => '精度の高いクロスでチャンスを演出する。',
        PlayerTrait.setPieceMaestro => 'フリーキックの精度で得点機会を作る。',
        PlayerTrait.clockwork => '鋭い予測でプレーの一歩先を読む。',
        PlayerTrait.decisiveMind => '高い判断力で最適なプレーを選択する。',
        PlayerTrait.teamPlayer => '高いチームワークでチームに貢献する。',
        PlayerTrait.tirelessRunner => '豊富な運動量でピッチを走り回る。',
        PlayerTrait.explosiveStart => '鋭い加速力で相手を置き去りにする。',
        PlayerTrait.fearlessDefender => '勇敢さを武器に体を張ったプレーを見せる。',
        PlayerTrait.divineReflexes => '神がかった反応速度で、並みのシュートを寄せ付けない守護神。',
        PlayerTrait.awayDayHero => 'アウェイでの大きな逆境ほど、燃え上がって真価を発揮する。',
        PlayerTrait.risingPhoenix => '苦境で意気消沈するどころか、そこから闘志を燃やして這い上がる。',
        PlayerTrait.veteranAce => '経験を積んだベテランが、大一番でこそその真価を見せつける。',
      };
}

/// 選手特性の習得経路による分類。
/// - [technical]: 具体的な技術・フィジカルの練習(特訓)で身につけられる。
/// - [personality]: 練習では身につかず、メンター(チームメイト)や監督との
///   関わり(声かけ)を通じて選手の中で育っていく。
/// - [talent]: 生まれ持った資質であり、特訓によって後から獲得することはできない。
enum PlayerTraitCategory { technical, personality, talent }

extension PlayerTraitCategoryInfo on PlayerTraitCategory {
  String get label => switch (this) {
        PlayerTraitCategory.technical => '技術',
        PlayerTraitCategory.personality => '性格',
        PlayerTraitCategory.talent => '才能',
      };

  String get acquisitionHint => switch (this) {
        PlayerTraitCategory.technical => '特訓(練習)で狙って身につけられる',
        PlayerTraitCategory.personality => 'メンターや監督の声かけを通じて育っていく',
        PlayerTraitCategory.talent => '生まれ持った資質。特訓では身につけられない',
      };
}

/// 各選手特性がどの分類に属するか。
/// 技術: 特定の技術・フィジカル能力値に直結し、練習で伸ばせるもの。
/// 性格: 対戦相手・状況への向き合い方やメンタル面の資質で、チームメイト
///   (メンター)や監督との関わりの中で育つもの。
/// 才能: 天候・年齢・調子の波など、選手自身の生まれ持った資質や外的条件に
///   左右され、練習では後天的に獲得できないもの。
extension PlayerTraitCategoryOf on PlayerTrait {
  PlayerTraitCategory get category => switch (this) {
        PlayerTrait.giantKiller => PlayerTraitCategory.personality,
        PlayerTrait.frontRunner => PlayerTraitCategory.personality,
        PlayerTrait.underdogSpirit => PlayerTraitCategory.personality,
        PlayerTrait.dominantForce => PlayerTraitCategory.personality,
        PlayerTrait.bigGameHunter => PlayerTraitCategory.personality,
        PlayerTrait.bullyBall => PlayerTraitCategory.personality,
        PlayerTrait.homeBoy => PlayerTraitCategory.personality,
        PlayerTrait.roadWarrior => PlayerTraitCategory.personality,
        PlayerTrait.rainMaster => PlayerTraitCategory.talent,
        PlayerTrait.windMaster => PlayerTraitCategory.talent,
        PlayerTrait.heatwaveMaster => PlayerTraitCategory.talent,
        PlayerTrait.snowMaster => PlayerTraitCategory.talent,
        PlayerTrait.fairWeatherPlayer => PlayerTraitCategory.talent,
        PlayerTrait.ironLungs => PlayerTraitCategory.talent,
        PlayerTrait.freshLegs => PlayerTraitCategory.talent,
        PlayerTrait.confidentMind => PlayerTraitCategory.personality,
        PlayerTrait.clutchNerves => PlayerTraitCategory.personality,
        PlayerTrait.contentPlayer => PlayerTraitCategory.personality,
        PlayerTrait.sharpShooter => PlayerTraitCategory.technical,
        PlayerTrait.rustyButReady => PlayerTraitCategory.talent,
        PlayerTrait.wonderkid => PlayerTraitCategory.talent,
        PlayerTrait.oldHead => PlayerTraitCategory.talent,
        PlayerTrait.primeTime => PlayerTraitCategory.talent,
        PlayerTrait.warriorSpirit => PlayerTraitCategory.personality,
        PlayerTrait.calmHead => PlayerTraitCategory.personality,
        PlayerTrait.leaderOnPitch => PlayerTraitCategory.personality,
        PlayerTrait.streaky => PlayerTraitCategory.talent,
        PlayerTrait.volatileTalent => PlayerTraitCategory.talent,
        PlayerTrait.metronome => PlayerTraitCategory.talent,
        PlayerTrait.visionary => PlayerTraitCategory.technical,
        PlayerTrait.paceMerchant => PlayerTraitCategory.technical,
        PlayerTrait.powerhouse => PlayerTraitCategory.technical,
        PlayerTrait.enginesRunning => PlayerTraitCategory.technical,
        PlayerTrait.silkyDribbler => PlayerTraitCategory.technical,
        PlayerTrait.playmakerTrait => PlayerTraitCategory.technical,
        PlayerTrait.ballWinner => PlayerTraitCategory.technical,
        PlayerTrait.shadowMarker => PlayerTraitCategory.technical,
        PlayerTrait.clinicalFinisher => PlayerTraitCategory.technical,
        PlayerTrait.distanceShooter => PlayerTraitCategory.technical,
        PlayerTrait.aerialThreat => PlayerTraitCategory.technical,
        PlayerTrait.showman => PlayerTraitCategory.personality,
        PlayerTrait.sureTouch => PlayerTraitCategory.technical,
        PlayerTrait.crossSpecialist => PlayerTraitCategory.technical,
        PlayerTrait.setPieceMaestro => PlayerTraitCategory.technical,
        PlayerTrait.clockwork => PlayerTraitCategory.technical,
        PlayerTrait.decisiveMind => PlayerTraitCategory.personality,
        PlayerTrait.teamPlayer => PlayerTraitCategory.personality,
        PlayerTrait.tirelessRunner => PlayerTraitCategory.technical,
        PlayerTrait.explosiveStart => PlayerTraitCategory.technical,
        PlayerTrait.fearlessDefender => PlayerTraitCategory.personality,
        PlayerTrait.divineReflexes => PlayerTraitCategory.technical,
        PlayerTrait.awayDayHero => PlayerTraitCategory.personality,
        PlayerTrait.risingPhoenix => PlayerTraitCategory.personality,
        PlayerTrait.veteranAce => PlayerTraitCategory.talent,
      };
}

/// 選手の成長タイプ。年齢に応じた伸びやすさ・衰え始める時期の傾向を表す。
/// 早熟は若いうちに一気に伸びて衰えも早く、大器晩成は伸びが遅い代わりに
/// 長く成長・活躍できる。育成方針(誰を我慢して使い続けるか)に戦略性を
/// もたらす要素。
enum PlayerGrowthType { early, balanced, late }

extension PlayerGrowthTypeInfo on PlayerGrowthType {
  String get label => switch (this) {
        PlayerGrowthType.early => '早熟',
        PlayerGrowthType.balanced => '標準',
        PlayerGrowthType.late => '大器晩成',
      };

  String get description => switch (this) {
        PlayerGrowthType.early => '若いうちの伸びが早い一方、衰え始めるのも早い',
        PlayerGrowthType.balanced => '年齢による伸び・衰えの標準的なカーブをたどる',
        PlayerGrowthType.late => '若いうちの伸びは遅いが、その分長く成長し衰えも遅い',
      };
}

/// 旧バージョン（gk/df/mf/fwの4区分）のセーブデータからポジション名を解決する。
Position parsePosition(String raw) {
  switch (raw) {
    case 'df':
      return Position.dc;
    case 'mf':
      return Position.mc;
    case 'fw':
      return Position.st;
    default:
      try {
        return Position.values.byName(raw);
      } catch (_) {
        return Position.mc;
      }
  }
}

/// セーブデータの技術特訓ターゲットを復元する。カテゴリ分類の導入以前の
/// セーブデータでは技術以外の特性が入っている場合があるため、その場合は
/// 練習では習得できない特性として黙って読み捨てる(null扱い)。
PlayerTrait? _technicalTraitTargetFromJson(String? raw) {
  if (raw == null) return null;
  final trait = enumFromName(PlayerTrait.values, raw, PlayerTrait.streaky);
  return trait.category == PlayerTraitCategory.technical ? trait : null;
}

/// セーブデータの性格特性ターゲットを復元する。性格カテゴリ以外の特性が
/// 入っていた場合は同様に読み捨てる。
PlayerTrait? _personalityTraitTargetFromJson(String? raw) {
  if (raw == null) return null;
  final trait = enumFromName(PlayerTrait.values, raw, PlayerTrait.streaky);
  return trait.category == PlayerTraitCategory.personality ? trait : null;
}

class Player {
  final String id;
  String name;
  int age;
  Position position;

  /// 主ポジションほどではないが無理なくこなせるポジション（0〜2個程度）。
  List<Position> secondaryPositions;

  /// 技術・メンタル・フィジカル・GKの詳細能力値（[AttributeKeys.all]の42項目、1-99）。
  Map<String, int> attributes;

  int potential;
  int fatigue;
  int morale;
  int injuryWeeks;

  /// 現在負傷している場合の負傷の種類(負傷していない場合はnull)。
  InjuryType? injuryType;

  /// 過去に負ったことのある負傷の種類ごとの回数。再負傷のリスク判定に使う。
  Map<String, int> injuryHistoryCounts;

  /// 現在の累積警告数(退場したリセットされる)。[yellowCardSuspensionThreshold]枚
  /// 貯まると次節出場停止になり0にリセットされる。
  int yellowCards;

  /// 出場停止の残り試合数(0なら出場停止でない)。退場は即1試合、
  /// 警告累積は[yellowCardSuspensionThreshold]枚で1試合の出場停止。
  int suspendedMatches;

  /// 通算出場試合数・通算得点数(公式戦・カップ戦。親善試合は含まない)。
  int careerAppearances;
  int careerGoals;

  /// 個別のトレーニング方針。nullの場合はチームの既定方針に従う。
  TrainingFocus? individualFocus;

  /// 週俸（万円）
  int wage;

  /// 契約残り年数。0になると自由契約としてチームを去る(シーズン開始時に
  /// 1年ずつ消化する)。
  int contractYearsRemaining;

  /// 性格。不満度の変動しやすさ・移籍希望の出やすさに影響する。
  PlayerPersonality personality;

  /// 不満度（0-100）。低いほど移籍を希望しやすくなる。
  int happiness;

  /// 話し合い(reassure)の再実施までの残り週数。0なら実施可能。
  /// 連発による不満度管理の形骸化を防ぐためのクールダウン。
  int reassureCooldownWeeks;

  /// 個別声かけ(モチベーショントーク)の再実施までの残り週数。0なら実施可能。
  /// reassureが不満度(happiness)を対象にするのに対し、こちらは士気(morale)を
  /// 対象にした短期的なコマンドで、連発を防ぐためのクールダウン。
  int talkCooldownWeeks;

  /// ローンでの加入かどうか。ローン選手は契約更新・放出の対象外で、
  /// [loanWeeksRemaining]が0になると自動的にチームを離れる。
  bool isLoan;

  /// ローン期間の残り週数（ローン選手でない場合は0）。
  int loanWeeksRemaining;

  /// ローン契約に買取オプションが付いている場合の買取金額(万円)。
  /// ローン期間中いつでもこの金額を支払えば恒久的に完全移籍へ切り替えられる。
  /// 買取オプションがない通常のローンの場合はnull。
  int? loanBuyOptionFee;

  /// リリース条項(解放金額、万円)。設定されている場合、他クラブがこの金額を
  /// 提示すると交渉なしで自動的に移籍が成立する。未設定はnull。
  int? releaseClause;

  /// 代表召集で一時離脱している残り週数(0なら招集されていない)。
  /// 招集中はスタメン・自動編成の対象外になる。
  int internationalDutyWeeksRemaining;

  /// 戦術上のデューティ(守備的/バランス/攻撃的)。試合エンジンの攻守貢献度に補正がかかる。
  PlayerDuty duty;

  /// スカッド・ステータス(出場機会の約束)。旧セーブは「主力」扱い。
  SquadStatus squadStatus;

  /// 移籍リストに登録されているか。登録中は他クラブからのオファーが来やすくなる。
  bool isTransferListed;

  /// 他クラブへローン放出中かどうかの残り週数(0なら放出されていない)。
  /// 放出中はスタメン・自動編成の対象外で、週俸は放出先クラブが負担する。
  int loanedOutWeeksRemaining;
  String? loanedOutToClubName;

  /// 移籍市場にスカウティング候補として掲載されている選手の現所属クラブ名
  /// (表示専用。自クラブの選手・フリーエージェントにはnull)。
  String? originClubName;

  /// 出場手当(万円)。契約更新時に決定され、リーグ公式戦でスタメン出場するたびに支払われる。
  int appearanceFee;

  /// プレースタイル(ロール)。デューティとは別に、活躍する能力値の傾向を表す。
  PlayerRole role;

  /// 本職(主ポジション)以外のポジションで起用された際の慣れ度(0-100、
  /// Position.name → 慣れ度)。出場を重ねるごとに上昇し、攻撃/守備への
  /// ペナルティを徐々に軽減する。主ポジションは常に完全適性のため含まない。
  Map<String, int> positionFamiliarity;

  /// 直近の試合勘・コンディション(0-100)。出場を重ねると上昇し、
  /// ベンチ・怪我・出場停止が続くと緩やかに低下する。負傷から復帰した
  /// 直後は大きく下がる。試合エンジンのコンディション算出に用いる。
  int matchSharpness;

  /// ユース練習試合の通算出場数(昇格候補在籍中のみ加算)。昇格後も
  /// 記録として残る。旧セーブは0。
  int youthMatchApps;

  /// ユース練習試合の通算得点数。旧セーブは0。
  int youthMatchGoals;

  /// 直近のユース練習試合の評点(10点満点)。未出場・旧セーブは0。
  double lastYouthMatchRating;

  /// メンター(指導役)に指名されたベテラン選手のID。若手選手の成長率に
  /// ボーナスを与える代わりに、メンター自身の士気も少し上がる。
  String? mentorId;

  /// ピンポイントで重点的に伸ばしたい能力値。設定するとチーム/個別の
  /// トレーニング方針とは別に、この1項目の成長確率が上乗せされる。
  String? drillAttributeKey;

  /// 2つ目のピンポイント特訓ドリル(任意)。[drillAttributeKey]より成長率は
  /// 抑えめだが、同時に2項目を重点的に伸ばせる。
  String? drillAttributeKey2;

  /// 特性未保有の選手に対し、週次トレーニングで狙って習得させたい選手特性
  /// ([PlayerTrait])。技術カテゴリの特性のみ指定できる(才能・性格の特性は
  /// 練習では身につかないため)。設定すると毎週低確率でこの特性を獲得する
  /// 判定が行われ、選手の能力値・年齢がその特性に適性が高いほど成功率が
  /// 上がる。既に特性を持つ選手には効果がない。
  PlayerTrait? traitTrainingTarget;

  /// 特性未保有の選手に対し、メンター(チームメイト)や監督との関わりを
  /// 通じて習得させたい性格カテゴリの選手特性。設定すると、有効なメンターが
  /// いる週・監督が個別に声をかけた週に、低確率でこの特性を獲得する判定が
  /// 行われる。既に特性を持つ選手には効果がない。
  PlayerTrait? personalityTraitTrainingTarget;

  /// 複数のトレーニング方針を登録し、週次トレーニングのたびに順番に
  /// 切り替える個別ローテーション。設定されている間は[individualFocus]
  /// より優先される。空またはnullならローテーションを使わない。
  List<TrainingFocus>? focusRotation;

  /// [focusRotation]の中で次に適用する方針のインデックス。
  int rotationWeekIndex;

  /// ポジションコンバート特訓(TrainingFocus.positionSwitch)で目標とする
  /// ポジション(Position.name)。設定した場合、生成時に偶然割り当てられた
  /// secondaryPositionsとは関係なく、このポジションの慣れ度を集中的に
  /// 伸ばす。慣れ度が上限(100)に達するとsecondaryPositionsへ自動的に
  /// 追加され、実際にそのポジションで起用できるようになる。
  String? trainingConvertTargetPosition;

  /// 育成プラン: この選手を将来どのロール(プレースタイル)に育てたいか。
  /// 設定すると、週次トレーニングでそのロールの重視能力値
  /// ([PlayerRoleInfo.keyAttributes])が優先的に伸びる追加の成長判定が
  /// 行われる。選手のポジション大分類に合ったロールのみ設定できる。
  PlayerRole? developmentTargetRole;

  /// 選手特性(格上キラー/横綱相撲/波がある)。持たない選手も多い(null)。
  PlayerTrait? trait;

  /// 直近の試合での特性由来のパフォーマンス倍率(1.0で補正なし)。
  /// [MatchEngine]が試合開始時に算出する一時的な値で、セーブデータには
  /// 保存しない(次の試合ごとに改めて算出される)。
  double matchFormMultiplier = 1.0;

  /// 今試合で既に[matchFormMultiplier]を算出済みかどうか。前後半を通して
  /// 同じ値を使うためのフラグで、セーブデータには保存しない。前半に出場
  /// しなかった選手(後半途中出場の交代選手等)が後半開始時に初めて
  /// [MatchEngine.lineupOf]に現れた場合のみ、この試合用に改めて算出する。
  bool matchFormRolledThisMatch = false;

  /// この半(前半・後半)で既に警告(イエローカード)を受けているかどうか。
  /// [MatchEngine.simulateMinutes]が半の開始時にリセットする一時的なフラグで、
  /// セーブデータには保存しない。同じ半でもう一度カード対象に選ばれた際、
  /// 2枚目の警告を退場(レッドカード)として扱うために使う。
  bool yellowCardedThisHalf = false;

  /// 成長タイプ(早熟/標準/大器晩成)。年齢による伸びやすさ・衰え始める
  /// 時期の傾向を左右する。
  PlayerGrowthType growthType;

  /// 直近の週次トレーニングで「才能開花」(複数属性がまとまって伸びる
  /// 特別な成長)が発生したかどうか。[TrainingEngine]が週次トレーニング
  /// のたびに設定し直す一時的なフラグで、セーブデータには保存しない。
  bool hadBreakthroughThisWeek = false;

  /// 直近の週次トレーニングで特性トレーニングにより獲得した選手特性
  /// (獲得しなかった場合はnull)。[TrainingEngine]が週次トレーニングの
  /// たびに設定し直す一時的なフラグで、セーブデータには保存しない。
  PlayerTrait? acquiredTraitThisWeek;

  Player({
    required this.id,
    required this.name,
    required this.age,
    required this.position,
    required this.potential,
    List<Position>? secondaryPositions,
    Map<String, int>? attributes,
    this.fatigue = 0,
    this.morale = 75,
    this.injuryWeeks = 0,
    this.injuryType,
    Map<String, int>? injuryHistoryCounts,
    this.yellowCards = 0,
    this.suspendedMatches = 0,
    this.careerAppearances = 0,
    this.careerGoals = 0,
    this.individualFocus,
    this.wage = 20,
    this.contractYearsRemaining = 2,
    this.personality = PlayerPersonality.balanced,
    this.happiness = 70,
    this.reassureCooldownWeeks = 0,
    this.talkCooldownWeeks = 0,
    this.isLoan = false,
    this.loanWeeksRemaining = 0,
    this.loanBuyOptionFee,
    this.releaseClause,
    this.internationalDutyWeeksRemaining = 0,
    this.duty = PlayerDuty.support,
    this.squadStatus = SquadStatus.regular,
    this.isTransferListed = false,
    this.loanedOutWeeksRemaining = 0,
    this.loanedOutToClubName,
    this.originClubName,
    this.appearanceFee = 0,
    this.role = PlayerRole.standard,
    Map<String, int>? positionFamiliarity,
    this.matchSharpness = 80,
    this.youthMatchApps = 0,
    this.youthMatchGoals = 0,
    this.lastYouthMatchRating = 0,
    this.mentorId,
    this.drillAttributeKey,
    this.drillAttributeKey2,
    this.traitTrainingTarget,
    this.personalityTraitTrainingTarget,
    this.focusRotation,
    this.rotationWeekIndex = 0,
    this.trainingConvertTargetPosition,
    this.developmentTargetRole,
    this.trait,
    this.growthType = PlayerGrowthType.balanced,
  })  : secondaryPositions = secondaryPositions ?? [],
        attributes = attributes ?? {for (final k in AttributeKeys.all) k: 50},
        positionFamiliarity = positionFamiliarity ?? {},
        injuryHistoryCounts = injuryHistoryCounts ?? {};

  /// このポジション（主・副とも）を無理なくこなせるか。
  bool canPlay(Position pos) =>
      position == pos || secondaryPositions.contains(pos);

  /// 指定ポジションでの慣れ度(0-100)。主ポジションは常に100。
  int familiarityFor(Position pos) =>
      pos == position ? 100 : (positionFamiliarity[pos.name] ?? 0);

  /// 本職外のポジションで出場した際、慣れ度を積み増す(上限100)。
  void growFamiliarity(Position pos, {int amount = 3}) {
    if (pos == position) return;
    final current = positionFamiliarity[pos.name] ?? 0;
    positionFamiliarity[pos.name] = (current + amount).clamp(0, 100);
  }

  /// 不満度が性格ごとの閾値を下回り、移籍を希望しているかどうか。
  bool get wantsTransfer => happiness < personality.transferRequestThreshold;

  int attributeValue(String key) => attributes[key] ?? 50;

  void setAttributeValue(String key, int value) {
    attributes[key] = value.clamp(1, 99);
  }

  int _weightedAverage(Map<String, int> weights) {
    var total = 0;
    var weightSum = 0;
    weights.forEach((key, weight) {
      total += attributeValue(key) * weight;
      weightSum += weight;
    });
    if (weightSum == 0) return 50;
    return (total / weightSum).round();
  }

  /// 攻撃力（シュート・崩し・オフザボールの複合値）。ひらめき(flair)は
  /// 意表を突く仕掛け、バランス(balance)は競り合い下でのドリブル/仕掛けの
  /// 質に寄与するため軽い重みで加える。
  int get attack => _weightedAverage({
        AttributeKeys.finishing: 3,
        AttributeKeys.longShots: 2,
        AttributeKeys.dribbling: 2,
        AttributeKeys.offTheBall: 2,
        AttributeKeys.composure: 1,
        AttributeKeys.pace: 1,
        AttributeKeys.flair: 1,
        AttributeKeys.balance: 1,
      });

  /// 守備力（対人・ポジショニングの複合値）。集中力(concentration)は
  /// 守備での注意散漫による失点を減らし、勇敢さ(bravery)は際どい競り合い・
  /// 最後の一枚での対応に寄与するため軽い重みで加える。
  int get defense => _weightedAverage({
        AttributeKeys.tackling: 3,
        AttributeKeys.marking: 3,
        AttributeKeys.positioning: 2,
        AttributeKeys.anticipation: 2,
        AttributeKeys.strength: 1,
        AttributeKeys.aggression: 1,
        AttributeKeys.concentration: 1,
        AttributeKeys.bravery: 1,
      });

  /// 技術（パス・ボールコントロールの複合値）。連係(teamwork)は周囲との
  /// コンビネーションプレーの質に寄与するため軽い重みで加える。
  int get technique => _weightedAverage({
        AttributeKeys.passing: 3,
        AttributeKeys.firstTouch: 2,
        AttributeKeys.vision: 2,
        AttributeKeys.technique: 2,
        AttributeKeys.crossing: 1,
        AttributeKeys.decisions: 1,
        AttributeKeys.teamwork: 1,
      });

  /// スタミナ（持久力・運動量の複合値）
  int get stamina => _weightedAverage({
        AttributeKeys.stamina: 3,
        AttributeKeys.naturalFitness: 2,
        AttributeKeys.workRate: 2,
        AttributeKeys.strength: 1,
        AttributeKeys.acceleration: 1,
      });

  /// ゴールキーピング(反応・ハイボール処理などの複合値)。GK以外にはあまり
  /// 意味を持たないが、GKの総合力・市場価値を正しく反映するために必要。
  int get goalkeeping => _weightedAverage({
        AttributeKeys.reflexes: 3,
        AttributeKeys.handling: 3,
        AttributeKeys.oneOnOnes: 2,
        AttributeKeys.aerialReach: 2,
        AttributeKeys.commandOfArea: 1,
        AttributeKeys.kicking: 1,
      });

  int get overall => position == Position.gk
      ? ((goalkeeping * 2 + defense + stamina) / 4).round()
      : ((attack + defense + technique + stamina) / 4).round();

  bool get isInjured => injuryWeeks > 0;

  bool get isSuspended => suspendedMatches > 0;

  bool get isOnInternationalDuty => internationalDutyWeeksRemaining > 0;

  /// 他クラブへローン放出中で、自クラブの試合には出場できない状態かどうか。
  bool get isLoanedOut => loanedOutWeeksRemaining > 0;

  /// [marketValue]の算出根拠となる各内訳値。選手詳細画面で市場価値の
  /// 内訳を説明するために使う(marketValue自体もこれを使って計算する)。
  ({
    double base,
    double potentialBonus,
    double ageFactor,
    double personalityFactor,
    double leadershipFactor,
  }) get marketValueBreakdown {
    final ovr = (overall - 40).clamp(0, 60);
    final base = pow(ovr, 1.8) * 3;
    final potentialBonus = (potential - overall).clamp(0, 40) * 15;
    double ageFactor;
    if (age <= 21) {
      ageFactor = 1.4;
    } else if (age <= 27) {
      ageFactor = 1.1;
    } else if (age <= 30) {
      ageFactor = 0.8;
    } else {
      ageFactor = 0.4;
    }
    // リーダーシップが高い選手は主将候補として、低い選手はロッカールームへの
    // 悪影響を懸念されてわずかに評価が振れる(±10%)。
    final leadershipFactor = 1 +
        (attributeValue(AttributeKeys.leadership) - 50).clamp(-50, 50) / 500;
    return (
      base: base.toDouble(),
      potentialBonus: potentialBonus.toDouble(),
      ageFactor: ageFactor,
      personalityFactor: personality.marketValueFactor,
      leadershipFactor: leadershipFactor,
    );
  }

  /// 想定移籍金（万円）。年齢・現在能力・伸びしろから概算する。
  int get marketValue {
    final b = marketValueBreakdown;
    final value = (b.base + b.potentialBonus) *
        b.ageFactor *
        b.personalityFactor *
        b.leadershipFactor;
    return value.round().clamp(50, 20000);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'position': position.name,
        'secondaryPositions': secondaryPositions.map((p) => p.name).toList(),
        // AttributeKeys.all の並び順に沿った値だけの配列で保存する(キー名を
        // 省いた分だけセーブデータを大幅に圧縮できる)。並び順は
        // AttributeKeys.all に追記する形でのみ変更し、既存項目の順序を
        // 変えてはならない(変えると旧セーブの値が別の属性にずれてしまう)。
        'attributes': [for (final k in AttributeKeys.all) attributes[k] ?? 50],
        'potential': potential,
        'fatigue': fatigue,
        'morale': morale,
        'injuryWeeks': injuryWeeks,
        'injuryType': injuryType?.name,
        'injuryHistoryCounts': injuryHistoryCounts,
        'yellowCards': yellowCards,
        'suspendedMatches': suspendedMatches,
        'careerAppearances': careerAppearances,
        'careerGoals': careerGoals,
        'individualFocus': individualFocus?.name,
        'wage': wage,
        'contractYearsRemaining': contractYearsRemaining,
        'personality': personality.name,
        'happiness': happiness,
        'reassureCooldownWeeks': reassureCooldownWeeks,
        'talkCooldownWeeks': talkCooldownWeeks,
        'isLoan': isLoan,
        'loanWeeksRemaining': loanWeeksRemaining,
        'loanBuyOptionFee': loanBuyOptionFee,
        'releaseClause': releaseClause,
        'internationalDutyWeeksRemaining': internationalDutyWeeksRemaining,
        'duty': duty.name,
        'squadStatus': squadStatus.name,
        'isTransferListed': isTransferListed,
        'loanedOutWeeksRemaining': loanedOutWeeksRemaining,
        'loanedOutToClubName': loanedOutToClubName,
        'originClubName': originClubName,
        'appearanceFee': appearanceFee,
        'role': role.name,
        'positionFamiliarity': positionFamiliarity,
        'matchSharpness': matchSharpness,
        'youthMatchApps': youthMatchApps,
        'youthMatchGoals': youthMatchGoals,
        'lastYouthMatchRating': lastYouthMatchRating,
        'mentorId': mentorId,
        'drillAttributeKey': drillAttributeKey,
        'drillAttributeKey2': drillAttributeKey2,
        'traitTrainingTarget': traitTrainingTarget?.name,
        'personalityTraitTrainingTarget': personalityTraitTrainingTarget?.name,
        'focusRotation': focusRotation?.map((f) => f.name).toList(),
        'rotationWeekIndex': rotationWeekIndex,
        'trainingConvertTargetPosition': trainingConvertTargetPosition,
        'developmentTargetRole': developmentTargetRole?.name,
        'trait': trait?.name,
        'growthType': growthType.name,
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    final rawAttributes = json['attributes'];
    final Map<String, int> attributes;
    if (rawAttributes is List) {
      // 新形式: AttributeKeys.all の並び順の値配列。
      attributes = {
        for (int i = 0; i < AttributeKeys.all.length; i++)
          AttributeKeys.all[i]:
              (i < rawAttributes.length ? rawAttributes[i] as int? : null) ??
                  50,
      };
    } else if (rawAttributes is Map) {
      // 旧形式: キー名付きのMap(過去のセーブとの互換性のため引き続き読める)。
      attributes = {
        for (final k in AttributeKeys.all) k: (rawAttributes[k] as int?) ?? 50,
      };
    } else {
      attributes = _migrateLegacyAttributes(json);
    }

    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      age: json['age'] as int,
      position: parsePosition(json['position'] as String),
      secondaryPositions: (json['secondaryPositions'] as List?)
              ?.map((e) => parsePosition(e as String))
              .toList() ??
          [],
      attributes: attributes,
      potential: json['potential'] as int,
      fatigue: json['fatigue'] as int? ?? 0,
      morale: json['morale'] as int? ?? 75,
      injuryWeeks: json['injuryWeeks'] as int? ?? 0,
      injuryType: json['injuryType'] == null
          ? null
          : enumFromName(
              InjuryType.values,
              json['injuryType'] as String?,
              InjuryType.bruise,
            ),
      injuryHistoryCounts: (json['injuryHistoryCounts'] as Map?)?.map(
            (k, v) => MapEntry(k as String, v as int),
          ) ??
          {},
      yellowCards: json['yellowCards'] as int? ?? 0,
      suspendedMatches: json['suspendedMatches'] as int? ?? 0,
      careerAppearances: json['careerAppearances'] as int? ?? 0,
      careerGoals: json['careerGoals'] as int? ?? 0,
      individualFocus: json['individualFocus'] == null
          ? null
          : enumFromName(
              TrainingFocus.values,
              json['individualFocus'] as String?,
              TrainingFocus.rest,
            ),
      wage: json['wage'] as int? ?? 20,
      contractYearsRemaining: _migrateContractYears(json),
      personality: enumFromName(
        PlayerPersonality.values,
        json['personality'] as String?,
        PlayerPersonality.balanced,
      ),
      happiness: json['happiness'] as int? ?? 70,
      reassureCooldownWeeks: json['reassureCooldownWeeks'] as int? ?? 0,
      talkCooldownWeeks: json['talkCooldownWeeks'] as int? ?? 0,
      isLoan: json['isLoan'] as bool? ?? false,
      loanWeeksRemaining: json['loanWeeksRemaining'] as int? ?? 0,
      loanBuyOptionFee: json['loanBuyOptionFee'] as int?,
      releaseClause: json['releaseClause'] as int?,
      internationalDutyWeeksRemaining:
          json['internationalDutyWeeksRemaining'] as int? ?? 0,
      duty: enumFromName(
        PlayerDuty.values,
        json['duty'] as String?,
        PlayerDuty.support,
      ),
      squadStatus: enumFromName(
        SquadStatus.values,
        json['squadStatus'] as String?,
        SquadStatus.regular,
      ),
      isTransferListed: json['isTransferListed'] as bool? ?? false,
      loanedOutWeeksRemaining: json['loanedOutWeeksRemaining'] as int? ?? 0,
      loanedOutToClubName: json['loanedOutToClubName'] as String?,
      originClubName: json['originClubName'] as String?,
      appearanceFee: json['appearanceFee'] as int? ?? 0,
      role: enumFromName(
        PlayerRole.values,
        json['role'] as String?,
        PlayerRole.standard,
      ),
      positionFamiliarity: (json['positionFamiliarity'] as Map?)?.map(
            (k, v) => MapEntry(k as String, v as int),
          ) ??
          {},
      matchSharpness: json['matchSharpness'] as int? ?? 80,
      youthMatchApps: json['youthMatchApps'] as int? ?? 0,
      youthMatchGoals: json['youthMatchGoals'] as int? ?? 0,
      lastYouthMatchRating:
          (json['lastYouthMatchRating'] as num?)?.toDouble() ?? 0,
      mentorId: json['mentorId'] as String?,
      drillAttributeKey: json['drillAttributeKey'] as String?,
      drillAttributeKey2: json['drillAttributeKey2'] as String?,
      traitTrainingTarget: _technicalTraitTargetFromJson(
        json['traitTrainingTarget'] as String?,
      ),
      personalityTraitTrainingTarget: _personalityTraitTargetFromJson(
        json['personalityTraitTrainingTarget'] as String?,
      ),
      focusRotation: (json['focusRotation'] as List?)
          ?.map(
            (e) => enumFromName(
              TrainingFocus.values,
              e as String?,
              TrainingFocus.rest,
            ),
          )
          .toList(),
      rotationWeekIndex: json['rotationWeekIndex'] as int? ?? 0,
      trainingConvertTargetPosition:
          json['trainingConvertTargetPosition'] as String?,
      developmentTargetRole: json['developmentTargetRole'] == null
          ? null
          : enumFromName(
              PlayerRole.values,
              json['developmentTargetRole'] as String?,
              PlayerRole.standard,
            ),
      trait: json['trait'] == null
          ? null
          : enumFromName(
              PlayerTrait.values,
              json['trait'] as String?,
              PlayerTrait.streaky,
            ),
      growthType: enumFromName(
        PlayerGrowthType.values,
        json['growthType'] as String?,
        PlayerGrowthType.balanced,
      ),
    );
  }

  /// 旧セーブ（attack/defense/technique/staminaの4値のみ）からの移行用。
  /// 該当する系統の詳細項目にそれぞれの値を割り当て、それ以外は50で埋める。
  static Map<String, int> _migrateLegacyAttributes(Map<String, dynamic> json) {
    final legacyAttack = json['attack'] as int? ?? 50;
    final legacyDefense = json['defense'] as int? ?? 50;
    final legacyTechnique = json['technique'] as int? ?? 50;
    final legacyStamina = json['stamina'] as int? ?? 50;

    final map = {for (final k in AttributeKeys.all) k: 50};
    for (final k in [
      AttributeKeys.finishing,
      AttributeKeys.longShots,
      AttributeKeys.dribbling,
      AttributeKeys.offTheBall,
    ]) {
      map[k] = legacyAttack;
    }
    for (final k in [
      AttributeKeys.tackling,
      AttributeKeys.marking,
      AttributeKeys.positioning,
      AttributeKeys.anticipation,
    ]) {
      map[k] = legacyDefense;
    }
    for (final k in [
      AttributeKeys.passing,
      AttributeKeys.firstTouch,
      AttributeKeys.vision,
      AttributeKeys.technique,
    ]) {
      map[k] = legacyTechnique;
    }
    for (final k in [
      AttributeKeys.stamina,
      AttributeKeys.naturalFitness,
      AttributeKeys.workRate,
    ]) {
      map[k] = legacyStamina;
    }
    return map;
  }

  /// 旧セーブ(契約を週数で管理していた版)からの移行用。新フィールドが
  /// あればそれを使い、なければ旧フィールドの週数を年数に丸めて引き継ぐ。
  static int _migrateContractYears(Map<String, dynamic> json) {
    final years = json['contractYearsRemaining'] as int?;
    if (years != null) return years;
    final legacyWeeks = json['contractWeeksRemaining'] as int?;
    if (legacyWeeks == null) return 2;
    if (legacyWeeks <= 0) return 0;
    return (legacyWeeks / 52).ceil().clamp(1, 10);
  }
}
