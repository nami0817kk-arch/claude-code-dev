import '../models/player.dart';
import '../models/team.dart';

class ContractEngine {
  /// 週俸総額。他クラブへローン放出中の選手は放出先が週俸を負担するため含めない。
  static int weeklyWageBill(Team team) => team.players
      .where((p) => !p.isLoanedOut)
      .fold<int>(0, (s, p) => s + p.wage);

  /// 残り契約年数の表示ラベル。契約は年単位で結ばれるため、そのまま表示する。
  static String yearsLabel(int yearsRemaining) {
    if (yearsRemaining <= 0) return '契約満了間近';
    return '契約残り$yearsRemaining年';
  }

  /// [yearsLabel]の短縮版(トレーリング領域など表示幅が限られる箇所向け)。
  static String yearsShortLabel(int yearsRemaining) {
    if (yearsRemaining <= 0) return '契約満了間近';
    return '残り$yearsRemaining年';
  }

  /// ローン期間(週単位)を1週分消化させ、ローン満了となった選手を
  /// チームから除外して返す(元クラブへ復帰するため、フリーエージェントには
  /// 加えない)。契約(年単位)自体はシーズン開始時に[advanceSeason]でまとめて
  /// 処理する。
  static List<Player> advanceLoanWeek(Team team) {
    final expired = <Player>[];
    for (final p in List<Player>.from(team.players)) {
      if (!p.isLoan) continue;
      if (p.loanWeeksRemaining > 0) {
        p.loanWeeksRemaining -= 1;
      }
      if (p.loanWeeksRemaining <= 0) {
        expired.add(p);
      }
    }
    for (final p in expired) {
      team.players.remove(p);
      team.startingXI.remove(p.id);
    }
    return expired;
  }

  /// 契約(年単位)をシーズン境界で1年分消化させ、契約切れとなった選手を
  /// チームから除外する。除外された選手と、最終年に入り契約満了が近づいた
  /// 選手(事前警告用)をそれぞれ返す(UI通知用)。ローン選手は対象外
  /// (ローン期間は個別合意された週数で管理し、[advanceLoanWeek]で扱う)。
  static ({List<Player> expired, List<Player> nearingExpiry}) advanceSeason(
    Team team,
  ) {
    final expired = <Player>[];
    final nearingExpiry = <Player>[];
    for (final p in List<Player>.from(team.players)) {
      if (p.isLoan) continue;
      if (p.contractYearsRemaining > 0) {
        p.contractYearsRemaining -= 1;
      }
      if (p.contractYearsRemaining <= 0) {
        expired.add(p);
      } else if (p.contractYearsRemaining == 1) {
        nearingExpiry.add(p);
      }
    }
    for (final p in expired) {
      team.players.remove(p);
      team.startingXI.remove(p.id);
    }
    return (expired: expired, nearingExpiry: nearingExpiry);
  }

  /// 契約更新にかかる基本費用（万円）。ローン選手には適用されない。
  static int renewalCost(Player p) => (p.marketValue * 0.5).round();

  /// 放出(契約解除)にかかる違約金相当額（万円）。週俸が高く契約が長く
  /// 残っている選手ほど高額になり、移籍先が見つからない場合でもクラブが
  /// 残り契約分の負担を負う現実の慣行を反映する。移籍金収入(marketValue×0.7)
  /// から差し引かれ、高年俸の長期契約選手を放出すると持ち出しになり得る。
  static int releaseSeverance(Player p) =>
      (p.wage * 26 * p.contractYearsRemaining * 0.3).round();

  /// 契約更新時に一括で要求されるサインボーナス（万円）。野心家など要求水準が
  /// 高い性格ほど高額になる。
  static int signingBonusFor(Player p) =>
      (p.marketValue * 0.12 * p.personality.wageSensitivity).round();

  /// リーグ公式戦にスタメン出場するたびに支払われる出場手当（万円）。
  static int appearanceFeeFor(Player p) =>
      (p.overall * 0.5 * p.personality.wageSensitivity).round().clamp(1, 60);

  /// 新規契約・更新時に結ばれる契約年数。若い選手ほど長期契約を結びやすく、
  /// ベテランほど短期契約になる(現実のクラブ経営に合わせた簡易モデル)。
  static int negotiatedYears(Player p) {
    if (p.age <= 23) return 4;
    if (p.age <= 27) return 3;
    if (p.age <= 31) return 2;
    return 1;
  }

  /// [years]を指定しない場合は[negotiatedYears]で年齢に応じた契約年数を結ぶ。
  static void renewContract(Player p, {int? years}) {
    p.contractYearsRemaining = years ?? negotiatedYears(p);
    p.appearanceFee = appearanceFeeFor(p);
  }

  /// 契約交渉で選手が受け入れる最低週俸(万円)。要求水準が高い性格ほど、
  /// より大きな昇給を求める。
  static int minimumAcceptableWage(Player p) =>
      (p.wage * (1.05 + p.personality.wageSensitivity * 0.15)).round();

  /// 交渉開始時に選手側がまず提示する要求額(万円)。本当の最低希望額を
  /// 開始直後にそのまま見せてしまうと駆け引きが成立しなくなるため、
  /// 実際の最低ラインより高めに構えさせる(以降の対案と同じ上乗せ率)。
  static int initialDemand(Player p) =>
      (minimumAcceptableWage(p) * 1.15).round();

  /// この回数を超えて折り合わない場合、選手は交渉から離脱する。
  static const int maxNegotiationRounds = 3;

  /// クラブの提示額を拒否した際に選手側が出す対案(万円)。
  /// 最低希望額よりやや高めに構え、徐々に譲歩していく。
  static int counterOffer(Player p, int rejectedOffer) {
    final minAcceptable = minimumAcceptableWage(p);
    final demand = ((rejectedOffer + minAcceptable * 1.15) / 2).round();
    return demand < minAcceptable ? minAcceptable : demand;
  }
}
