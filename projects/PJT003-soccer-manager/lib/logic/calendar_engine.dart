import '../models/continental_cup.dart';
import '../models/cup.dart';
import '../models/league.dart';
import '../models/team.dart';
import 'continental_cup_engine.dart';

/// カレンダー表示用の1日分の情報。
class CalendarDayInfo {
  final DateTime date;
  final bool isLeagueMatchDay;
  final bool isHomeMatch;
  final String? opponentName;
  final int? matchday;
  final bool isTrainingFocusDay;
  final bool isToday;

  /// この日から消化可能になるカップ戦(国内・大陸)の表示ラベル。
  /// 複数の大会が同じ日に消化可能となることもあるため複数保持する。
  final List<String> cupLabels;

  const CalendarDayInfo({
    required this.date,
    this.isLeagueMatchDay = false,
    this.isHomeMatch = false,
    this.opponentName,
    this.matchday,
    this.isTrainingFocusDay = false,
    this.isToday = false,
    this.cupLabels = const [],
  });

  bool get isCupMatchDay => cupLabels.isNotEmpty;
}

/// シーズン内の節・親善試合に実際の暦日を与え、カレンダー画面向けに
/// 日ごとの予定(試合日/重点練習日)を計算する。ゲームは節(週)単位で
/// 進行するため、この日付はあくまで表示用であり、セーブデータへの
/// 永続化は不要(シーズン番号から常に同じ日付を再計算できる)。
class CalendarEngine {
  /// 指定シーズンの開幕節(第1節)の実日付。常に土曜日になるよう調整する。
  static DateTime seasonAnchor(int season) {
    final d = DateTime(2024 + (season - 1), 8, 1);
    final diff = (DateTime.saturday - d.weekday) % 7;
    return d.add(Duration(days: diff));
  }

  /// 指定シーズン・節の実日付(常に土曜日)。
  static DateTime dateForMatchday(int season, int matchday) =>
      seasonAnchor(season).add(Duration(days: (matchday - 1) * 7));

  /// プレシーズン親善試合の推定日付。開幕の週から遡って1週間隔で並べる。
  static DateTime dateForFriendly(int season, int index, int count) =>
      seasonAnchor(season).subtract(Duration(days: (count - index) * 7));

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static const _weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

  /// DateTime.weekday(1=月〜7=日)に対応する日本語の曜日1文字。
  static String weekdayLabel(int weekday) => _weekdayLabels[weekday - 1];

  /// カップ戦の対戦相手表示に使うチーム名を、リーグ勢+大陸カップ参加勢
  /// (両方渡された場合)から解決する。
  static String? _teamNameFor(
      String teamId, League league, List<Team> extraTeams) {
    for (final t in league.teams) {
      if (t.id == teamId) return t.name;
    }
    for (final t in extraTeams) {
      if (t.id == teamId) return t.name;
    }
    return null;
  }

  /// [cup]の次の未消化試合が消化可能になる日付("1節分の間隔"ルールにより
  /// 消化可能になる最初の日)と、カレンダー表示用ラベルを返す。
  static (DateTime, String)? _domesticCupEntry(
      Cup? cup, League league, String userTeamId, List<Team> extraTeams) {
    if (cup == null) return null;
    final match = cup.nextUnplayedMatch;
    if (match == null) return null;
    final eligibleMatchday = (cup.lastPlayedAtMatchday ?? 0) + 1;
    final date = dateOnly(dateForMatchday(league.season, eligibleMatchday));
    final involvesUser =
        match.homeTeamId == userTeamId || match.awayTeamId == userTeamId;
    if (!involvesUser) return (date, '${cup.name}: 消化可能');
    final isHome = match.homeTeamId == userTeamId;
    final opponentId = isHome ? match.awayTeamId : match.homeTeamId;
    final opponentName = _teamNameFor(opponentId, league, extraTeams) ?? '未定';
    return (date, '${cup.name}: ${isHome ? '(H)' : '(A)'} vs $opponentName');
  }

  /// 大陸カップ版の[_domesticCupEntry]。グループステージ・決勝トーナメントの
  /// いずれの段階でも、次の未消化試合から対戦カードを解決する。
  static (DateTime, String)? _continentalCupEntry(ContinentalCup? cup,
      League league, String userTeamId, List<Team> extraTeams) {
    if (cup == null) return null;
    String? homeId;
    String? awayId;
    bool? isHome;
    if (!cup.isGroupStageComplete) {
      final match = ContinentalCupEngine.nextGroupMatch(cup);
      if (match == null) return null;
      homeId = match.homeTeamId;
      awayId = match.awayTeamId;
      isHome = homeId == userTeamId;
    } else {
      if (cup.knockoutRounds.isEmpty) return null;
      CupTie? tie;
      for (final t in cup.knockoutRounds.last) {
        if (!t.isComplete) {
          tie = t;
          break;
        }
      }
      if (tie == null) return null;
      homeId = tie.teamAId;
      awayId = tie.teamBId;
      isHome = null;
    }
    final eligibleMatchday = (cup.lastPlayedAtMatchday ?? 0) + 1;
    final date = dateOnly(dateForMatchday(league.season, eligibleMatchday));
    final involvesUser = homeId == userTeamId || awayId == userTeamId;
    if (!involvesUser) return (date, '${cup.name}: 消化可能');
    final opponentId = homeId == userTeamId ? awayId : homeId;
    final opponentName = _teamNameFor(opponentId, league, extraTeams) ?? '未定';
    final sideLabel = isHome == null ? '' : (isHome ? '(H)' : '(A)');
    return (date, '${cup.name}: $sideLabel vs $opponentName');
  }

  /// [from]〜[to](両端含む)の各日について、自クラブのリーグ戦がある日は
  /// 対戦相手情報を、それ以外は重点練習日かどうかを付与して返す。カップ戦
  /// (国内・大陸)は次の試合が消化可能になる日にラベルとして付与する。
  static List<CalendarDayInfo> buildRange({
    required DateTime from,
    required DateTime to,
    required League league,
    required String userTeamId,
    required int trainingDayOfWeek,
    required DateTime today,
    Cup? domesticCup,
    ContinentalCup? continentalCup,
    List<Team> continentalTeams = const [],
  }) {
    final matchesByDate = <DateTime, Fixture>{};
    for (final f in league.fixtures) {
      if (f.homeTeamId != userTeamId && f.awayTeamId != userTeamId) continue;
      matchesByDate[dateOnly(dateForMatchday(league.season, f.matchday))] = f;
    }

    final cupLabelsByDate = <DateTime, List<String>>{};
    for (final entry in [
      _domesticCupEntry(domesticCup, league, userTeamId, continentalTeams),
      _continentalCupEntry(
          continentalCup, league, userTeamId, continentalTeams),
    ]) {
      if (entry == null) continue;
      cupLabelsByDate.putIfAbsent(entry.$1, () => []).add(entry.$2);
    }

    final days = <CalendarDayInfo>[];
    var cursor = dateOnly(from);
    final end = dateOnly(to);
    final todayOnly = dateOnly(today);
    while (!cursor.isAfter(end)) {
      final fixture = matchesByDate[cursor];
      final isToday = cursor == todayOnly;
      final cupLabels = cupLabelsByDate[cursor] ?? const [];
      if (fixture != null) {
        final isHome = fixture.homeTeamId == userTeamId;
        final opponentId = isHome ? fixture.awayTeamId : fixture.homeTeamId;
        String? opponentName;
        for (final t in league.teams) {
          if (t.id == opponentId) {
            opponentName = t.name;
            break;
          }
        }
        days.add(CalendarDayInfo(
          date: cursor,
          isLeagueMatchDay: true,
          isHomeMatch: isHome,
          opponentName: opponentName,
          matchday: fixture.matchday,
          isToday: isToday,
          cupLabels: cupLabels,
        ));
      } else {
        days.add(CalendarDayInfo(
          date: cursor,
          isTrainingFocusDay: cursor.weekday == trainingDayOfWeek,
          isToday: isToday,
          cupLabels: cupLabels,
        ));
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return days;
  }
}
