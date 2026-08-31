import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/logic/first_run_guide.dart';
import 'package:soccer_manager/models/first_run_step.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  group('初回ガイド', () {
    late GameState gameState;

    setUp(() async {
      gameState = GameState();
      await gameState.startNewGame('テストFC');
    });

    test('新規ゲームでは最初のステップから案内される', () {
      final save = gameState.save!;
      expect(FirstRunGuide.shouldShow(save), isTrue);
      expect(FirstRunGuide.nextStep(save), FirstRunStep.lineup);
      expect(FirstRunGuide.doneCount(save), 0);
    });

    test('ステップを踏むと次へ進み、4つ終えると表示されなくなる', () {
      gameState.markFirstRunStep(FirstRunStep.lineup);
      expect(FirstRunGuide.nextStep(gameState.save!), FirstRunStep.training);

      gameState.markFirstRunStep(FirstRunStep.training);
      // 試合は記録ではなく通算成績から導出する。まだ0試合なのでここで止まる。
      expect(FirstRunGuide.nextStep(gameState.save!), FirstRunStep.match);

      gameState.save!.careerWins = 1;
      expect(FirstRunGuide.nextStep(gameState.save!), FirstRunStep.growth);

      gameState.markFirstRunStep(FirstRunStep.growth);
      expect(FirstRunGuide.nextStep(gameState.save!), isNull);
      expect(FirstRunGuide.shouldShow(gameState.save!), isFalse);
    });

    test('閉じたら残りのステップがあっても二度と表示しない', () {
      gameState.dismissFirstRunGuide();
      final save = gameState.save!;
      expect(FirstRunGuide.shouldShow(save), isFalse);
      // 案内対象自体は残っている(閉じたことと完了は別)。
      expect(FirstRunGuide.nextStep(save), isNotNull);
    });

    test('練習は消化済みなら記録がなくても達成扱いになる', () {
      // 自動トレーニング設定で消化された場合、画面を開いた記録は残らない。
      // それでも「練習方針を決める」を促し続けるのは筋が悪い。
      final save = gameState.save!;
      expect(FirstRunGuide.isDone(save, FirstRunStep.training), isFalse);
      save.trainingDoneThisWeek = true;
      expect(FirstRunGuide.isDone(save, FirstRunStep.training), isTrue);
    });

    test('既に遊んでいるセーブにいまさら試合を促さない', () {
      final save = gameState.save!;
      save.careerWins = 3;
      save.careerLosses = 2;
      expect(FirstRunGuide.isDone(save, FirstRunStep.match), isTrue);
    });

    test('進捗がセーブに往復し、旧セーブは既定値で読める', () {
      gameState.markFirstRunStep(FirstRunStep.lineup);
      gameState.dismissFirstRunGuide();

      final restored =
          SaveGame.fromJson(jsonDecode(jsonEncode(gameState.save!.toJson())));
      expect(restored.firstRunStepsSeen, contains(FirstRunStep.lineup.name));
      expect(restored.firstRunGuideDismissed, isTrue);

      // 旧セーブにはどちらのキーも無い。落ちずに既定値になること。
      final legacy = jsonDecode(jsonEncode(gameState.save!.toJson()))
          as Map<String, dynamic>
        ..remove('firstRunStepsSeen')
        ..remove('firstRunGuideDismissed');
      final old = SaveGame.fromJson(legacy);
      expect(old.firstRunStepsSeen, isEmpty);
      expect(old.firstRunGuideDismissed, isFalse);
    });
  });
}
