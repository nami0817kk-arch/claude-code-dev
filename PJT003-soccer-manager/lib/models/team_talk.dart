import 'player.dart';

/// 試合前・ハーフタイムに監督が飛ばす檄のトーン。士気(morale)に一時的な
/// 補正を与える。効果の大きさは選手の性格(結果感応度)によって変わる。
enum TeamTalkTone { encouraging, calm, critical }

extension TeamTalkToneInfo on TeamTalkTone {
  String get label => switch (this) {
        TeamTalkTone.encouraging => '鼓舞する',
        TeamTalkTone.calm => '冷静に指示する',
        TeamTalkTone.critical => '叱咤する',
      };

  String get description => switch (this) {
        TeamTalkTone.encouraging => '選手を鼓舞し、士気を大きく高める。',
        TeamTalkTone.calm => '落ち着いた指示で、士気を穏やかに高める。',
        TeamTalkTone.critical => '厳しく発破をかける。奮起する選手もいれば、反発して士気を落とす選手もいる。',
      };

  /// 士気変動のベース値。実際の変動は選手ごとの結果感応度(resultSensitivity)
  /// を掛け合わせて決まる。
  int get baseMoraleDelta => switch (this) {
        TeamTalkTone.encouraging => 6,
        TeamTalkTone.calm => 3,
        TeamTalkTone.critical => -2,
      };

  /// 選手の性格を踏まえた実際の士気変動ベース値。「厳しく叱咤する」は
  /// description通り一枚岩の効果ではなく、気性が激しい・野心的な選手には
  /// 逆に火がつき、それ以外の選手は素直に士気を落とす。
  int baseMoraleDeltaFor(PlayerPersonality personality) {
    if (this != TeamTalkTone.critical) return baseMoraleDelta;
    switch (personality) {
      case PlayerPersonality.temperamental:
      case PlayerPersonality.ambitious:
        return 4;
      default:
        return baseMoraleDelta;
    }
  }
}
