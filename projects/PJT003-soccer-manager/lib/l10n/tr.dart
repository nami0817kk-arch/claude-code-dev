import 'dart:ui' show PlatformDispatcher;

/// アプリが表示に使う言語。
enum AppLanguage {
  /// 端末の言語設定に従う。
  system,
  japanese,
  english;

  String get label => switch (this) {
        AppLanguage.system => Tr.pick('端末の設定に従う', 'Follow device setting'),
        // i18n-ignore: 言語名そのもの。英語表示でも「日本語」と出るのが正しい。
        AppLanguage.japanese => '日本語',
        AppLanguage.english => 'English',
      };
}

/// 文脈(BuildContext)を必要としない翻訳の入り口。
///
/// このアプリの文言の大半は、enumのラベルやニュース文のように
/// ウィジェットの外で組み立てられる。そこでは `AppLocalizations.of(context)`
/// が使えないため、現在の言語を静的に保持して `Tr.pick` で切り替える。
///
/// ウィジェット内の文言は従来どおり ARB (`context.l10n`) を使ってよい。
/// どちらも `Tr.resolvedLocale` と同じロケールを指すよう `main.dart` で
/// MaterialApp の locale に反映している。
class Tr {
  Tr._();

  /// 現在の設定値。`SettingsController` から設定され、既定は端末準拠。
  static AppLanguage language = AppLanguage.system;

  /// Flutter が実際に解決したロケールが英語かどうか。`main.dart` がビルドの
  /// たびに書き込む。
  ///
  /// PlatformDispatcher を直接読むだけでは足りない。テストの
  /// `localesTestValue` や `localeResolutionCallback` の結果は
  /// PlatformDispatcher.instance に反映されないため、ARB(AppLocalizations)が
  /// 日本語を返しているのに Tr が英語を返す、という食い違いが起きる。
  /// 値(boolean)で持つのは、context を掴んだクロージャを保持すると
  /// ウィジェット破棄後に「deactivated widget の祖先を参照した」で落ちるため。
  static bool? resolvedLocaleIsEnglish;

  /// 端末のロケールを英語とみなすか。テストから差し替えられるようにしてある。
  static bool Function() deviceIsEnglish = _deviceIsEnglish;

  /// 既定の判定に戻すための参照(テストが差し替えた後に復帰するため)。
  static bool Function() get deviceIsEnglishForTest => _deviceIsEnglish;

  static bool _deviceIsEnglish() {
    final resolved = resolvedLocaleIsEnglish;
    if (resolved != null) return resolved;
    final locale = PlatformDispatcher.instance.locale;
    return locale.languageCode.toLowerCase() == 'en';
  }

  /// 実際に表示に使う言語(systemを解決したもの)。
  static bool get isEnglish => switch (language) {
        AppLanguage.english => true,
        AppLanguage.japanese => false,
        AppLanguage.system => deviceIsEnglish(),
      };

  /// MaterialApp に渡す言語コード。systemのときはnull(Flutterに委ねる)。
  static String? get localeCode => switch (language) {
        AppLanguage.english => 'en',
        AppLanguage.japanese => 'ja',
        AppLanguage.system => null,
      };

  /// 日本語と英語のどちらかを返す。
  ///
  /// 日本語を第1引数に置いているのは、このアプリの原本が日本語だから。
  /// 英語側だけを見て読めない文があれば、それは英語が原文の意図を
  /// 落としているということなので、日本語を正として直す。
  static String pick(String ja, String en) => isEnglish ? en : ja;

  /// 英語の可算名詞を数に合わせて出す。日本語には単複の区別がないので、
  /// 使うのは Tr.pick の英語側だけ。
  ///
  /// 「1 years left」「1 apps, 1 goals」のような表示を避けるためのもの。
  /// match → matches のように -s を付けるだけで済まない語は [plural] を渡す。
  static String plural(int n, String singular, [String? plural]) =>
      '$n ${n == 1 ? singular : (plural ?? '${singular}s')}';
}
