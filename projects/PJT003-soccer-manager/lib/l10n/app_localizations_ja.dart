// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'サッカー経営マネージャー';

  @override
  String get startTagline => 'クラブを率いてリーグ優勝を目指そう';

  @override
  String startSlotLabel(int number) {
    return 'スロット$number';
  }

  @override
  String get startEmptySlot => '空きスロット';

  @override
  String startDeleteSlot(int number) {
    return 'スロット$numberを削除しますか？';
  }

  @override
  String get startCreateClub => '新規クラブ作成';

  @override
  String startNewClubIn(int number) {
    return 'スロット$numberに新規クラブを作成';
  }

  @override
  String get startClubNameLabel => 'クラブ名';

  @override
  String get startLeagueLabel => '所属リーグ';

  @override
  String get startDifficultyLabel => '難易度';

  @override
  String get startCreate => '創設する';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get onboardingSkip => 'スキップ';

  @override
  String get onboardingNext => '次へ';

  @override
  String get onboardingStart => 'はじめる';

  @override
  String get navHome => 'ホーム';

  @override
  String get navSquad => 'スカッド';

  @override
  String get navTactics => '戦術';

  @override
  String get navStandings => '順位表';

  @override
  String get firstRunTitle => 'はじめの一歩';

  @override
  String firstRunProgress(int done, int total) {
    return 'はじめの一歩 ($done/$total)';
  }

  @override
  String get firstRunClose => 'ガイドを閉じる';

  @override
  String firstRunSemantics(int done, int total) {
    return '初回ガイドの進捗 $total ステップ中 $done ステップ完了';
  }

  @override
  String get firstRunMatchHint => 'このすぐ下の「次の試合」から始められます';

  @override
  String get firstRunLineupLabel => 'スタメンを確認する';

  @override
  String get firstRunLineupDesc => '誰がピッチに立つのかを見てみましょう。並びは後からいつでも変えられます。';

  @override
  String get firstRunLineupAction => 'スタメンへ';

  @override
  String get firstRunTrainingLabel => '今週の練習方針を決める';

  @override
  String get firstRunTrainingDesc => '練習方針は選手の伸び方を変えます。迷ったら「全体練習」で構いません。';

  @override
  String get firstRunTrainingAction => 'トレーニングへ';

  @override
  String get firstRunMatchLabel => '最初の試合を戦う';

  @override
  String get firstRunMatchDesc => '「ライブで戦う」を選ぶと、決定機ごとにあなたが判断を下せます。';

  @override
  String get firstRunMatchAction => '試合へ';

  @override
  String get firstRunGrowthLabel => '選手の成長を確かめる';

  @override
  String get firstRunGrowthDesc => 'スカッドから選手を開くと、能力の推移グラフで伸びが確認できます。';

  @override
  String get firstRunGrowthAction => 'スカッドへ';
}
