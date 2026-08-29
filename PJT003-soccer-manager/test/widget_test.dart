import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/logic/continental_cup_engine.dart';
import 'package:soccer_manager/logic/lineup_utils.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/main.dart';
import 'package:soccer_manager/screens/cup_screen.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('start screen shows save slot list', (WidgetTester tester) async {
    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('スキップ'));
    await tester.pumpAndSettle();

    expect(find.text('サッカー経営マネージャー'), findsOneWidget);
    expect(find.text('空きスロット'), findsWidgets);
    expect(find.text('新規クラブ作成'), findsWidgets);
  });

  testWidgets('creating a club navigates to the home dashboard',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('スキップ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('新規クラブ作成').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'テストFC');
    await tester.tap(find.text('創設する'));
    await tester.pumpAndSettle();

    expect(find.text('テストFC'), findsWidgets);
    expect(find.text('スカッド'), findsOneWidget);
  });

  testWidgets(
      'pressing back while on a non-home tab returns to the home tab '
      'instead of exiting to the title screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('スキップ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('新規クラブ作成').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'テストFC');
    await tester.tap(find.text('創設する'));
    await tester.pumpAndSettle();

    // ホームタブから「スカッド」タブへ切り替える(ルートは積まれない)。
    await tester.tap(find.text('スカッド'));
    await tester.pumpAndSettle();
    expect(find.text('テストFC'), findsNothing);

    // ブラウザ/端末の戻る操作を発火する。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // タイトル画面まで戻るのではなく、ホームタブに戻るだけであるべき。
    expect(find.text('新規クラブ作成'), findsNothing);
    expect(find.text('テストFC'), findsWidgets);

    // ホームタブの状態でもう一度戻る操作をすると、今度はタイトル画面へ戻る。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('新規クラブ作成'), findsWidgets);
  });

  testWidgets(
      'CupScreen announces the user club in the continental group table to '
      'screen readers, not just via background color',
      (WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    // グループ表がListViewの遅延構築で画面外に隠れないよう、十分縦長な
    // ビューポートにしておく。
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    // GameStateのシーズン進行処理は実際の非同期I/O(SharedPreferences等)を
    // 伴うため、テストのフェイクタイムゾーンの外(runAsync)で実行する。
    late final String userId;
    final gameState = await tester.runAsync(() async {
      final gs = GameState();
      await gs.startNewGame('テストFC');
      userId = gs.userTeam.id;
      // 大陸カップは通常、5部制ピラミッドを1部優勝まで何シーズンもかけて
      // 昇格した末に生成される。このテストが検証したいのはCupScreenの
      // グループ表アクセシビリティのみなので、昇格を何シーズンも消化する
      // 代わりに大陸カップの状態を直接組み立てる。
      final opponents = [
        for (int i = 0; i < 7; i++)
          PlayerGenerator.generateSquad(
              id: 'continental-test-$i', name: '大陸クラブ$i', strengthTier: 65 + i),
      ];
      for (final t in opponents) {
        LineupUtils.autoFill(t);
      }
      gs.save!.continentalTeams = opponents;
      gs.save!.continentalCup = ContinentalCupEngine.create(
        name: '大陸チャンピオンズカップ',
        teamIds: [userId, ...opponents.map((t) => t.id)],
      );
      return gs;
    });
    expect(gameState!.continentalCup, isNotNull);

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<GameState>.value(
        value: gameState,
        child: const CupScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('大陸カップ'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('自クラブ。')), findsOneWidget);

    handle.dispose();
  });

  testWidgets(
      'quick-sim ("結果だけ見る") shows a result dialog with the score '
      'instead of only a snackbar', (WidgetTester tester) async {
    // ホーム画面のListViewの遅延構築で次節カードが画面外にならないよう、
    // 十分縦長なビューポートにしておく。
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('スキップ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('新規クラブ作成').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'テストFC');
    await tester.tap(find.text('創設する'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('結果だけ見る'));
    await tester.pumpAndSettle();

    expect(find.textContaining('結果: '), findsOneWidget);
    expect(find.text('閉じる'), findsOneWidget);

    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    expect(find.textContaining('結果: '), findsNothing);
  });
}
