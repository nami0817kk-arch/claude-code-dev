import '../l10n/tr.dart';

enum TrainingFocus { balanced, attack, defense, fitness, rest, positionSwitch }

extension TrainingFocusLabel on TrainingFocus {
  String get label {
    switch (this) {
      case TrainingFocus.balanced:
        return Tr.pick('全体練習', 'General');
      case TrainingFocus.attack:
        return Tr.pick('攻撃強化', 'Attacking');
      case TrainingFocus.defense:
        return Tr.pick('守備強化', 'Defending');
      case TrainingFocus.fitness:
        return Tr.pick('体力強化', 'Fitness');
      case TrainingFocus.rest:
        return Tr.pick('休養', 'Rest');
      case TrainingFocus.positionSwitch:
        return Tr.pick('ポジションコンバート', 'Position Retraining');
    }
  }

  String get description {
    switch (this) {
      case TrainingFocus.balanced:
        return Tr.pick('ポジションに応じて攻守をバランス良く伸ばす。特化練習ほど尖らないが、スカッド全体が着実に成長する既定の方針。',
            'Develops attack and defence evenly by position. Less pointed than the specialised sessions, but the default that grows the whole squad steadily.');
      case TrainingFocus.attack:
        return Tr.pick('FW・MFの攻撃力と技術が伸びやすくなる。疲労はやや増加。',
            'Attack and technique improve faster for forwards and midfielders. Fatigue rises a little.');
      case TrainingFocus.defense:
        return Tr.pick('DF・GKの守備力と技術が伸びやすくなる。疲労はやや増加。',
            'Defence and technique improve faster for defenders and keepers. Fatigue rises a little.');
      case TrainingFocus.fitness:
        return Tr.pick('全選手のスタミナが伸びやすくなる。疲労は少し増加。',
            'Stamina improves faster across the squad. Fatigue rises slightly.');
      case TrainingFocus.rest:
        return Tr.pick('疲労を大きく回復し、士気も上がる。成長は控えめ。',
            'Recovers a lot of fatigue and lifts morale. Little growth.');
      case TrainingFocus.positionSwitch:
        return Tr.pick('試合に出場しなくても、対応可能ポジションへの慣れ度がゆっくり伸びる。疲労はやや増加。',
            'Familiarity with new positions builds slowly even without playing. Fatigue rises a little.');
    }
  }
}

/// トレーニングの強度。成長速度と疲労蓄積・怪我リスクのトレードオフを調整する。
enum TrainingIntensity { light, normal, intense }

extension TrainingIntensityInfo on TrainingIntensity {
  String get label => switch (this) {
        TrainingIntensity.light => Tr.pick('軽め', 'Light'),
        TrainingIntensity.normal => Tr.pick('通常', 'Normal'),
        TrainingIntensity.intense => Tr.pick('追い込み', 'Intense'),
      };

  String get description => switch (this) {
        TrainingIntensity.light => Tr.pick('成長は緩やかだが、疲労・怪我リスクを抑えられる。',
            'Slower growth, but keeps fatigue and injury risk down.'),
        TrainingIntensity.normal => Tr.pick(
            '標準的な成長速度と疲労・怪我リスク。', 'Standard growth, fatigue and injury risk.'),
        TrainingIntensity.intense => Tr.pick('成長が早まる代わりに、疲労と練習中の怪我リスクが増す。',
            'Faster growth, at the cost of more fatigue and more injuries in training.'),
      };

  /// 成長確率・疲労増加・練習中負傷リスクへの倍率。
  double get factor => switch (this) {
        TrainingIntensity.light => 0.7,
        TrainingIntensity.normal => 1.0,
        TrainingIntensity.intense => 1.4,
      };
}
