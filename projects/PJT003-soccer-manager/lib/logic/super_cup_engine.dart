import '../models/cup.dart';

/// スーパーカップの対戦カード(1組目=リーグ王者側、2組目=対戦相手)。
typedef SuperCupPairing = (String championId, String opponentId);

class SuperCupEngine {
  /// 前シーズンのリーグ王者と国内カップ王者から、新シーズン開幕前のスーパー
  /// カップの対戦カードを決める。同一クラブが両方を制した場合は、カップ準優勝
  /// クラブが相手となる(実際のスーパーカップでよくある扱いに準拠)。
  ///
  /// 国内カップが未消化のままシーズンが終わった場合や、対戦カードが同一クラブ
  /// になってしまう場合(理論上は起こらない)はnullを返し、開催しない。
  static SuperCupPairing? pairing({
    required String leagueChampionId,
    required Cup domesticCup,
  }) {
    if (!domesticCup.isComplete || domesticCup.championId == null) {
      return null;
    }
    var opponentId = domesticCup.championId!;
    if (opponentId == leagueChampionId) {
      final cupFinal = domesticCup.rounds.last.first;
      opponentId = cupFinal.winnerId == cupFinal.homeTeamId
          ? cupFinal.awayTeamId
          : cupFinal.homeTeamId;
    }
    if (opponentId == leagueChampionId) return null;
    return (leagueChampionId, opponentId);
  }
}
