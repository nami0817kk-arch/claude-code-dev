import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/l10n/app_localizations.dart';
import 'package:soccer_manager/models/first_run_step.dart';

void main() {
  group('多言語対応', () {
    test('日本語と英語で同じキーが揃っている', () {
      // 片方にキーを足し忘れると、その言語だけ実行時に落ちるか
      // 日本語のまま出てしまう。ARB同士を突き合わせて防ぐ。
      Set<String> keysOf(String path) {
        final json =
            jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
        return json.keys.where((k) => !k.startsWith('@')).toSet();
      }

      final ja = keysOf('lib/l10n/app_ja.arb');
      final en = keysOf('lib/l10n/app_en.arb');
      expect(en.difference(ja), isEmpty, reason: '日本語側に無いキーが英語にある');
      expect(ja.difference(en), isEmpty, reason: '英語に未翻訳のキーがある');
      expect(ja, isNotEmpty);
    });

    testWidgets('英語ロケールで英語の文言が引ける', (tester) async {
      late AppLocalizations en;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          en = AppLocalizations.of(context)!;
          return const SizedBox.shrink();
        }),
      ));

      expect(en.navSquad, 'Squad');
      expect(en.firstRunProgress(1, 4), 'First steps (1/4)');
      expect(en.startSlotLabel(2), 'Slot 2');
      // 初回ガイドは新規プレイヤーが最初に触れる導線なので、
      // 英語でも日本語が残っていないことを明示的に押さえる。
      for (final step in FirstRunStep.values) {
        for (final text in [
          step.label(en),
          step.description(en),
          step.actionLabel(en),
        ]) {
          expect(
            RegExp(r'[぀-ヿ一-鿿]').hasMatch(text),
            isFalse,
            reason: '英語ロケールに日本語が残っている: $text',
          );
        }
      }
    });

    testWidgets('日本語ロケールでは日本語のままになる', (tester) async {
      late AppLocalizations ja;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          ja = AppLocalizations.of(context)!;
          return const SizedBox.shrink();
        }),
      ));

      expect(ja.navSquad, 'スカッド');
      expect(ja.appTitle, 'サッカー経営マネージャー');
      expect(ja.firstRunProgress(1, 4), 'はじめの一歩 (1/4)');
    });
  });
}
