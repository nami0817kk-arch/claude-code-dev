import '../models/first_run_step.dart';
import '../models/save_game.dart';

/// 初回ガイドの進捗を、セーブデータから組み立てる。
///
/// 「画面を開いたか」だけをセーブに記録し、試合や成長のように既存の
/// カウンタから判定できるものは記録を増やさず導出している。記録する項目を
/// 増やすほど旧セーブとの互換や整合の面倒が増えるため。
class FirstRunGuide {
  const FirstRunGuide._();

  /// このステップを踏み終えているか。
  static bool isDone(SaveGame save, FirstRunStep step) {
    switch (step) {
      case FirstRunStep.lineup:
      case FirstRunStep.growth:
        // 画面を開いたかどうかでしか判定できないので、記録を見る。
        return save.firstRunStepsSeen.contains(step.name);
      case FirstRunStep.training:
        // 今週分を消化済みなら開いた記録が無くても達成扱いにする。
        // 自動トレーニング設定で消化された場合を取りこぼさないため。
        return save.trainingDoneThisWeek ||
            save.firstRunStepsSeen.contains(step.name);
      case FirstRunStep.match:
        // 1試合でも結果が残っていれば達成。旧セーブから再開した人にも
        // いきなり「最初の試合を戦う」とは出したくない。
        return save.careerWins + save.careerDraws + save.careerLosses > 0;
    }
  }

  /// 次に案内すべきステップ。すべて終えていれば null。
  static FirstRunStep? nextStep(SaveGame save) {
    for (final step in FirstRunStep.values) {
      if (!isDone(save, step)) return step;
    }
    return null;
  }

  static int doneCount(SaveGame save) =>
      FirstRunStep.values.where((s) => isDone(save, s)).length;

  /// ガイドカードを表示すべきか。
  ///
  /// 全ステップ完了、または本人が閉じた場合は二度と出さない。
  /// 途中まで進んだ状態のセーブから再開したときは、残りだけを案内する。
  static bool shouldShow(SaveGame save) =>
      !save.firstRunGuideDismissed && nextStep(save) != null;
}
