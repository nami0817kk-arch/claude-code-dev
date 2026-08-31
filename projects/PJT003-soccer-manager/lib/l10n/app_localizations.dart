import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja')
  ];

  /// アプリ名。ストア表記と揃える
  ///
  /// In ja, this message translates to:
  /// **'サッカー経営マネージャー'**
  String get appTitle;

  /// No description provided for @startTagline.
  ///
  /// In ja, this message translates to:
  /// **'クラブを率いてリーグ優勝を目指そう'**
  String get startTagline;

  /// No description provided for @startSlotLabel.
  ///
  /// In ja, this message translates to:
  /// **'スロット{number}'**
  String startSlotLabel(int number);

  /// No description provided for @startEmptySlot.
  ///
  /// In ja, this message translates to:
  /// **'空きスロット'**
  String get startEmptySlot;

  /// No description provided for @startDeleteSlot.
  ///
  /// In ja, this message translates to:
  /// **'スロット{number}を削除しますか？'**
  String startDeleteSlot(int number);

  /// No description provided for @startCreateClub.
  ///
  /// In ja, this message translates to:
  /// **'新規クラブ作成'**
  String get startCreateClub;

  /// No description provided for @startNewClubIn.
  ///
  /// In ja, this message translates to:
  /// **'スロット{number}に新規クラブを作成'**
  String startNewClubIn(int number);

  /// No description provided for @startClubNameLabel.
  ///
  /// In ja, this message translates to:
  /// **'クラブ名'**
  String get startClubNameLabel;

  /// No description provided for @startLeagueLabel.
  ///
  /// In ja, this message translates to:
  /// **'所属リーグ'**
  String get startLeagueLabel;

  /// No description provided for @startDifficultyLabel.
  ///
  /// In ja, this message translates to:
  /// **'難易度'**
  String get startDifficultyLabel;

  /// No description provided for @startCreate.
  ///
  /// In ja, this message translates to:
  /// **'創設する'**
  String get startCreate;

  /// No description provided for @commonCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get commonCancel;

  /// No description provided for @onboardingSkip.
  ///
  /// In ja, this message translates to:
  /// **'スキップ'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In ja, this message translates to:
  /// **'次へ'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In ja, this message translates to:
  /// **'はじめる'**
  String get onboardingStart;

  /// No description provided for @navHome.
  ///
  /// In ja, this message translates to:
  /// **'ホーム'**
  String get navHome;

  /// No description provided for @navSquad.
  ///
  /// In ja, this message translates to:
  /// **'スカッド'**
  String get navSquad;

  /// No description provided for @navTactics.
  ///
  /// In ja, this message translates to:
  /// **'戦術'**
  String get navTactics;

  /// No description provided for @navStandings.
  ///
  /// In ja, this message translates to:
  /// **'順位表'**
  String get navStandings;

  /// No description provided for @firstRunTitle.
  ///
  /// In ja, this message translates to:
  /// **'はじめの一歩'**
  String get firstRunTitle;

  /// No description provided for @firstRunProgress.
  ///
  /// In ja, this message translates to:
  /// **'はじめの一歩 ({done}/{total})'**
  String firstRunProgress(int done, int total);

  /// No description provided for @firstRunClose.
  ///
  /// In ja, this message translates to:
  /// **'ガイドを閉じる'**
  String get firstRunClose;

  /// No description provided for @firstRunSemantics.
  ///
  /// In ja, this message translates to:
  /// **'初回ガイドの進捗 {total} ステップ中 {done} ステップ完了'**
  String firstRunSemantics(int done, int total);

  /// No description provided for @firstRunMatchHint.
  ///
  /// In ja, this message translates to:
  /// **'このすぐ下の「次の試合」から始められます'**
  String get firstRunMatchHint;

  /// No description provided for @firstRunLineupLabel.
  ///
  /// In ja, this message translates to:
  /// **'スタメンを確認する'**
  String get firstRunLineupLabel;

  /// No description provided for @firstRunLineupDesc.
  ///
  /// In ja, this message translates to:
  /// **'誰がピッチに立つのかを見てみましょう。並びは後からいつでも変えられます。'**
  String get firstRunLineupDesc;

  /// No description provided for @firstRunLineupAction.
  ///
  /// In ja, this message translates to:
  /// **'スタメンへ'**
  String get firstRunLineupAction;

  /// No description provided for @firstRunTrainingLabel.
  ///
  /// In ja, this message translates to:
  /// **'今週の練習方針を決める'**
  String get firstRunTrainingLabel;

  /// No description provided for @firstRunTrainingDesc.
  ///
  /// In ja, this message translates to:
  /// **'練習方針は選手の伸び方を変えます。迷ったら「全体練習」で構いません。'**
  String get firstRunTrainingDesc;

  /// No description provided for @firstRunTrainingAction.
  ///
  /// In ja, this message translates to:
  /// **'トレーニングへ'**
  String get firstRunTrainingAction;

  /// No description provided for @firstRunMatchLabel.
  ///
  /// In ja, this message translates to:
  /// **'最初の試合を戦う'**
  String get firstRunMatchLabel;

  /// No description provided for @firstRunMatchDesc.
  ///
  /// In ja, this message translates to:
  /// **'「ライブで戦う」を選ぶと、決定機ごとにあなたが判断を下せます。'**
  String get firstRunMatchDesc;

  /// No description provided for @firstRunMatchAction.
  ///
  /// In ja, this message translates to:
  /// **'試合へ'**
  String get firstRunMatchAction;

  /// No description provided for @firstRunGrowthLabel.
  ///
  /// In ja, this message translates to:
  /// **'選手の成長を確かめる'**
  String get firstRunGrowthLabel;

  /// No description provided for @firstRunGrowthDesc.
  ///
  /// In ja, this message translates to:
  /// **'スカッドから選手を開くと、能力の推移グラフで伸びが確認できます。'**
  String get firstRunGrowthDesc;

  /// No description provided for @firstRunGrowthAction.
  ///
  /// In ja, this message translates to:
  /// **'スカッドへ'**
  String get firstRunGrowthAction;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
