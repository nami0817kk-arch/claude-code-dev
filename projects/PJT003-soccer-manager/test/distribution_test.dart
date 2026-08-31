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

    test('iOSが輸出コンプライアンスを申告している', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      // これがないと App Store Connect へのアップロードのたびに
      // 手動での回答を求められ、TestFlight への配信が止まる。
      expect(plist, contains('ITSAppUsesNonExemptEncryption'));
    });
  });
}
