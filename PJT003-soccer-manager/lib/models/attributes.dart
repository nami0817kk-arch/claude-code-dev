/// 選手の詳細能力値のキー定義。
///
/// 技術14 + メンタル14 + フィジカル8 + GK6 = 計42項目。
/// GK項目はゴールキーパー以外では参考値程度の意味しか持たない。
class AttributeKeys {
  // 技術 (Technical)
  static const corners = 'corners';
  static const crossing = 'crossing';
  static const dribbling = 'dribbling';
  static const finishing = 'finishing';
  static const firstTouch = 'firstTouch';
  static const freeKick = 'freeKick';
  static const heading = 'heading';
  static const longShots = 'longShots';
  static const longThrows = 'longThrows';
  static const marking = 'marking';
  static const passing = 'passing';
  static const penalties = 'penalties';
  static const tackling = 'tackling';
  static const technique = 'technique';

  // メンタル (Mental)
  static const aggression = 'aggression';
  static const anticipation = 'anticipation';
  static const bravery = 'bravery';
  static const composure = 'composure';
  static const concentration = 'concentration';
  static const decisions = 'decisions';
  static const determination = 'determination';
  static const flair = 'flair';
  static const leadership = 'leadership';
  static const offTheBall = 'offTheBall';
  static const positioning = 'positioning';
  static const teamwork = 'teamwork';
  static const vision = 'vision';
  static const workRate = 'workRate';

  // フィジカル (Physical)
  static const acceleration = 'acceleration';
  static const agility = 'agility';
  static const balance = 'balance';
  static const jumpingReach = 'jumpingReach';
  static const naturalFitness = 'naturalFitness';
  static const pace = 'pace';
  static const stamina = 'stamina';
  static const strength = 'strength';

  // ゴールキーピング (Goalkeeping)
  static const aerialReach = 'aerialReach';
  static const commandOfArea = 'commandOfArea';
  static const handling = 'handling';
  static const kicking = 'kicking';
  static const oneOnOnes = 'oneOnOnes';
  static const reflexes = 'reflexes';

  static const technical = [
    corners,
    crossing,
    dribbling,
    finishing,
    firstTouch,
    freeKick,
    heading,
    longShots,
    longThrows,
    marking,
    passing,
    penalties,
    tackling,
    technique,
  ];

  static const mental = [
    aggression,
    anticipation,
    bravery,
    composure,
    concentration,
    decisions,
    determination,
    flair,
    leadership,
    offTheBall,
    positioning,
    teamwork,
    vision,
    workRate,
  ];

  static const physical = [
    acceleration,
    agility,
    balance,
    jumpingReach,
    naturalFitness,
    pace,
    stamina,
    strength,
  ];

  static const goalkeeping = [
    aerialReach,
    commandOfArea,
    handling,
    kicking,
    oneOnOnes,
    reflexes,
  ];

  static const all = [...technical, ...mental, ...physical, ...goalkeeping];

  static const Map<String, String> _labels = {
    corners: 'コーナーキック',
    crossing: 'クロス',
    dribbling: 'ドリブル',
    finishing: 'フィニッシュ',
    firstTouch: 'ファーストタッチ',
    freeKick: 'フリーキック',
    heading: 'ヘディング',
    longShots: 'ロングシュート',
    longThrows: 'ロングスロー',
    marking: 'マーキング',
    passing: 'パス',
    penalties: 'PK',
    tackling: 'タックル',
    technique: 'テクニック',
    aggression: '積極性',
    anticipation: '予測',
    bravery: '勇敢さ',
    composure: '冷静さ',
    concentration: '集中力',
    decisions: '判断力',
    determination: '闘志',
    flair: '閃き',
    leadership: 'リーダーシップ',
    offTheBall: 'オフザボール',
    positioning: 'ポジショニング',
    teamwork: 'チームワーク',
    vision: '視野',
    workRate: '労働量',
    acceleration: '加速力',
    agility: '敏捷性',
    balance: 'バランス',
    jumpingReach: 'ジャンプ力',
    naturalFitness: '基礎体力',
    pace: 'スピード',
    stamina: 'スタミナ',
    strength: '強さ',
    aerialReach: '空中対応',
    commandOfArea: 'エリア支配',
    handling: 'ハンドリング',
    kicking: 'キック',
    oneOnOnes: '一対一',
    reflexes: '反応速度',
  };

  static String labelOf(String key) => _labels[key] ?? key;
}

enum AttributeCategory { technical, mental, physical, goalkeeping }

extension AttributeCategoryInfo on AttributeCategory {
  String get label {
    switch (this) {
      case AttributeCategory.technical:
        return '技術';
      case AttributeCategory.mental:
        return 'メンタル';
      case AttributeCategory.physical:
        return 'フィジカル';
      case AttributeCategory.goalkeeping:
        return 'ゴールキーピング';
    }
  }

  List<String> get keys {
    switch (this) {
      case AttributeCategory.technical:
        return AttributeKeys.technical;
      case AttributeCategory.mental:
        return AttributeKeys.mental;
      case AttributeCategory.physical:
        return AttributeKeys.physical;
      case AttributeCategory.goalkeeping:
        return AttributeKeys.goalkeeping;
    }
  }
}
