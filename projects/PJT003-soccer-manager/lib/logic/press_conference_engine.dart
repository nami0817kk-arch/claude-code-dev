import 'dart:math';

import '../models/match_result.dart';
import '../models/press_question.dart';
import '../l10n/tr.dart';

enum _Outcome { win, draw, loss }

/// 試合結果を受けて記者会見の質問と回答選択肢を生成する。
class PressConferenceEngine {
  static final Random _rng = Random();

  static PressQuestion generateFor({
    required MatchResult result,
    required String userTeamId,
  }) {
    final isHome = result.homeTeamId == userTeamId;
    final userGoals = isHome ? result.homeGoals : result.awayGoals;
    final oppGoals = isHome ? result.awayGoals : result.homeGoals;
    final outcome = userGoals > oppGoals
        ? _Outcome.win
        : (userGoals == oppGoals ? _Outcome.draw : _Outcome.loss);

    final prompts = switch (outcome) {
      _Outcome.win => [
          Tr.pick('素晴らしい勝利でした。この結果をどう見ていますか？',
              'A fine win. How do you see the result?'),
          Tr.pick('快勝でしたね。今日のパフォーマンスについて一言お願いします。',
              'A comfortable win. A word on the performance?'),
        ],
      _Outcome.draw => [
          Tr.pick('引き分けに終わりました。手応えはありましたか？',
              'It finished level. Were you encouraged?'),
          Tr.pick('勝ち点を逃した形ですが、今日の内容をどう評価しますか？',
              'Points dropped. How do you rate the performance?'),
        ],
      _Outcome.loss => [
          Tr.pick(
              '厳しい敗戦となりました。原因は何だとお考えですか？', 'A hard defeat. What went wrong?'),
          Tr.pick('今日の敗北について、選手たちにどう声をかけますか？',
              'After that defeat, what do you say to the players?'),
        ],
    };
    final prompt = prompts[_rng.nextInt(prompts.length)];

    final options = switch (outcome) {
      _Outcome.win => [
          PressOption(
              label: Tr.pick('選手たちを誇りに思う', 'I am proud of them'),
              confidenceDelta: 1,
              moraleDelta: 3),
          PressOption(
            label: Tr.pick('まだ満足していない、次も勝つ', 'Not satisfied yet; we go again'),
            confidenceDelta: 3,
            moraleDelta: 0,
          ),
          PressOption(
            label: Tr.pick('相手も素晴らしいチームだった', 'They were a good side too'),
            confidenceDelta: 0,
            moraleDelta: 1,
          ),
        ],
      _Outcome.draw => [
          PressOption(
              label: Tr.pick('勝ち点1は前向きに捉えたい', 'I will take the point'),
              confidenceDelta: 1,
              moraleDelta: 1),
          PressOption(
            label: Tr.pick('勝てた試合だっただけに悔しい', 'We should have won that one'),
            confidenceDelta: 1,
            moraleDelta: -1,
          ),
          PressOption(
            label: Tr.pick('選手たちはよくやってくれた', 'The players gave everything'),
            confidenceDelta: -1,
            moraleDelta: 2,
          ),
        ],
      _Outcome.loss => [
          PressOption(
              label: Tr.pick('選手を全面的に擁護する', 'Back the players completely'),
              confidenceDelta: -1,
              moraleDelta: 3),
          PressOption(
            label: Tr.pick('猛省を促し、次に切り替える', 'Demand better, then move on'),
            confidenceDelta: 2,
            moraleDelta: -2,
          ),
          PressOption(
              label: Tr.pick('審判の判定に疑問を呈する', 'Question the refereeing'),
              confidenceDelta: -3,
              moraleDelta: 1),
        ],
    };

    return PressQuestion(prompt: prompt, options: options);
  }
}
