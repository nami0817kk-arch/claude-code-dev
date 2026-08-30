import '../models/team.dart';
import 'training_engine.dart';

/// 育成アドバイスの種類。並び順がそのまま重要度(上ほど急ぎ)になる。
enum AdviceKind { highFatigue, lowSharpness, unusedPotential, noMentor }

extension AdviceKindInfo on AdviceKind {
  String get label => switch (this) {
        AdviceKind.highFatigue => '疲労',
        AdviceKind.lowSharpness => '実戦感覚',
        AdviceKind.unusedPotential => '伸びしろ',
        AdviceKind.noMentor => 'メンター',
      };
}

/// 育成アドバイス1件(対象選手+提案文)。
class DevelopmentAdvice {
  final AdviceKind kind;
  final String playerId;
  final String playerName;
  final String message;

  const DevelopmentAdvice({
    required this.kind,
    required this.playerId,
    required this.playerName,
    required this.message,
  });
}

/// コーチ陣がスカッドを見渡し、育成面で手を打つべき選手を挙げる
/// アドバイザー。トレーニング画面の提案カードに表示する。
/// 押しつけはせず、既にケアされている選手(ドリル設定済み等)は挙げない。
class DevelopmentAdvisor {
  /// この疲労以上で休養を勧める。
  static const int fatigueThreshold = 75;

  /// この実戦感覚未満で出場機会の確保を勧める(成長ペナルティと同じ閾値)。
  static const int sharpnessThreshold = 40;

  /// 「伸びしろ豊富」とみなす潜在能力と現在能力の差。
  static const int potentialGapThreshold = 10;

  /// 伸びしろ提案・メンター提案の対象になる年齢の上限。
  static const int youngAgeLimit = 21;
  static const int mentorAgeLimit = 23;

  /// 一度に表示するアドバイスの上限(多すぎると読まれないため)。
  static const int maxAdvices = 6;

  static List<DevelopmentAdvice> advise(Team team) {
    final advices = <DevelopmentAdvice>[];
    final hasMentorCandidate =
        team.players.any((p) => p.age >= TrainingEngine.minMentorAge);

    for (final p in team.players) {
      if (p.isLoanedOut) continue;
      if (p.fatigue >= fatigueThreshold) {
        advices.add(
          DevelopmentAdvice(
            kind: AdviceKind.highFatigue,
            playerId: p.id,
            playerName: p.name,
            message: '疲労${p.fatigue}。休養方針やローテーションで回復を',
          ),
        );
      }
      if (!p.isInjured && p.matchSharpness < sharpnessThreshold) {
        advices.add(
          DevelopmentAdvice(
            kind: AdviceKind.lowSharpness,
            playerId: p.id,
            playerName: p.name,
            message: '実戦感覚${p.matchSharpness}で成長が鈍っている。'
                '出場機会かローン武者修行を',
          ),
        );
      }
      if (p.age <= youngAgeLimit &&
          p.potential - p.overall >= potentialGapThreshold &&
          p.drillAttributeKey == null &&
          p.developmentTargetRole == null) {
        advices.add(
          DevelopmentAdvice(
            kind: AdviceKind.unusedPotential,
            playerId: p.id,
            playerName: p.name,
            message: '伸びしろ${p.potential - p.overall}が手つかず。'
                '特訓ドリルか育成プランで方向付けを',
          ),
        );
      }
      if (p.age <= mentorAgeLimit && p.mentorId == null && hasMentorCandidate) {
        advices.add(
          DevelopmentAdvice(
            kind: AdviceKind.noMentor,
            playerId: p.id,
            playerName: p.name,
            message: 'メンター未設定。ベテランを付けると成長率が上がる',
          ),
        );
      }
    }

    advices.sort((a, b) => a.kind.index.compareTo(b.kind.index));
    return advices.length > maxAdvices
        ? advices.sublist(0, maxAdvices)
        : advices;
  }
}
