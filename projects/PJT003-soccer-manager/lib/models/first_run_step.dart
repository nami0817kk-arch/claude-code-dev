import '../l10n/app_localizations.dart';

/// 初めて遊ぶ人に、読ませずに一連の流れを一周してもらうためのステップ。
///
/// このゲームは画面が32枚あり、初見では「何から触ればいいか」が分からない。
/// マネジメントシムは初日の離脱が大きく、最初の数分で手応えに到達できるかが
/// 続けてもらえるかを分ける。そこで「スタメンを見る → 練習方針を決める →
/// 試合を戦う → 選手が伸びたのを確認する」という、このゲームの週次サイクル
/// そのものを最短でなぞらせる。
///
/// 4つ終えるとホーム画面のカードは自動的に消える。飛ばしたい人のために
/// 手動で閉じることもできる。
enum FirstRunStep {
  /// 誰が出るのかを把握する。
  lineup,

  /// 週次で選手を伸ばす手段があることを知る。
  training,

  /// 実際に試合を戦う。ライブ観戦の存在に気付いてもらう狙いも兼ねる。
  match,

  /// 育てた結果が数値で返ってくることを見届ける。ここが最初の手応えになる。
  growth,
}

extension FirstRunStepInfo on FirstRunStep {
  String label(AppLocalizations l10n) => switch (this) {
        FirstRunStep.lineup => l10n.firstRunLineupLabel,
        FirstRunStep.training => l10n.firstRunTrainingLabel,
        FirstRunStep.match => l10n.firstRunMatchLabel,
        FirstRunStep.growth => l10n.firstRunGrowthLabel,
      };

  String description(AppLocalizations l10n) => switch (this) {
        FirstRunStep.lineup => l10n.firstRunLineupDesc,
        FirstRunStep.training => l10n.firstRunTrainingDesc,
        FirstRunStep.match => l10n.firstRunMatchDesc,
        FirstRunStep.growth => l10n.firstRunGrowthDesc,
      };

  /// このステップから飛ばす先の画面。ホーム画面のカードから直接遷移させる。
  String actionLabel(AppLocalizations l10n) => switch (this) {
        FirstRunStep.lineup => l10n.firstRunLineupAction,
        FirstRunStep.training => l10n.firstRunTrainingAction,
        FirstRunStep.match => l10n.firstRunMatchAction,
        FirstRunStep.growth => l10n.firstRunGrowthAction,
      };
}
