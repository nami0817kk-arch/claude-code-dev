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
  String get label => switch (this) {
        FirstRunStep.lineup => 'スタメンを確認する',
        FirstRunStep.training => '今週の練習方針を決める',
        FirstRunStep.match => '最初の試合を戦う',
        FirstRunStep.growth => '選手の成長を確かめる',
      };

  String get description => switch (this) {
        FirstRunStep.lineup =>
          '誰がピッチに立つのかを見てみましょう。並びは後からいつでも変えられます。',
        FirstRunStep.training =>
          '練習方針は選手の伸び方を変えます。迷ったら「全体練習」で構いません。',
        FirstRunStep.match =>
          '「ライブで戦う」を選ぶと、決定機ごとにあなたが判断を下せます。',
        FirstRunStep.growth =>
          'スカッドから選手を開くと、能力の推移グラフで伸びが確認できます。',
      };

  /// このステップから飛ばす先の画面。ホーム画面のカードから直接遷移させる。
  String get actionLabel => switch (this) {
        FirstRunStep.lineup => 'スタメンへ',
        FirstRunStep.training => 'トレーニングへ',
        FirstRunStep.match => '試合へ',
        FirstRunStep.growth => 'スカッドへ',
      };
}
