import 'dart:math';

import '../models/league.dart';
import '../models/match_result.dart';

/// シーズン終了時の監督契約の去就。
enum ManagerContractEvent {
  none,
  finalYearWarning,
  extended,
  renewedOneYear,
  dismissed,
}

class BoardEngine {
  /// シーズン終了時に監督契約(残り年数)を1年消化し、去就を決める。
  /// 目標達成で残りが少なければ3年へ延長。満了時は信頼度次第で
  /// 単年契約の続投か、契約非更新(解任)となる。
  static ({int years, ManagerContractEvent event}) managerContractAfterSeason({
    required int yearsRemaining,
    required bool targetMet,
    required int confidence,
  }) {
    final years = yearsRemaining - 1;
    if (targetMet && years <= 1) {
      return (years: 3, event: ManagerContractEvent.extended);
    }
    if (years <= 0) {
      if (confidence >= 45) {
        return (years: 1, event: ManagerContractEvent.renewedOneYear);
      }
      return (years: 0, event: ManagerContractEvent.dismissed);
    }
    if (years == 1) {
      return (years: 1, event: ManagerContractEvent.finalYearWarning);
    }
    return (years: years, event: ManagerContractEvent.none);
  }

  /// ディビジョンごとの週給予算の基準値(万円/週)。下位リーグほど
  /// 人件費に厳しく、昇格すると理事会が予算を引き上げる。
  static int wageBudgetBaseForTier(int tier) => switch (tier) {
        1 => 700,
        2 => 480,
        3 => 330,
        4 => 230,
        _ => 160,
      };

  /// 理事会が設定する週給総額の上限(万円/週)。ティア基準値と
  /// 「現在の週給総額+基準値の25%の余裕」の大きい方を採用するため、
  /// シーズン開始時点で必ず補強の余地が残る。
  static int wageBudgetFor({
    required int tier,
    required int currentWeeklyWageBill,
  }) {
    final base = wageBudgetBaseForTier(tier);
    final headroom = max(60, (base * 0.4).round());
    return max(base, currentWeeklyWageBill + headroom);
  }

  /// 理事会が期待する国内カップの到達ラウンド(そのラウンドの試合を
  /// 戦うところまで勝ち残ること)。リーグ内の戦力順位が高いクラブほど
  /// 深いラウンドまで期待される。
  static int estimateCupTargetRound({
    required int strengthRank,
    required int teamCount,
    required int totalRounds,
  }) {
    if (teamCount <= 0 || totalRounds <= 0) return 0;
    final ratio = strengthRank / teamCount;
    if (ratio <= 0.15) return totalRounds; // 優勝候補: 決勝進出
    if (ratio <= 0.35) return max(1, totalRounds - 1); // 準決勝進出
    if (ratio <= 0.6) return max(1, totalRounds - 2); // 準々決勝進出
    return max(1, totalRounds - 3);
  }

  /// スカッド総合力の順位に対して理事会が許容する余裕(順位いくつ分か)。
  /// 戦力通りの順位ちょうどを要求すると、達成できるかどうかが実質50%の
  /// コイン投げになり、何をしても運任せで解任される。少しの取りこぼしなら
  /// 許される幅を持たせる。
  static const int targetRankCushion = 2;

  /// 現在のスカッド総合力から見て妥当な目標順位（1が最高位）を見積もる。
  static int estimateTargetRank(League league, String userTeamId) {
    final sorted = [...league.teams]
      ..sort((a, b) => b.overallRating.compareTo(a.overallRating));
    final idx = sorted.indexWhere((t) => t.id == userTeamId);
    final strengthRank = idx < 0 ? (league.teams.length / 2).ceil() : idx + 1;
    return (strengthRank + targetRankCushion).clamp(1, league.teams.length);
  }

  /// 新シーズン開幕時に、続投が決まった監督へ戻す信頼度の下限。
  /// 信頼度はシーズンをまたいで持ち越されるため、前シーズンをぎりぎり
  /// 生き延びた監督は開幕2節で解任され、立て直す機会すらなかった
  /// (実測で確認)。契約を更新された=理事会は続投を選んだということなので、
  /// 新シーズンの開幕時点では最低限の猶予を与える。
  static const int newSeasonConfidenceFloor = 40;

  /// 試合結果を受けて信頼度の増減量を返す。
  /// かつては勝ち+4・引き分け-1・負け-6と負けが重く、信頼度を維持するには
  /// 勝ちが負けの1.5倍(38試合なら23勝15敗)必要だった。つまり優勝争いを
  /// しない限り信頼度が0へ落ち続け、実測では放置プレイ5回中5回が、うち
  /// 3回はシーズン1〜2で解任されていた。勝ち負けを対称にし、勝率5割の
  /// クラブは試合結果だけでは信頼を失わないようにする。理事会の評価は
  /// シーズン中盤レビュー([midSeasonReviewDelta])とシーズン終了時の
  /// 順位評価([confidenceDeltaForSeasonEnd])が主役になる。
  static int confidenceDeltaForMatch(MatchResult result, String userTeamId) {
    final isHome = result.homeTeamId == userTeamId;
    final userGoals = isHome ? result.homeGoals : result.awayGoals;
    final oppGoals = isHome ? result.awayGoals : result.homeGoals;
    if (userGoals > oppGoals) return 3;
    if (userGoals == oppGoals) return 0;
    return -3;
  }

  /// シーズン終了時の順位評価による信頼度の増減量を返す。
  static int confidenceDeltaForSeasonEnd({
    required int finalRank,
    required int targetRank,
  }) {
    if (finalRank <= targetRank) return 15;
    if (finalRank > targetRank + 2) return -20;
    return 0;
  }

  /// シーズン中盤(折り返し地点)の理事会レビューによる信頼度の増減量。
  /// シーズン終了時ほど大きくは動かないが、早期の軌道修正を促す。
  static int midSeasonReviewDelta({
    required int currentRank,
    required int targetRank,
  }) {
    if (currentRank <= targetRank) return 8;
    if (currentRank > targetRank + 3) return -12;
    return 0;
  }

  /// シーズン中盤レビューで理事会から届く講評文。
  static String midSeasonReviewMessage({
    required int currentRank,
    required int targetRank,
  }) {
    if (currentRank <= targetRank) {
      return '理事会からシーズン中盤レビュー: 現在$currentRank位と好調な滑り出しです。'
          'このまま$targetRank位以内を目指してください。';
    }
    if (currentRank > targetRank + 3) {
      return '理事会からシーズン中盤レビュー: 現在$currentRank位と目標の$targetRank位を'
          '大きく下回っています。残り試合での早急な立て直しを求めます。';
    }
    return '理事会からシーズン中盤レビュー: 現在$currentRank位。目標の$targetRank位以内に向けて、'
        '引き続き注視しています。';
  }

  /// 資金がマイナスのまま連続した週数がこの値に達するたびに信頼度が下がる。
  static const int negativeBudgetPenaltyThresholdWeeks = 8;

  /// 資金マイナスが続いている週数を受けて信頼度の増減量を返す。
  /// 閾値に達するたびに(閾値の倍数ごとに)ペナルティが発生する。
  static int negativeBudgetConfidenceDelta(int consecutiveNegativeWeeks) {
    if (consecutiveNegativeWeeks <= 0) return 0;
    if (consecutiveNegativeWeeks % negativeBudgetPenaltyThresholdWeeks != 0) {
      return 0;
    }
    return -8;
  }

  /// 最終順位に応じた賞金（万円）。
  /// 昇格時の理事会からの補強予算(万円)。昇格したクラブは放映権料・
  /// スポンサー収入が跳ね上がるため、新しいディビジョンで戦うための
  /// 資金が渡される。金額は新ティアの週給予算基準の[promotionBonusWeeks]
  /// 週分で、上のディビジョンほど大きい。
  ///
  /// これがないと、昇格しても戦力差(ティアあたり総合力で約10)を埋める
  /// 資金がなく、昇格→即降格の往復から抜け出せない(長期実測で確認)。
  static const int promotionBonusWeeks = 6;

  static int promotionBonusFor(int newTier) =>
      wageBudgetBaseForTier(newTier) * promotionBonusWeeks;

  static int seasonPrizeMoney({
    required int finalRank,
    required int teamCount,
  }) {
    final worst = teamCount;
    final ratio = worst <= 1 ? 1.0 : 1 - (finalRank - 1) / (worst - 1);
    return (300 + ratio * 2700).round();
  }
}
