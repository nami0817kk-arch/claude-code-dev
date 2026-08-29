import 'player.dart';

/// 週次トレーニングの前後で選手1人に起きた変化のスナップショット。
/// UI側でトレーニング結果のサマリー表示に使う(セーブデータには保存しない)。
class PlayerGrowthSummary {
  final String playerId;
  final String playerName;
  final int overallBefore;
  final int overallAfter;

  /// トレーニングで変化した属性のみを含む(キー: 属性キー, 値: 変化量)。
  final Map<String, int> attributeDeltas;

  /// この週に「才能開花」(ブレイクスルー)が発生したかどうか。
  final bool isBreakthrough;

  /// この週に特性トレーニングで新たに獲得した選手特性(獲得していなければnull)。
  final PlayerTrait? acquiredTrait;

  const PlayerGrowthSummary({
    required this.playerId,
    required this.playerName,
    required this.overallBefore,
    required this.overallAfter,
    required this.attributeDeltas,
    this.isBreakthrough = false,
    this.acquiredTrait,
  });

  int get overallDelta => overallAfter - overallBefore;
}
