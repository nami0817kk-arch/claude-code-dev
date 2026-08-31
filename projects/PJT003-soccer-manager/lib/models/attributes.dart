import '../l10n/tr.dart';

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

  /// 能力値キーごとの (日本語, 英語) の対。
  ///
  /// ラベルを直接持たずに対で持つのは、`const` を保ったまま表示時点の言語で
  /// 選べるようにするため。`static final` で組み立ててしまうと最初のアクセス時に
  /// 言語が固定され、設定で切り替えても反映されなくなる。
  static const Map<String, ({String ja, String en})> _labels = {
    corners: (ja: 'コーナーキック', en: 'Corners'),
    crossing: (ja: 'クロス', en: 'Crossing'),
    dribbling: (ja: 'ドリブル', en: 'Dribbling'),
    finishing: (ja: 'フィニッシュ', en: 'Finishing'),
    firstTouch: (ja: 'ファーストタッチ', en: 'First Touch'),
    freeKick: (ja: 'フリーキック', en: 'Free Kicks'),
    heading: (ja: 'ヘディング', en: 'Heading'),
    longShots: (ja: 'ロングシュート', en: 'Long Shots'),
    longThrows: (ja: 'ロングスロー', en: 'Long Throws'),
    marking: (ja: 'マーキング', en: 'Marking'),
    passing: (ja: 'パス', en: 'Passing'),
    penalties: (ja: 'PK', en: 'Penalties'),
    tackling: (ja: 'タックル', en: 'Tackling'),
    technique: (ja: 'テクニック', en: 'Technique'),
    aggression: (ja: '積極性', en: 'Aggression'),
    anticipation: (ja: '予測', en: 'Anticipation'),
    bravery: (ja: '勇敢さ', en: 'Bravery'),
    composure: (ja: '冷静さ', en: 'Composure'),
    concentration: (ja: '集中力', en: 'Concentration'),
    decisions: (ja: '判断力', en: 'Decisions'),
    determination: (ja: '闘志', en: 'Determination'),
    flair: (ja: '閃き', en: 'Flair'),
    leadership: (ja: 'リーダーシップ', en: 'Leadership'),
    offTheBall: (ja: 'オフザボール', en: 'Off the Ball'),
    positioning: (ja: 'ポジショニング', en: 'Positioning'),
    teamwork: (ja: 'チームワーク', en: 'Teamwork'),
    vision: (ja: '視野', en: 'Vision'),
    workRate: (ja: '労働量', en: 'Work Rate'),
    acceleration: (ja: '加速力', en: 'Acceleration'),
    agility: (ja: '敏捷性', en: 'Agility'),
    balance: (ja: 'バランス', en: 'Balance'),
    jumpingReach: (ja: 'ジャンプ力', en: 'Jumping Reach'),
    naturalFitness: (ja: '基礎体力', en: 'Natural Fitness'),
    pace: (ja: 'スピード', en: 'Pace'),
    stamina: (ja: 'スタミナ', en: 'Stamina'),
    strength: (ja: '強さ', en: 'Strength'),
    aerialReach: (ja: '空中対応', en: 'Aerial Reach'),
    commandOfArea: (ja: 'エリア支配', en: 'Command of Area'),
    handling: (ja: 'ハンドリング', en: 'Handling'),
    kicking: (ja: 'キック', en: 'Kicking'),
    oneOnOnes: (ja: '一対一', en: 'One on Ones'),
    reflexes: (ja: '反応速度', en: 'Reflexes'),
  };

  static String labelOf(String key) {
    final pair = _labels[key];
    return pair == null ? key : Tr.pick(pair.ja, pair.en);
  }
}

enum AttributeCategory { technical, mental, physical, goalkeeping }

extension AttributeCategoryInfo on AttributeCategory {
  String get label {
    switch (this) {
      case AttributeCategory.technical:
        return Tr.pick('技術', 'Technical');
      case AttributeCategory.mental:
        return Tr.pick('メンタル', 'Mental');
      case AttributeCategory.physical:
        return Tr.pick('フィジカル', 'Physical');
      case AttributeCategory.goalkeeping:
        return Tr.pick('ゴールキーピング', 'Goalkeeping');
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
