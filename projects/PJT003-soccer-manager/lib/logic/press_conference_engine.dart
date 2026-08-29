import 'dart:math';
import '../models/match_result.dart';
import '../models/press_question.dart';

enum _Outcome { win, draw, loss }

/// 試合結果を受けて記者会見の質問と回答選択肢を生成する。
class PressConferenceEngine {
  static final Random _rng = Random();

  static PressQuestion generateFor(
      {required MatchResult result, required String userTeamId}) {
    final isHome = result.homeTeamId == userTeamId;
    final userGoals = isHome ? result.homeGoals : result.awayGoals;
    final oppGoals = isHome ? result.awayGoals : result.homeGoals;
    final outcome = userGoals > oppGoals
        ? _Outcome.win
        : (userGoals == oppGoals ? _Outcome.draw : _Outcome.loss);

    final prompts = switch (outcome) {
      _Outcome.win => const [
          '素晴らしい勝利でした。この結果をどう見ていますか？',
          '快勝でしたね。今日のパフォーマンスについて一言お願いします。',
        ],
      _Outcome.draw => const [
          '引き分けに終わりました。手応えはありましたか？',
          '勝ち点を逃した形ですが、今日の内容をどう評価しますか？',
        ],
      _Outcome.loss => const [
          '厳しい敗戦となりました。原因は何だとお考えですか？',
          '今日の敗北について、選手たちにどう声をかけますか？',
        ],
    };
    final prompt = prompts[_rng.nextInt(prompts.length)];

    final options = switch (outcome) {
      _Outcome.win => [
          PressOption(label: '選手たちを誇りに思う', confidenceDelta: 1, moraleDelta: 3),
          PressOption(
              label: 'まだ満足していない、次も勝つ', confidenceDelta: 3, moraleDelta: 0),
          PressOption(
              label: '相手も素晴らしいチームだった', confidenceDelta: 0, moraleDelta: 1),
        ],
      _Outcome.draw => [
          PressOption(
              label: '勝ち点1は前向きに捉えたい', confidenceDelta: 1, moraleDelta: 1),
          PressOption(
              label: '勝てた試合だっただけに悔しい', confidenceDelta: 1, moraleDelta: -1),
          PressOption(
              label: '選手たちはよくやってくれた', confidenceDelta: -1, moraleDelta: 2),
        ],
      _Outcome.loss => [
          PressOption(
              label: '選手を全面的に擁護する', confidenceDelta: -1, moraleDelta: 3),
          PressOption(
              label: '猛省を促し、次に切り替える', confidenceDelta: 2, moraleDelta: -2),
          PressOption(
              label: '審判の判定に疑問を呈する', confidenceDelta: -3, moraleDelta: 1),
        ],
    };

    return PressQuestion(prompt: prompt, options: options);
  }
}
