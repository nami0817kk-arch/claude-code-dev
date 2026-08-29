enum TrainingFocus { attack, defense, fitness, rest, positionSwitch }

extension TrainingFocusLabel on TrainingFocus {
  String get label {
    switch (this) {
      case TrainingFocus.attack:
        return '攻撃強化';
      case TrainingFocus.defense:
        return '守備強化';
      case TrainingFocus.fitness:
        return '体力強化';
      case TrainingFocus.rest:
        return '休養';
      case TrainingFocus.positionSwitch:
        return 'ポジションコンバート';
    }
  }

  String get description {
    switch (this) {
      case TrainingFocus.attack:
        return 'FW・MFの攻撃力と技術が伸びやすくなる。疲労はやや増加。';
      case TrainingFocus.defense:
        return 'DF・GKの守備力と技術が伸びやすくなる。疲労はやや増加。';
      case TrainingFocus.fitness:
        return '全選手のスタミナが伸びやすくなる。疲労は少し増加。';
      case TrainingFocus.rest:
        return '疲労を大きく回復し、士気も上がる。成長は控えめ。';
      case TrainingFocus.positionSwitch:
        return '試合に出場しなくても、対応可能ポジションへの慣れ度がゆっくり伸びる。疲労はやや増加。';
    }
  }
}

/// トレーニングの強度。成長速度と疲労蓄積・怪我リスクのトレードオフを調整する。
enum TrainingIntensity { light, normal, intense }

extension TrainingIntensityInfo on TrainingIntensity {
  String get label => switch (this) {
        TrainingIntensity.light => '軽め',
        TrainingIntensity.normal => '通常',
        TrainingIntensity.intense => '追い込み',
      };

  String get description => switch (this) {
        TrainingIntensity.light => '成長は緩やかだが、疲労・怪我リスクを抑えられる。',
        TrainingIntensity.normal => '標準的な成長速度と疲労・怪我リスク。',
        TrainingIntensity.intense => '成長が早まる代わりに、疲労と練習中の怪我リスクが増す。',
      };

  /// 成長確率・疲労増加・練習中負傷リスクへの倍率。
  double get factor => switch (this) {
        TrainingIntensity.light => 0.7,
        TrainingIntensity.normal => 1.0,
        TrainingIntensity.intense => 1.4,
      };
}
