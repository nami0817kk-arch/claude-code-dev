import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 配信まわりの設定が食い違っていないかを固定するテスト。
///
/// これらは実行時ロジックではなく、ビルド設定・ストア掲載情報・アプリ内リンクの
/// 整合性を守るためのもの。ズレていても普通のテストは通ってしまい、
/// 気付くのがストアの審査差し戻しになるため、ここで検出する。
void main() {
  group('配信設定の整合性', () {
    test('プライバシーポリシー・利用規約のURLが公開先と一致している', () {
      // Web版のデプロイ先。soccer-manager-web.yml が --base-href に指定し、
      // legal/*.html をこの下の legal/ へコピーしている。
      const publishedLegalBase =
          'https://nami0817kk-arch.github.io/claude-code-dev/soccer-manager/legal';

      final settingsSource =
          File('lib/screens/settings_screen.dart').readAsStringSync();
      expect(
        settingsSource,
        contains("'$publishedLegalBase/privacy.html'"),
        reason: 'アプリ内のプライバシーポリシーのリンク先が公開先と食い違っている',
      );
      expect(
        settingsSource,
        contains("'$publishedLegalBase/terms.html'"),
        reason: 'アプリ内の利用規約のリンク先が公開先と食い違っている',
      );

      // ストア掲載情報にも同じURLを書く。Google Play は動作する
      // プライバシーポリシーURLの提出を必須にしているため、
      // ここがアプリ内と食い違うと審査で差し戻される。
      final storeListing = File('STORE_LISTING.md').readAsStringSync();
      expect(storeListing, contains('$publishedLegalBase/privacy.html'));
      expect(storeListing, contains('$publishedLegalBase/terms.html'));
    });

    test('旧リポジトリを指すURLが残っていない', () {
      // このプロジェクトは kabu-agari-ranking から claude-code-dev へ移した。
      // 移行時に取り残されたURLが実際にアプリ内とストア掲載情報の両方に
      // 残っていて、どちらも存在しないページを指していた。
      // README の移行経緯の記述だけは対象外。
      for (final path in const [
        'lib/screens/settings_screen.dart',
        'STORE_LISTING.md',
        'legal/privacy.html',
        'legal/terms.html',
      ]) {
        expect(
          File(path).readAsStringSync(),
          isNot(contains('kabu-agari-ranking')),
          reason: '$path に旧リポジトリを指すURLが残っている',
        );
      }
    });

    test('Androidのリリースビルドがデバッグ鍵で署名されない', () {
      final gradle = File('android/app/build.gradle').readAsStringSync();
      // key.properties があるときは必ず署名設定 release を使う。
      // ここが signingConfigs.debug 固定に戻ると、Google Play に
      // 提出できないAABが黙って出来上がる。
      expect(
        gradle,
        contains('signingConfig = hasKeystore ? signingConfigs.release'),
        reason: 'リリースビルドの署名設定が key.properties を見ていない',
      );
    });

    test('見出しフォントを同梱していて、外部から取得していない', () {
      // google_fonts 経由だと初回起動時に fonts.gstatic.com へ取りに行き、
      // 利用者のIPアドレスが Google に渡る。プライバシーポリシーの
      // 「アプリ版は外部サーバーへの通信を一切行いません」と矛盾するため、
      // アセットとして同梱する方式に戻さないよう固定する。
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec.contains(RegExp(r'^\s*google_fonts:', multiLine: true)),
        isFalse,
        reason: 'google_fonts への依存が復活している',
      );
      expect(pubspec, contains('family: ShipporiMincho'));

      for (final f in const [
        'assets/fonts/ShipporiMincho-Regular.ttf',
        'assets/fonts/ShipporiMincho-SemiBold.ttf',
        // OFL 1.1 はフォントの再配布に際してライセンス文の同梱を求めている。
        'assets/fonts/OFL.txt',
      ]) {
        expect(File(f).existsSync(), isTrue, reason: '$f が無い');
      }

      expect(
        File('lib/main.dart').readAsStringSync(),
        isNot(contains('GoogleFonts')),
        reason: 'main.dart が実行時取得のフォントを参照している',
      );
    });

    test('Web版がCanvasKitをGoogleのCDNから読み込まない', () {
      // Flutter Web は既定で CanvasKit (描画エンジン本体) を
      // www.gstatic.com から読み込むため、ページを開いただけで
      // 利用者のIPアドレスが Google に渡る。ビルド時に
      // build/web/canvaskit/ へ出力されるローカルのコピーを使う。
      final bootstrap = File('web/flutter_bootstrap.js');
      expect(bootstrap.existsSync(), isTrue, reason: 'ブートストラップの上書きが消えている');
      expect(bootstrap.readAsStringSync(), contains('canvasKitBaseUrl'));
    });

    test('広告を入れた事実が法務・掲載情報から漏れていない', () {
      // 実装だけ広告を出して、プライバシーポリシーやストア掲載情報が
      // 「広告なし」のままだと、虚偽の申告で提出することになる。
      // 実装と表記が食い違わないよう固定する。
      final privacy = File('legal/privacy.html').readAsStringSync();
      expect(privacy, contains('AdMob'), reason: 'プライバシーポリシーが広告配信に触れていない');
      expect(privacy, contains('広告識別子'), reason: '広告識別子の取得を開示していない');

      for (final path in const [
        'STORE_LISTING.md',
        'marketing/landing/index.html',
        'marketing/ANNOUNCEMENT.md',
      ]) {
        final text = File(path).readAsStringSync();
        expect(text, isNot(contains('広告なし・課金なし')),
            reason: '$path に「広告なし・課金なし」が残っている');
        expect(text, isNot(contains('広告も課金も')),
            reason: '$path に広告・課金が無いという記述が残っている');
      }
    });

    test('Androidが広告に必要なインターネット権限を宣言している', () {
      // 権限が無いと広告SDKは通信できず、リワード広告が永久に
      // 読み込まれない (押せないボタンだけが残る)。
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android.permission.INTERNET'));
      expect(manifest, contains('com.google.android.gms.ads.APPLICATION_ID'));
    });

    test('iOSが輸出コンプライアンスを申告している', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      // これがないと App Store Connect へのアップロードのたびに
      // 手動での回答を求められ、TestFlight への配信が止まる。
      expect(plist, contains('ITSAppUsesNonExemptEncryption'));
    });
  });
}
