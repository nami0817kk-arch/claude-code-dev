import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/main.dart';

/// 英語は日本語よりラベルが横に長くなるため、日本語では収まっていたUIが
/// 英語でだけ枠からはみ出すことがある。リリースビルドではオーバーフローの
/// 縞模様も例外も出ないので目視でも気づきにくい。デバッグビルドのテストなら
/// RenderFlexのオーバーフローが例外として上がるので、英語表示のまま
/// 主要画面を狭いスマートフォン幅で描画して回帰を検出する。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Tr.language = AppLanguage.english;
    final dispatcher =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher;
    dispatcher.localeTestValue = const Locale('en');
    dispatcher.localesTestValue = const [Locale('en')];
  });

  tearDown(() {
    Tr.language = AppLanguage.system;
    final dispatcher =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher;
    dispatcher.clearLocaleTestValue();
    dispatcher.clearLocalesTestValue();
  });

  /// 小さめのスマートフォン幅。ここで収まればより広い画面でも収まる。
  void useNarrowPhone(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 780);
  }

  /// タイトル画面からクラブを創設してホーム画面まで進む。
  Future<void> createClub(WidgetTester tester) async {
    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New club').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Test FC');
    await tester.tap(find.text('Found the club'));
    await tester.pumpAndSettle();
  }

  testWidgets('start screen fits within a narrow phone in English',
      (WidgetTester tester) async {
    useNarrowPhone(tester);

    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('New club'), findsWidgets);
  });

  testWidgets('the new club dialog fits within a narrow phone in English',
      (WidgetTester tester) async {
    useNarrowPhone(tester);

    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New club').first);
    await tester.pumpAndSettle();

    expect(find.text('Found the club'), findsOneWidget);
  });

  testWidgets('the main tabs fit within a narrow phone in English',
      (WidgetTester tester) async {
    useNarrowPhone(tester);
    await createClub(tester);

    // ボトムナビの各タブを開く。オーバーフローがあればpumpの時点で
    // 例外になり、このテストが落ちる。
    for (final tab in const ['Squad', 'Tactics', 'Table', 'Home']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
    }

    expect(find.text('Test FC'), findsWidgets);
  });

  testWidgets('the onboarding slides fit within a narrow phone in English',
      (WidgetTester tester) async {
    useNarrowPhone(tester);

    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();

    // 「次へ」で最後のスライドまで送る。各スライドの描画で
    // オーバーフローが出ないことを確かめる。
    while (find.text('Next').evaluate().isNotEmpty) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    // 最終スライドまで来ると「次へ」が開始ボタンに変わる。
    expect(find.text('Start'), findsOneWidget);
  });
}
