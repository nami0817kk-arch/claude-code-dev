import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 同梱フォントに字形のない文字を検出する回帰テスト。
///
/// このアプリはフォントを同梱している (Web版の実行時に fonts.gstatic.com へ
/// 取りに行かせないため)。つまり同梱フォントのcmapが世界のすべてで、そこに
/// ない文字は豆腐(□)になる。しかも flutter analyze もウィジェットテストも
/// 何も言わないので、リリースビルドの画面を見るまで気づけない。
///
/// 実際に起きた: 英語の文言で区切りに U+00B7 MIDDLE DOT を使っていたが、
/// 同梱フォントのどちらにも入っておらず、全部が豆腐になっていた。
void main() {
  test(
    'every character used in lib/ can be drawn by the bundled fonts',
    () {
      final result = Process.runSync(
        'python3',
        ['tool/i18n/check_glyphs.py'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      // python3 が無い環境では検査できないので、落とさずスキップする。
      // ただし黙って無効になるのが一番まずいので、それ以外の失敗は落とす。
      final err = result.stderr as String;
      if (err.contains('No such file or directory') && result.exitCode != 1) {
        markTestSkipped('python3 が無いため字形の検査を行っていない');
        return;
      }

      final out = (result.stdout as String).trim();
      expect(
        out.endsWith('----- 0 characters missing from the bundled fonts'),
        isTrue,
        reason: '同梱フォントに字形のない文字が使われている(画面では豆腐になる)。\n'
            '同じ意味で字形のある文字に置き換えること。\n'
            '例: U+00B7「·」ではなく U+2022「•」、'
            'U+2013「–」ではなく ASCII のハイフン。\n\n$out',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
