import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import '../models/bank_loan.dart';
import '../models/investment.dart';
import '../models/best_eleven.dart';
import '../models/club_infrastructure.dart';
import '../models/continental_cup.dart';
import '../models/contract_negotiation.dart';
import '../models/cup.dart';
import '../models/formation.dart';
import '../models/incoming_offer.dart';
import '../models/installment.dart';
import '../models/league_theme.dart';
import '../models/player.dart';
import '../models/player_season_stats.dart';
import '../models/press_question.dart';
import '../models/save_game.dart';
import '../models/season_award.dart';
import '../models/season_record.dart';
import '../models/sponsor.dart';
import '../models/tactic_preset.dart';
import '../models/team_talk.dart';
import '../models/training_result.dart';
import '../models/team.dart';
import '../models/league.dart';
import '../models/match_result.dart';
import '../models/weather.dart';
import '../logic/achievement_engine.dart';
import '../logic/ai_transfer_engine.dart';
import '../logic/calendar_engine.dart';
import '../logic/awards_engine.dart';
import '../logic/background_match_engine.dart';
import '../logic/best_eleven_engine.dart';
import '../logic/board_engine.dart';
import '../logic/contract_engine.dart';
import '../logic/continental_cup_engine.dart';
import '../logic/cup_engine.dart';
import '../logic/happiness_engine.dart';
import '../logic/investment_engine.dart';
import '../logic/loan_engine.dart';
import '../logic/manager_career_engine.dart';
import '../logic/press_conference_engine.dart';
import '../logic/player_generator.dart';
import '../logic/promotion_engine.dart';
import '../logic/retirement_engine.dart';
import '../logic/rotation_engine.dart';
import '../logic/fixture_generator.dart';
import '../logic/free_agent_engine.dart';
import '../logic/lineup_utils.dart';
import '../logic/match_engine.dart';
import '../logic/scouting_engine.dart';
import '../logic/season_projection_engine.dart';
import '../logic/sponsor_engine.dart';
import '../logic/super_cup_engine.dart';
import '../logic/training_engine.dart';
import '../logic/transfer_market.dart';
import '../logic/weather_engine.dart';
import '../data/name_pool.dart';

const int maxSquadSize = 26;
const int minSquadSize = 12;

/// 1リーグあたりの参加クラブ数(自クラブ含む)。実際の主要リーグに近い規模とする。
const int teamsPerLeague = 20;

/// セーブスロット一覧表示用の概要情報。データが存在しないスロットは
/// clubNameがnullになる。
class SaveSlotSummary {
  final int slot;
  final String? clubName;
  final int? season;
  final int? divisionTier;

  SaveSlotSummary({
    required this.slot,
    this.clubName,
    this.season,
    this.divisionTier,
  });

  bool get hasSave => clubName != null;
}

class GameState extends ChangeNotifier {
  /// 旧バージョンで使われていた単一スロットのキー。起動時にスロット0へ移行する。
  static const _legacyPrefsKey = 'soccer_manager_save_v1';
  static const _slotKeyPrefix = 'soccer_manager_save_slot_';
  static const _currentSlotKey = 'soccer_manager_current_slot';

  /// 対応するセーブスロット数。
  static const int maxSaveSlots = 3;

  static String _slotKey(int slot) => '$_slotKeyPrefix$slot';

  int currentSlot = 0;

  SaveGame? _save;
  bool initialized = false;

  /// シーズン開幕・シーズン終了処理など、重い同期計算を行っている間true。
  /// UI側でローディング表示を出すために使う。
  bool isBusy = false;

  /// 直近の保存(_persist)が失敗した場合のエラーメッセージ。保存に成功すると
  /// nullに戻る。ブラウザのストレージ容量超過など、プレイ自体は継続できるが
  /// 進行状況が保存されていない可能性がある場合にUI側で警告を出すために使う。
  String? lastSaveError;
  List<Player> transferMarket = [];

  /// スカウトが見つけてきた、獲得可能な候補選手一覧(閲覧専用・未確定)。
  List<Player> scoutCandidates = [];

  /// 直近のplayNextMatchdayでローン期間満了により契約元クラブへ復帰した選手名、
  /// または直近のstartNextSeasonで契約(年単位)満了により退団した選手名
  /// （1回表示したら呼び出し側でクリアする想定）。
  List<String> lastContractExpirations = [];

  /// 直近のstartNextSeasonで契約の最終年に入った(事前警告)選手名
  /// (1回表示したら呼び出し側でクリアする想定)。
  List<String> lastContractWarnings = [];

  /// 契約切れでスカッドが最低人数を割り込んだ際、自動的に緊急補強された
  /// フリーエージェントの選手名(1回表示したら呼び出し側でクリアする想定)。
  List<String> lastEmergencySignings = [];

  /// 今週すでにトレーニングを実施済みかどうか(節が進むとリセットされる)。
  bool get trainingDoneThisWeek => _save?.trainingDoneThisWeek ?? false;

  /// 直近のrunWeeklyTrainingで実際に変化(成長・衰え)があった選手の一覧
  /// (1回表示したら呼び出し側でクリアする想定)。
  List<PlayerGrowthSummary> lastTrainingResults = [];

  /// 直近のstartNextSeasonで引退した選手名(1回表示したら呼び出し側でクリアする想定)。
  List<String> lastRetirements = [];

  /// 直近の自クラブの試合で達成された節目(ハットトリック・通算記録)の説明文
  /// (1回表示したら呼び出し側でクリアする想定)。
  List<String> lastMilestones = [];

  /// 直近の判定で新たに解除された実績(1回表示したら呼び出し側でクリアする想定)。
  List<Achievement> lastUnlockedAchievements = [];

  /// 直近のstartNextSeasonで算出された、前シーズン開始時点からの
  /// 選手成長サマリー(1回表示したら呼び出し側でクリアする想定)。
  List<PlayerGrowthSummary> lastSeasonGrowthSummary = [];

  SaveGame? get save => _save;
  bool get hasSave => _save != null;
  Team get userTeam =>
      _save!.league.teams.firstWhere((t) => t.id == _save!.userTeamId);

  /// 信頼度が0まで落ち、監督が解任された状態かどうか。
  bool get isDismissed => _save != null && _save!.confidence <= 0;

  /// 監督としての通算成績(勝敗数)。保存済みの過去シーズン分に加え、
  /// 進行中のシーズンの現在の順位表の成績もその場で合算して返す
  /// (シーズン終了を待たずに逐次反映されるようにするため)。
  ({int wins, int draws, int losses}) get careerRecordSoFar {
    if (_save == null) return (wins: 0, draws: 0, losses: 0);
    final rows = _save!.league.sortedStandings.where(
      (r) => r.teamId == _save!.userTeamId,
    );
    final row = rows.isEmpty ? null : rows.first;
    return (
      wins: _save!.careerWins + (row?.won ?? 0),
      draws: _save!.careerDraws + (row?.draw ?? 0),
      losses: _save!.careerLosses + (row?.lost ?? 0),
    );
  }

  /// 今シーズンの最終節(まだ日程が組まれていなければ0)。
  int get _totalMatchdaysThisSeason {
    if (_save == null || _save!.league.fixtures.isEmpty) return 0;
    return _save!.league.fixtures.map((f) => f.matchday).reduce(max);
  }

  /// 移籍ウィンドウが開いているか。プレシーズン(開幕前)・シーズン中盤の
  /// 数節・シーズン終了後(オフシーズン)にのみ、選手の獲得・放出ができる。
  bool get isTransferWindowOpen {
    if (_save == null) return true;
    final nextMd = _save!.league.nextUnplayedFixture?.matchday;
    if (nextMd == null) return true; // シーズン終了後(オフシーズン)
    if (nextMd <= 1) return true; // プレシーズン(開幕前)
    final total = _totalMatchdaysThisSeason;
    if (total == 0) return true;
    final midStart = total ~/ 2;
    return nextMd >= midStart && nextMd <= midStart + 2;
  }

  /// UI表示用の移籍ウィンドウ状態文言。
  String get transferWindowStatusLabel {
    if (isTransferWindowOpen) return '移籍ウィンドウ: オープン中';
    final nextMd = _save?.league.nextUnplayedFixture?.matchday;
    final total = _totalMatchdaysThisSeason;
    if (nextMd == null || total == 0) return '移籍ウィンドウ: クローズ中';
    final midStart = total ~/ 2;
    if (nextMd < midStart) {
      return '移籍ウィンドウ: クローズ中(第$midStart節に再開)';
    }
    return '移籍ウィンドウ: クローズ中(来シーズン開幕前に再開)';
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    // 旧バージョンの単一セーブをスロット0へ移行する(スロット0が未使用の場合のみ)。
    final legacy = prefs.getString(_legacyPrefsKey);
    if (legacy != null && prefs.getString(_slotKey(0)) == null) {
      await prefs.setString(_slotKey(0), legacy);
      await prefs.remove(_legacyPrefsKey);
    }
    currentSlot = prefs.getInt(_currentSlotKey) ?? 0;
    final raw = prefs.getString(_slotKey(currentSlot));
    if (raw != null) {
      try {
        _save = SaveGame.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _save = null;
      }
    }
    if (_save != null) {
      _reseedPlayerIdCounter(_save!);
      _migrateDivisionPyramidIfNeeded();
      transferMarket = TransferMarket.generate();
      _refreshScoutCandidates();
    }
    initialized = true;
    notifyListeners();
  }

  /// セーブデータ内の全選手IDを集め、[PlayerGenerator]のIDカウンターへ反映する。
  void _reseedPlayerIdCounter(SaveGame save) {
    final ids = <String>[
      for (final t in save.allTeams)
        for (final p in t.players) p.id,
      for (final p in save.youthProspects) p.id,
      for (final p in save.pendingYouthIntake) p.id,
      for (final p in save.freeAgents) p.id,
      for (final p in save.retiredLegends) p.id,
    ];
    PlayerGenerator.ensureIdCounterAbove(ids);
  }

  /// [teams]から指定IDのチームを探す。見つからない場合はnull(移籍・世代交代
  /// 等で参照が古くなったフィクスチャがあっても、例外で節送り全体を
  /// 止めないようにするための安全な検索)。
  Team? _findTeam(List<Team> teams, String id) {
    for (final t in teams) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 旧セーブデータ(5部制ピラミッド導入前、または一部ディビジョンの日程が
  /// 未生成)を読み込んだ場合に、不足しているディビジョンを補充し、現在の
  /// リーグの節数までその日程をまとめて消化して追いつかせる。
  void _migrateDivisionPyramidIfNeeded() {
    if (_save == null) return;
    final catchUpTo = _currentLeagueMatchdayMarker - 1;
    final rng = Random();
    for (int tier = 1; tier <= totalDivisionTiers; tier++) {
      if (tier == _save!.currentDivisionTier) continue;
      final idx = tier - 1;
      final existing = _save!.otherDivisionLeagues[idx];
      if (existing != null && existing.fixtures.isNotEmpty) continue;

      List<Team> teams;
      if (existing != null) {
        // 旧セーブ(secondDivisionTeamsのみ)からの移行: チーム自体は既にある。
        teams = existing.teams;
      } else {
        // 5部制導入前は存在しなかったティア。新規にチームを生成する。
        final names = NamePool.themedClubNames(
          currentLeagueTheme,
          teamsPerLeague,
        );
        teams = [
          for (int i = 0; i < teamsPerLeague; i++)
            PlayerGenerator.generateSquad(
              id: 'migrated_t${tier}_$i',
              name: names[i],
              strengthTier: (55 - (tier - 1) * 10 + rng.nextInt(20)).clamp(
                15,
                90,
              ),
            ),
        ];
        for (final t in teams) {
          LineupUtils.autoFill(t);
        }
      }

      final fixtures = FixtureGenerator.generateDoubleRoundRobin(teams);
      for (final f in fixtures) {
        if (f.matchday > catchUpTo) continue;
        final home = teams.firstWhere((t) => t.id == f.homeTeamId);
        final away = teams.firstWhere((t) => t.id == f.awayTeamId);
        f.result = BackgroundMatchEngine.simulate(
          home: home,
          away: away,
          matchday: f.matchday,
        );
      }
      _save!.otherDivisionLeagues[idx] = League(
        teams: teams,
        fixtures: fixtures,
        season: _save!.league.season,
      );
    }
  }

  /// セーブデータをローカルストレージへ書き込む。ブラウザのストレージ容量
  /// 超過など、書き込み自体が失敗する場合がある(特にディビジョン数が増えて
  /// セーブデータが肥大化した場合)。ここで例外を握りつぶさずに外へ伝播させると、
  /// 呼び出し元(新規クラブ作成など)の非同期処理全体が失敗し、ローディング
  /// 表示のまま進行できなくなる(UI側でエラーを拾えないため)。プレイ自体は
  /// メモリ上のセーブデータで継続できるため、保存失敗はここで捕捉して
  /// [lastSaveError] に記録するに留める。
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_save == null) {
        await prefs.remove(_slotKey(currentSlot));
      } else {
        await prefs.setString(
          _slotKey(currentSlot),
          jsonEncode(_save!.toJson()),
        );
      }
      lastSaveError = null;
    } catch (e) {
      lastSaveError = 'セーブデータの保存に失敗しました。端末の空き容量を確認してください。';
      notifyListeners();
    }
  }

  /// 各スロットの概要一覧を返す(スロット番号順)。
  Future<List<SaveSlotSummary>> listSaveSlots() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <SaveSlotSummary>[];
    for (int i = 0; i < maxSaveSlots; i++) {
      final raw = prefs.getString(_slotKey(i));
      if (raw == null) {
        result.add(SaveSlotSummary(slot: i));
        continue;
      }
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final league = json['league'] as Map<String, dynamic>?;
        result.add(
          SaveSlotSummary(
            slot: i,
            clubName: json['clubName'] as String?,
            season: league?['season'] as int?,
            divisionTier: json['currentDivisionTier'] as int?,
          ),
        );
      } catch (_) {
        result.add(SaveSlotSummary(slot: i));
      }
    }
    return result;
  }

  /// 指定スロットをカレントスロットにして読み込む(データがなければ空の状態にする)。
  Future<void> loadSlot(int slot) async {
    final prefs = await SharedPreferences.getInstance();
    currentSlot = slot;
    await prefs.setInt(_currentSlotKey, slot);
    final raw = prefs.getString(_slotKey(slot));
    if (raw == null) {
      _save = null;
    } else {
      try {
        _save = SaveGame.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _save = null;
      }
    }
    if (_save != null) {
      _reseedPlayerIdCounter(_save!);
      _migrateDivisionPyramidIfNeeded();
      transferMarket = TransferMarket.generate();
      _refreshScoutCandidates();
    } else {
      transferMarket = [];
      scoutCandidates = [];
    }
    lastContractExpirations = [];
    lastRetirements = [];
    notifyListeners();
  }

  /// 指定スロットのセーブデータを完全に削除する。カレントスロットの場合は
  /// メモリ上のセーブも破棄する。
  Future<void> deleteSlot(int slot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_slotKey(slot));
    if (slot == currentSlot) {
      _save = null;
      transferMarket = [];
      scoutCandidates = [];
      notifyListeners();
    }
  }

  Future<void> startNewGame(
    String clubName, {
    LeagueTheme theme = LeagueTheme.england,
  }) async {
    isBusy = true;
    notifyListeners();
    // ローディング表示を1フレーム描画させてから、重いクラブ生成処理に入る。
    await Future<void>.delayed(Duration.zero);
    final userTeam = PlayerGenerator.generateSquad(
      id: 'user',
      name: clubName,
      strengthTier: 60,
    );
    final rng = Random();
    // 5部制ピラミッドの最下層(5部)からスタートする。
    const userStartTier = totalDivisionTiers;
    final allNames = NamePool.themedClubNames(
      theme,
      teamsPerLeague * totalDivisionTiers - 1,
    );
    var nameIndex = 0;
    String nextName() => allNames[nameIndex++];

    // 上位ティアほど平均的なチーム力が高くなるようにする(1部が最強)。
    // ユーザーの開始ティアでの強さ幅は、旧来の1部CPUと同じ(40-74)に揃え、
    // 従来通りの難易度バランスを保つ。
    int strengthForTier(int tier) {
      final tiersAboveUser = userStartTier - tier;
      final base = 40 + tiersAboveUser * 10;
      return (base + rng.nextInt(35)).clamp(20, 99);
    }

    const cpuCount = teamsPerLeague - 1;
    final cpuTeams = <Team>[];
    for (int i = 0; i < cpuCount; i++) {
      cpuTeams.add(
        PlayerGenerator.generateSquad(
          id: 'cpu$i',
          name: nextName(),
          strengthTier: strengthForTier(userStartTier),
        ),
      );
    }
    final teams = [userTeam, ...cpuTeams];
    for (final t in teams) {
      LineupUtils.autoFill(t);
    }

    final otherDivisionLeagues = List<League?>.filled(totalDivisionTiers, null);
    for (int tier = 1; tier <= totalDivisionTiers; tier++) {
      if (tier == userStartTier) continue;
      final tierTeams = <Team>[
        for (int i = 0; i < teamsPerLeague; i++)
          PlayerGenerator.generateSquad(
            id: 'div${tier}_$i',
            name: nextName(),
            strengthTier: strengthForTier(tier),
          ),
      ];
      for (final t in tierTeams) {
        LineupUtils.autoFill(t);
      }
      otherDivisionLeagues[tier - 1] = League(
        teams: tierTeams,
        fixtures: FixtureGenerator.generateDoubleRoundRobin(tierTeams),
        season: 1,
      );
    }

    final fixtures = FixtureGenerator.generateDoubleRoundRobin(teams);
    final league = League(teams: teams, fixtures: fixtures, season: 1);
    _save = SaveGame(
      clubName: clubName,
      userTeamId: 'user',
      league: league,
      leagueName: theme.label,
      boardTargetRank: BoardEngine.estimateTargetRank(league, 'user'),
      cups: [
        CupEngine.createKnockout(
          type: CupType.domestic,
          name: theme.domesticCupName,
          teamIds: teams.map((t) => t.id).toList(),
        ),
      ],
      pendingSponsorOffers: SponsorEngine.generateOffers(
        userTeam.overallRating,
      ),
      friendlies: _generateFriendlies(teams, 'user'),
      otherDivisionLeagues: otherDivisionLeagues,
      currentDivisionTier: userStartTier,
      clubHistory: [clubName],
    );
    final rival = cpuTeams[rng.nextInt(cpuTeams.length)];
    _save!.rivalTeamId = rival.id;
    _save!.rivalTeamName = rival.name;
    transferMarket = TransferMarket.generate();
    _refreshScoutCandidates();
    FreeAgentEngine.topUp(_save!.freeAgents);
    lastContractExpirations = [];
    isBusy = false;
    notifyListeners();
    await _persist();
  }

  /// シーズン開幕前の親善試合を2試合分生成する(ランダムな相手と)。
  List<Fixture> _generateFriendlies(List<Team> teams, String userTeamId) {
    final opponents = teams.where((t) => t.id != userTeamId).toList()
      ..shuffle(Random());
    final count = min(2, opponents.length);
    return List.generate(
      count,
      (i) => Fixture(
        matchday: 0,
        homeTeamId: userTeamId,
        awayTeamId: opponents[i].id,
      ),
    );
  }

  Future<void> deleteSave() async {
    _save = null;
    transferMarket = [];
    scoutCandidates = [];
    lastContractExpirations = [];
    notifyListeners();
    await _persist();
  }

  /// バックアップ用にセーブデータ全体をJSON文字列として書き出す。
  String? exportSaveJson() {
    if (_save == null) return null;
    return jsonEncode(_save!.toJson());
  }

  /// エクスポートされたJSON文字列からセーブデータを復元する。形式が不正な場合はfalseを返す。
  Future<bool> importSaveJson(String json) async {
    final SaveGame restored;
    try {
      restored = SaveGame.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return false;
    }
    _save = restored;
    _reseedPlayerIdCounter(restored);
    _migrateDivisionPyramidIfNeeded();
    transferMarket = TransferMarket.generate();
    _refreshScoutCandidates();
    notifyListeners();
    await _persist();
    return true;
  }

  /// チーム既定のトレーニング方針を設定する（個別方針未設定の選手に適用される）。
  void setTeamTrainingFocus(TrainingFocus focus) {
    if (_save == null) return;
    userTeam.defaultTrainingFocus = focus;
    notifyListeners();
    _persist();
  }

  /// 選手個別のトレーニング方針を設定する。nullでチーム既定に戻す。
  void setPlayerTrainingFocus(String playerId, TrainingFocus? focus) {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.individualFocus = focus;
    notifyListeners();
    _persist();
  }

  /// ユース昇格候補の個別トレーニング方針を設定する。nullでポジション別の
  /// 既定の育成配分に戻す(TrainingEngine.applyYouthAcademyGrowth参照)。
  void setYouthProspectTrainingFocus(String playerId, TrainingFocus? focus) {
    if (_save == null) return;
    final player = _save!.youthProspects.firstWhere((p) => p.id == playerId);
    player.individualFocus = focus;
    notifyListeners();
    _persist();
  }

  /// 開発者向けのデバッグ機能。資金を任意の額だけ増減させる
  /// (負の値で減額も可能)。設定画面の管理者専用メニューからのみ呼ばれる。
  void addDebugFunds(int amount) {
    if (_save == null) return;
    _save!.budget += amount;
    notifyListeners();
    _persist();
  }

  /// ポジションコンバート特訓の目標ポジションを設定する(nullで解除)。
  /// 生成時に偶然割り当てられた副ポジションとは無関係に、任意のポジション
  /// への転向を目指せる。
  void setPlayerTrainingConvertTarget(String playerId, Position? target) {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.trainingConvertTargetPosition = target?.name;
    notifyListeners();
    _persist();
  }

  /// チームのトレーニング強度(軽め/通常/追い込み)を設定する。
  void setTrainingIntensity(TrainingIntensity intensity) {
    if (_save == null) return;
    userTeam.trainingIntensity = intensity;
    notifyListeners();
    _persist();
  }

  /// 週の中で重点的にトレーニングを行う曜日(1=月〜5=金)を設定する。
  void setTrainingDayOfWeek(int weekday) {
    if (_save == null) return;
    userTeam.trainingDayOfWeek = weekday;
    notifyListeners();
    _persist();
  }

  /// 週次トレーニングの自動実施の有効/無効を切り替える。有効な場合、
  /// 毎節の進行時に未実施であれば既定の方針・強度で自動的に実施する。
  void setAutoTrainingEnabled(bool enabled) {
    if (_save == null) return;
    userTeam.autoTrainingEnabled = enabled;
    notifyListeners();
    _persist();
  }

  /// 選手にメンター(指導役のベテラン)を指名する。[minMentorAge]未満の選手や
  /// 本人自身は指名できない。nullで解除する。
  bool setMentor(String menteeId, String? mentorId) {
    if (_save == null) return false;
    final mentee = userTeam.players.firstWhere((p) => p.id == menteeId);
    if (mentorId == null) {
      mentee.mentorId = null;
      notifyListeners();
      _persist();
      return true;
    }
    if (mentorId == menteeId) return false;
    Player? mentor;
    for (final p in userTeam.players) {
      if (p.id == mentorId) {
        mentor = p;
        break;
      }
    }
    if (mentor == null || mentor.age < TrainingEngine.minMentorAge) {
      return false;
    }
    mentee.mentorId = mentorId;
    notifyListeners();
    _persist();
    return true;
  }

  /// 同時にピンポイント特訓ドリルを指定できる人数の上限。ヘッドコーチの
  /// レベルが高いほど、より多くの選手を同時に個別指導できる。
  int get maxDrillSlots =>
      _save == null ? 1 : _save!.infrastructure.staffLevel(StaffRole.headCoach);

  /// 選手のピンポイント特訓ドリル(重点的に伸ばす1属性)を設定する。nullで解除。
  /// 既に[maxDrillSlots]人が指定済みの場合、新規の指定はfalseを返し失敗する
  /// (解除・指定済み選手の対象属性変更は上限に関係なく常に可能)。
  bool setDrillAttribute(String playerId, String? attributeKey) {
    if (_save == null) return false;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    if (attributeKey != null && player.drillAttributeKey == null) {
      final activeCount =
          userTeam.players.where((p) => p.drillAttributeKey != null).length;
      if (activeCount >= maxDrillSlots) return false;
    }
    player.drillAttributeKey = attributeKey;
    notifyListeners();
    _persist();
    return true;
  }

  /// 選手の2つ目のピンポイント特訓ドリルを設定する。nullで解除。
  /// 1つ目のドリルとは独立して[maxDrillSlots]の上限が適用される。
  bool setDrillAttribute2(String playerId, String? attributeKey) {
    if (_save == null) return false;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    if (attributeKey != null && player.drillAttributeKey2 == null) {
      final activeCount =
          userTeam.players.where((p) => p.drillAttributeKey2 != null).length;
      if (activeCount >= maxDrillSlots) return false;
    }
    player.drillAttributeKey2 = attributeKey;
    notifyListeners();
    _persist();
    return true;
  }

  /// 選手個別の特性特訓の目標特性を設定する。nullで解除。既に特性を
  /// 保有している選手にも設定自体は可能(効果が発現しないだけ)。
  void setTraitTrainingTarget(String playerId, PlayerTrait? target) {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.traitTrainingTarget = target;
    notifyListeners();
    _persist();
  }

  /// 選手個別のローテーション方針(週替わりで自動的に切り替わる複数方針)を
  /// 設定する。nullまたは空リストで解除し、個別方針/チーム既定方針に戻る。
  void setPlayerFocusRotation(String playerId, List<TrainingFocus>? rotation) {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.focusRotation =
        (rotation == null || rotation.isEmpty) ? null : rotation;
    player.rotationWeekIndex = 0;
    notifyListeners();
    _persist();
  }

  /// 監督としての生涯経験値(通算勝敗・トロフィー・実績解除数から算出)。
  int get managerCareerXp => _save == null
      ? 0
      : ManagerCareerEngine.xpFor(
          careerWins: _save!.careerWins,
          careerDraws: _save!.careerDraws,
          trophyCount: _save!.trophyHistory.length,
          unlockedAchievementCount: _save!.unlockedAchievements.length,
        );

  /// 監督としての生涯成長レベル(1〜[ManagerCareerEngine.maxLevel])。
  int get managerCareerLevel => ManagerCareerEngine.levelFor(managerCareerXp);

  /// 次のレベルまでに必要な残り経験値。
  int get managerCareerXpToNextLevel =>
      ManagerCareerEngine.xpToNextLevel(managerCareerXp);

  /// 現在のレベル内での経験値の進捗割合(0.0〜1.0)。
  double get managerCareerProgressFraction =>
      ManagerCareerEngine.progressFractionFor(managerCareerXp);

  /// 生涯成長レベルによる選手成長効率の永続ボーナス倍率。
  double get managerCareerGrowthBonus =>
      ManagerCareerEngine.growthBonusFor(managerCareerLevel);

  Future<bool> runWeeklyTraining() async {
    if (_save == null) return false;
    if (_save!.trainingDoneThisWeek) return false;
    final infra = _save!.infrastructure;
    final overallBefore = {for (final p in userTeam.players) p.id: p.overall};
    final attrsBefore = {
      for (final p in userTeam.players)
        p.id: Map<String, int>.from(p.attributes),
    };
    TrainingEngine.applyWeeklyTraining(
      userTeam,
      headCoachLevel: infra.staffLevel(StaffRole.headCoach),
      trainingGroundLevel: infra.facilityLevel(FacilityType.trainingGround),
      fitnessCoachLevel: infra.staffLevel(StaffRole.fitnessCoach),
      injuryFactor: _userInjuryFactor,
      careerGrowthBonus: managerCareerGrowthBonus,
    );
    _save!.trainingDoneThisWeek = true;
    lastTrainingResults = _diffTrainingResults(overallBefore, attrsBefore);
    notifyListeners();
    await _persist();
    return true;
  }

  /// トレーニング前後の総合力・属性を比較し、実際に変化があった選手のみを返す。
  List<PlayerGrowthSummary> _diffTrainingResults(
    Map<String, int> overallBefore,
    Map<String, Map<String, int>> attrsBefore,
  ) {
    final changes = <PlayerGrowthSummary>[];
    for (final p in userTeam.players) {
      final prevOverall = overallBefore[p.id];
      final prevAttrs = attrsBefore[p.id];
      if (prevOverall == null || prevAttrs == null) continue;
      final deltas = <String, int>{};
      for (final entry in p.attributes.entries) {
        final before = prevAttrs[entry.key] ?? entry.value;
        if (entry.value != before) deltas[entry.key] = entry.value - before;
      }
      if (deltas.isNotEmpty ||
          p.overall != prevOverall ||
          p.acquiredTraitThisWeek != null) {
        changes.add(
          PlayerGrowthSummary(
            playerId: p.id,
            playerName: p.name,
            overallBefore: prevOverall,
            overallAfter: p.overall,
            attributeDeltas: deltas,
            isBreakthrough: p.hadBreakthroughThisWeek,
            acquiredTrait: p.acquiredTraitThisWeek,
          ),
        );
      }
    }
    changes.sort((a, b) => b.overallDelta.compareTo(a.overallDelta));
    return changes;
  }

  /// スタッフ雇用・昇格の費用(万円)。上限レベルなら0を返す。
  int staffUpgradeCostFor(StaffRole role) {
    if (_save == null) return 0;
    final lvl = _save!.infrastructure.staffLevel(role);
    return ClubInfrastructure.staffUpgradeCost(lvl);
  }

  int facilityUpgradeCostFor(FacilityType type) {
    if (_save == null) return 0;
    final lvl = _save!.infrastructure.facilityLevel(type);
    return ClubInfrastructure.facilityUpgradeCost(lvl);
  }

  Future<bool> upgradeStaff(StaffRole role) async {
    if (_save == null) return false;
    final infra = _save!.infrastructure;
    final lvl = infra.staffLevel(role);
    if (lvl >= ClubInfrastructure.maxLevel) return false;
    final cost = ClubInfrastructure.staffUpgradeCost(lvl);
    if (_save!.budget < cost) return false;
    _save!.budget -= cost;
    infra.upgradeStaff(role);
    notifyListeners();
    await _persist();
    return true;
  }

  Future<bool> upgradeFacility(FacilityType type) async {
    if (_save == null) return false;
    final infra = _save!.infrastructure;
    final lvl = infra.facilityLevel(type);
    if (lvl >= ClubInfrastructure.maxLevel) return false;
    final cost = ClubInfrastructure.facilityUpgradeCost(lvl);
    if (_save!.budget < cost) return false;
    _save!.budget -= cost;
    infra.upgradeFacility(type);
    notifyListeners();
    await _persist();
    return true;
  }

  /// チケット価格戦略を切り替える(観客動員率と1人あたり収入のトレードオフ)。
  Future<void> setTicketPricing(TicketPricing pricing) async {
    if (_save == null) return;
    _save!.ticketPricing = pricing;
    notifyListeners();
    await _persist();
  }

  void setPressing(int value) {
    if (_save == null) return;
    userTeam.pressing = value.clamp(0, 100);
    notifyListeners();
    _persist();
  }

  void setLineHeight(int value) {
    if (_save == null) return;
    userTeam.lineHeight = value.clamp(0, 100);
    notifyListeners();
    _persist();
  }

  void setWidth(int value) {
    if (_save == null) return;
    userTeam.width = value.clamp(0, 100);
    notifyListeners();
    _persist();
  }

  void setTempo(int value) {
    if (_save == null) return;
    userTeam.tempo = value.clamp(0, 100);
    notifyListeners();
    _persist();
  }

  /// 選手のデューティ(守備的/バランス/攻撃的)を設定する。
  void setPlayerDuty(String playerId, PlayerDuty duty) {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.duty = duty;
    notifyListeners();
    _persist();
  }

  /// 選手のプレースタイル(ロール)を設定する。
  void setPlayerRole(String playerId, PlayerRole role) {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.role = role;
    notifyListeners();
    _persist();
  }

  /// キャプテンを指名する。既に副キャプテンだった場合はその指名を解除する。
  Future<void> setCaptain(String? playerId) async {
    if (_save == null) return;
    userTeam.captainId = playerId;
    if (playerId != null && userTeam.viceCaptainId == playerId) {
      userTeam.viceCaptainId = null;
    }
    notifyListeners();
    await _persist();
  }

  /// 副キャプテンを指名する。既にキャプテンだった場合はその指名を解除する。
  Future<void> setViceCaptain(String? playerId) async {
    if (_save == null) return;
    userTeam.viceCaptainId = playerId;
    if (playerId != null && userTeam.captainId == playerId) {
      userTeam.captainId = null;
    }
    notifyListeners();
    await _persist();
  }

  /// PK(ペナルティキック)の担当選手を指名する。
  void setPenaltyTaker(String? playerId) {
    if (_save == null) return;
    userTeam.penaltyTakerId = playerId;
    notifyListeners();
    _persist();
  }

  /// 直接FK(フリーキック)の担当選手を指名する。
  void setFreeKickTaker(String? playerId) {
    if (_save == null) return;
    userTeam.freeKickTakerId = playerId;
    notifyListeners();
    _persist();
  }

  /// CK(コーナーキック)の担当選手を指名する。
  void setCornerTaker(String? playerId) {
    if (_save == null) return;
    userTeam.cornerTakerId = playerId;
    notifyListeners();
    _persist();
  }

  /// 相手のセットプレー(CK・FK)を守る担当選手を指名する。
  void setSetPieceDefender(String? playerId) {
    if (_save == null) return;
    userTeam.setPieceDefenderId = playerId;
    notifyListeners();
    _persist();
  }

  /// 次の自チームの試合で相手のキープレイヤーにマンマークを付ける
  /// 自チームの選手を指名する。
  void setManMarker(String? playerId) {
    if (_save == null) return;
    userTeam.manMarkerId = playerId;
    notifyListeners();
    _persist();
  }

  /// 逃げ切りモードの有効・無効を切り替える。有効時は自チームの攻撃力が
  /// やや下がる代わりに守備が安定し、疲労蓄積も抑えられる。
  void setTimeWastingMode(bool enabled) {
    if (_save == null) return;
    userTeam.timeWastingMode = enabled;
    notifyListeners();
    _persist();
  }

  /// 試合前・ハーフタイムの檄。トーンに応じて先発イレブンの士気を変動
  /// させる。性格ごとの結果感応度(resultSensitivity)が大きい選手ほど
  /// 変動幅が大きい。
  void giveTeamTalk(TeamTalkTone tone) {
    if (_save == null) return;
    for (final p in userTeam.players.where(
      (p) => userTeam.startingXI.contains(p.id),
    )) {
      final base = tone.baseMoraleDeltaFor(p.personality);
      final delta = (base * p.personality.resultSensitivity).round();
      p.morale = (p.morale + delta).clamp(0, 100);
    }
    notifyListeners();
    _persist();
  }

  void setFormation(Formation formation) {
    if (_save == null) return;
    userTeam.formation = formation;
    LineupUtils.autoFill(userTeam);
    notifyListeners();
    _persist();
  }

  /// 現在の戦術設定(フォーメーション・各種スライダー・セットプレー担当)を
  /// 名前を付けて保存する。同名の既存プリセットがあれば上書きし、新規の
  /// 場合は[maxTacticPresets]件を超えないよう最も古いものから削除する。
  void saveTacticPreset(String name) {
    if (_save == null) return;
    final team = userTeam;
    final preset = TacticPreset(
      name: name,
      formation: team.formation,
      pressing: team.pressing,
      lineHeight: team.lineHeight,
      width: team.width,
      tempo: team.tempo,
      penaltyTakerId: team.penaltyTakerId,
      freeKickTakerId: team.freeKickTakerId,
      cornerTakerId: team.cornerTakerId,
    );
    final existingIndex = team.tacticPresets.indexWhere((p) => p.name == name);
    if (existingIndex >= 0) {
      team.tacticPresets[existingIndex] = preset;
    } else {
      if (team.tacticPresets.length >= maxTacticPresets) {
        team.tacticPresets.removeAt(0);
      }
      team.tacticPresets.add(preset);
    }
    notifyListeners();
    _persist();
  }

  /// 保存済みの戦術プリセットを現在の設定へ適用する。
  void applyTacticPreset(String name) {
    if (_save == null) return;
    final team = userTeam;
    if (team.tacticPresets.isEmpty) return;
    final preset = team.tacticPresets.firstWhere(
      (p) => p.name == name,
      orElse: () => team.tacticPresets.first,
    );
    team.formation = preset.formation;
    team.pressing = preset.pressing;
    team.lineHeight = preset.lineHeight;
    team.width = preset.width;
    team.tempo = preset.tempo;
    final rosterIds = team.players.map((p) => p.id).toSet();
    // プリセット保存後に売却・引き抜き等で離脱した選手が指名されたままに
    // ならないよう、現在のスカッドに残っている場合のみ復元する。
    team.penaltyTakerId = rosterIds.contains(preset.penaltyTakerId)
        ? preset.penaltyTakerId
        : null;
    team.freeKickTakerId = rosterIds.contains(preset.freeKickTakerId)
        ? preset.freeKickTakerId
        : null;
    team.cornerTakerId =
        rosterIds.contains(preset.cornerTakerId) ? preset.cornerTakerId : null;
    LineupUtils.autoFill(team);
    notifyListeners();
    _persist();
  }

  /// 保存済みの戦術プリセットを削除する。
  void deleteTacticPreset(String name) {
    if (_save == null) return;
    userTeam.tacticPresets.removeWhere((p) => p.name == name);
    notifyListeners();
    _persist();
  }

  /// デプスチャート(ポジション別控え順)を手動で入れ替える。
  /// [oldIndex]/[newIndex]は`ReorderableListView.onReorderItem`から渡される
  /// 値をそのまま使う想定(newIndexは削除後の挿入位置に調整済み)。
  void reorderDepthChart(Position position, int oldIndex, int newIndex) {
    if (_save == null) return;
    final team = userTeam;
    final current = team.depthChartFor(position).map((p) => p.id).toList();
    final id = current.removeAt(oldIndex);
    current.insert(newIndex, id);
    team.depthChartOrder[position.name] = current;
    notifyListeners();
    _persist();
  }

  void autoFillStartingXI() {
    if (_save == null) return;
    LineupUtils.autoFill(userTeam);
    notifyListeners();
    _persist();
  }

  /// スタメン入り/除外を切り替える。フォーメーションのポジション別人数上限を超える場合は無視する。
  void toggleStartingPlayer(String playerId) {
    if (_save == null) return;
    final team = userTeam;
    final player = team.players.firstWhere((p) => p.id == playerId);
    if (player.isInjured || player.isSuspended) return;

    if (team.startingXI.contains(playerId)) {
      team.startingXI.remove(playerId);
    } else {
      final quota = team.formation.quotaFor(player.position);
      final currentInPosition = team.startingXI
          .map((id) => team.players.firstWhere((p) => p.id == id))
          .where((p) => p.position == player.position)
          .length;
      if (currentInPosition >= quota) return;
      team.startingXI.add(playerId);
    }
    notifyListeners();
    _persist();
  }

  /// スタメンの特定選手を別の選手と入れ替える(戦術画面のピッチタップ操作用)。
  /// クォータ判定は行わず、指定された選手をそのまま入れ替える。
  /// 疲労の溜まったスタメンを、より疲労の少ないベンチ選手に入れ替える提案。
  List<RotationSuggestion> get rotationSuggestions =>
      _save == null ? [] : RotationEngine.suggest(userTeam);

  void swapStartingPlayer({String? outPlayerId, required String inPlayerId}) {
    if (_save == null) return;
    final team = userTeam;
    if (outPlayerId != null) team.startingXI.remove(outPlayerId);
    if (!team.startingXI.contains(inPlayerId)) team.startingXI.add(inPlayerId);
    notifyListeners();
    _persist();
  }

  Future<bool> buyPlayer(String playerId) async {
    if (_save == null) return false;
    if (!isTransferWindowOpen) return false;
    final idx = transferMarket.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    final player = transferMarket[idx];
    if (_save!.budget < player.marketValue) return false;
    if (userTeam.players.length >= maxSquadSize) return false;
    _save!.budget -= player.marketValue;
    userTeam.players.add(player);
    transferMarket.removeWhere((p) => p.id == playerId);
    notifyListeners();
    await _persist();
    return true;
  }

  /// 選手がチームを離れる際、キャプテンやセットプレー担当など個別の役割
  /// 指名にその選手のIDが残ったままにならないよう解除する。あわせて、
  /// その選手を対象にした契約交渉・分割払い残金が進行中であれば破棄する。
  void _clearPlayerRoleReferences(Team team, String playerId) {
    if (team.captainId == playerId) team.captainId = null;
    if (team.viceCaptainId == playerId) team.viceCaptainId = null;
    if (team.penaltyTakerId == playerId) team.penaltyTakerId = null;
    if (team.freeKickTakerId == playerId) team.freeKickTakerId = null;
    if (team.cornerTakerId == playerId) team.cornerTakerId = null;
    if (team.manMarkerId == playerId) team.manMarkerId = null;
    if (team.setPieceDefenderId == playerId) team.setPieceDefenderId = null;
    if (_save?.pendingContractNegotiation?.playerId == playerId) {
      _save!.pendingContractNegotiation = null;
    }
    _save?.pendingInstallments.removeWhere((i) => i.playerId == playerId);
  }

  /// 放出により実際に得られる(あるいは支払う)純額。移籍金収入から
  /// 契約解除の違約金を差し引いたもので、負の値になり得る。
  int netReleaseValueFor(String playerId) {
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    final sellPrice = (player.marketValue * 0.7).round();
    return sellPrice - ContractEngine.releaseSeverance(player);
  }

  Future<bool> sellPlayer(String playerId) async {
    if (_save == null) return false;
    if (!isTransferWindowOpen) return false;
    final team = userTeam;
    if (team.players.length <= minSquadSize) return false;
    final player = team.players.firstWhere((p) => p.id == playerId);
    if (player.isLoan) return false; // ローン選手は他クラブの所有物のため放出できない
    if (player.isLoanedOut) return false; // ローン放出中の選手は貸出先が保有しているため放出できない
    final net = netReleaseValueFor(playerId);
    team.players.removeWhere((p) => p.id == playerId);
    team.startingXI.remove(playerId);
    _clearPlayerRoleReferences(team, playerId);
    _save!.budget += net;
    notifyListeners();
    await _persist();
    return true;
  }

  int renewalCostFor(String playerId) {
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    return ContractEngine.renewalCost(player);
  }

  /// 契約更新時に一括で必要なサインボーナス(万円)。
  int signingBonusFor(String playerId) {
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    return ContractEngine.signingBonusFor(player);
  }

  /// 契約更新後、リーグ公式戦にスタメン出場するたびに支払う出場手当(万円)。
  int appearanceFeeFor(String playerId) {
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    return ContractEngine.appearanceFeeFor(player);
  }

  /// 指定選手の今シーズンの成績(出場・得点・カード・平均採点)を、
  /// リーグ戦の消化済み試合結果から都度集計する。
  PlayerSeasonStats seasonStatsFor(String playerId) {
    if (_save == null) return const PlayerSeasonStats();
    int appearances = 0, goals = 0, yellowCards = 0, redCards = 0;
    double ratingSum = 0;
    for (final f in _save!.league.fixtures) {
      final r = f.result;
      if (r == null) continue;
      final rating = r.playerRatings[playerId];
      if (rating != null) {
        appearances++;
        ratingSum += rating;
      }
      for (final e in r.events) {
        if (e.scorerId != playerId) continue;
        switch (e.type) {
          case MatchEventType.goal:
            goals++;
            break;
          case MatchEventType.yellowCard:
            yellowCards++;
            break;
          case MatchEventType.redCard:
            redCards++;
            break;
          case MatchEventType.chance:
            break;
        }
      }
    }
    return PlayerSeasonStats(
      appearances: appearances,
      goals: goals,
      yellowCards: yellowCards,
      redCards: redCards,
      averageRating: appearances == 0 ? null : ratingSum / appearances,
    );
  }

  Future<bool> renewContract(String playerId) async {
    if (_save == null) return false;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    if (player.isLoan) return false; // ローン選手には通常の契約更新は適用されない
    final cost = ContractEngine.renewalCost(player) +
        ContractEngine.signingBonusFor(player);
    if (_save!.budget < cost) return false;
    _save!.budget -= cost;
    ContractEngine.renewContract(player);
    notifyListeners();
    await _persist();
    return true;
  }

  /// 進行中の契約交渉(週俸の駆け引き)。ない場合はnull。
  ContractNegotiation? get pendingContractNegotiation =>
      _save?.pendingContractNegotiation;

  /// 選手との週俸交渉を開始する(現在の週俸を起点に、選手側の最低希望額を提示する)。
  void startContractNegotiation(String playerId) {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    if (player.isLoan) return;
    _save!.pendingContractNegotiation = ContractNegotiation(
      playerId: playerId,
      initialWage: player.wage,
      offeredWage: player.wage,
      counterWage: ContractEngine.initialDemand(player),
    );
    notifyListeners();
    _persist();
  }

  /// 交渉中の選手に週俸を提示する。選手の最低希望額以上ならその場で合意成立
  /// (契約更新の基本費用・サインボーナスの支払いが必要)。届かなければ選手側
  /// から対案が届き交渉が続く。規定回数を超えると選手は交渉から離脱する。
  Future<ContractOfferResult> offerContractWage(int wage) async {
    if (_save == null || _save!.pendingContractNegotiation == null) {
      return ContractOfferResult.walkedAway;
    }
    final negotiation = _save!.pendingContractNegotiation!;
    Player? player;
    for (final p in userTeam.players) {
      if (p.id == negotiation.playerId) {
        player = p;
        break;
      }
    }
    if (player == null) {
      // 交渉相手が何らかの理由で既にチームを離れている(インポートされた
      // セーブなど)場合は、交渉自体を破棄して安全に終了する。
      _save!.pendingContractNegotiation = null;
      notifyListeners();
      await _persist();
      return ContractOfferResult.walkedAway;
    }
    final minAcceptable = ContractEngine.minimumAcceptableWage(player);
    if (wage >= minAcceptable) {
      final cost = ContractEngine.renewalCost(player) +
          ContractEngine.signingBonusFor(player);
      if (_save!.budget < cost) return ContractOfferResult.insufficientFunds;
      _save!.budget -= cost;
      player.wage = wage;
      ContractEngine.renewContract(player);
      _save!.pendingContractNegotiation = null;
      notifyListeners();
      await _persist();
      return ContractOfferResult.accepted;
    }
    negotiation.roundsUsed += 1;
    if (negotiation.roundsUsed >= ContractEngine.maxNegotiationRounds) {
      _save!.pendingContractNegotiation = null;
      notifyListeners();
      await _persist();
      return ContractOfferResult.walkedAway;
    }
    negotiation.offeredWage = wage;
    negotiation.counterWage = ContractEngine.counterOffer(player, wage);
    notifyListeners();
    await _persist();
    return ContractOfferResult.countered;
  }

  /// 契約交渉を打ち切る。
  void cancelContractNegotiation() {
    if (_save == null) return;
    _save!.pendingContractNegotiation = null;
    notifyListeners();
    _persist();
  }

  /// 選手と話し合い、不満度を引き上げる。既に十分満足している場合は失敗する。
  Future<bool> reassurePlayer(String playerId) async {
    if (_save == null) return false;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    final ok = HappinessEngine.reassure(player);
    if (ok) {
      notifyListeners();
      await _persist();
    }
    return ok;
  }

  /// 個別声かけ(モチベーショントーク)の基礎士気上昇量とクールダウン週数。
  /// reassure(不満度)とは異なり士気(morale)を対象にした、より短い周期で
  /// 使える個別コマンド。
  static const int talkBaseMoraleBoost = 10;
  static const int talkCooldownWeeks = 3;

  /// 選手個別に声をかけ、士気を高める。効果は性格の結果感応度で変動する
  /// (T10の檄と同じ考え方)。クールダウン中は実施できない。
  Future<bool> talkToPlayer(String playerId) async {
    if (_save == null) return false;
    final idx = userTeam.players.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    final player = userTeam.players[idx];
    if (player.talkCooldownWeeks > 0) return false;
    final delta =
        (talkBaseMoraleBoost * player.personality.resultSensitivity).round();
    player.morale = (player.morale + delta).clamp(0, 100);
    player.talkCooldownWeeks = talkCooldownWeeks;
    notifyListeners();
    await _persist();
    return true;
  }

  /// 戦術ミーティングの再実施までのクールダウン週数。
  static const int tacticalMeetingCooldownWeeks = 3;

  /// スカッド全体で戦術ミーティングを行い、判断力・位置取り・チームワークを
  /// 小幅に伸ばす。クールダウン中は実施できない。
  Future<bool> holdTacticalMeeting() async {
    if (_save == null) return false;
    if (userTeam.tacticalMeetingCooldownWeeks > 0) return false;
    TrainingEngine.applyTacticalMeeting(userTeam.players);
    userTeam.tacticalMeetingCooldownWeeks = tacticalMeetingCooldownWeeks;
    notifyListeners();
    await _persist();
    return true;
  }

  /// 分割払い(頭金3割 + 残額を4週で均等払い)で移籍市場の選手を獲得する。
  Future<bool> buyPlayerOnInstallments(String playerId) async {
    if (_save == null) return false;
    if (!isTransferWindowOpen) return false;
    final idx = transferMarket.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    if (userTeam.players.length >= maxSquadSize) return false;
    final player = transferMarket[idx];
    final total = player.marketValue;
    final downPayment = (total * 0.3).round();
    if (_save!.budget < downPayment) return false;

    _save!.budget -= downPayment;
    const weeks = 4;
    final remaining = total - downPayment;
    _save!.pendingInstallments.add(
      Installment(
        description: '${player.name} 分割払い残金',
        weeklyAmount: (remaining / weeks).ceil(),
        weeksRemaining: weeks,
        playerId: player.id,
      ),
    );
    userTeam.players.add(player);
    transferMarket.removeAt(idx);
    notifyListeners();
    await _persist();
    return true;
  }

  /// ローン(期限付き移籍)で移籍市場の選手を獲得する。頭金は移籍金の2割、
  /// 週俸は6割に軽減される代わりに20週で自動的にチームを離れる。
  static const int loanFeeRatioPercent = 20;
  static const int loanDurationWeeks = 20;

  /// 買取オプション付きローンの場合の買取金額(移籍金に対する割合)。
  static const double loanBuyOptionRatio = 0.6;

  Future<bool> signLoanPlayer(
    String playerId, {
    bool withBuyOption = false,
  }) async {
    if (_save == null) return false;
    if (!isTransferWindowOpen) return false;
    final idx = transferMarket.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    if (userTeam.players.length >= maxSquadSize) return false;
    final player = transferMarket[idx];
    final fee = (player.marketValue * loanFeeRatioPercent / 100).round();
    if (_save!.budget < fee) return false;

    _save!.budget -= fee;
    player.isLoan = true;
    player.loanWeeksRemaining = loanDurationWeeks;
    player.wage = (player.wage * 0.6).round().clamp(1, 999);
    player.loanBuyOptionFee = withBuyOption
        ? (player.marketValue * loanBuyOptionRatio).round()
        : null;
    // 前クラブで設定されていた解放条項が残っていると、ローン中の選手が
    // 自動移籍オファーの対象になってしまうため解除する。
    player.releaseClause = null;
    userTeam.players.add(player);
    transferMarket.removeAt(idx);
    notifyListeners();
    await _persist();
    return true;
  }

  /// ローン契約に付いている買取オプションを行使し、ローン中の選手を恒久的に
  /// 完全移籍(自クラブの正式な選手)に切り替える。
  Future<bool> exerciseLoanBuyOption(String playerId) async {
    if (_save == null) return false;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    if (!player.isLoan || player.loanBuyOptionFee == null) return false;
    final fee = player.loanBuyOptionFee!;
    if (_save!.budget < fee) return false;

    _save!.budget -= fee;
    player.isLoan = false;
    player.loanWeeksRemaining = 0;
    player.loanBuyOptionFee = null;
    // ローン中は週俸を6割に軽減していた(signLoanPlayer)ため、完全移籍化に
    // あたって元の水準に戻す。そのままだと恒久的に割引契約のままになる。
    player.wage = (player.wage / 0.6).round().clamp(1, 999);
    player.contractYearsRemaining = ContractEngine.negotiatedYears(player);
    notifyListeners();
    await _persist();
    return true;
  }

  /// 契約中のスポンサーがなければ、次に選べる候補を返す(既に選択済みならnull)。
  List<SponsorDeal> get pendingSponsorOffers =>
      _save?.pendingSponsorOffers ?? [];

  Future<bool> chooseSponsor(int offerIndex) async {
    if (_save == null) return false;
    if (offerIndex < 0 || offerIndex >= _save!.pendingSponsorOffers.length) {
      return false;
    }
    _save!.sponsorDeal = _save!.pendingSponsorOffers[offerIndex];
    _save!.pendingSponsorOffers = [];
    notifyListeners();
    await _persist();
    return true;
  }

  int get scoutCost => _save == null
      ? 0
      : ScoutingEngine.scoutCostFor(
          _save!.infrastructure.staffLevel(StaffRole.scout),
        );

  int get maxYouthProspects => _save == null
      ? 0
      : ScoutingEngine.maxProspectsFor(
          _save!.infrastructure.facilityLevel(FacilityType.youthFacility),
        );

  /// 昇格候補がユース施設で育つ速さの係数(表示用)。ユース施設のレベルが
  /// 高いほど、昇格を焦らずじっくり育てる価値が生まれる。
  double get youthAcademyGrowthFactor => _save == null
      ? 0
      : TrainingEngine.youthAcademyGrowthFactor(
          _save!.infrastructure.facilityLevel(FacilityType.youthFacility),
        );

  /// スカウト網が一度に見つけてくる候補選手の人数(スカウトのレベルが高いほど広がる)。
  int get scoutCandidateCount => _save == null
      ? 0
      : ScoutingEngine.scoutCandidateCountFor(
          _save!.infrastructure.staffLevel(StaffRole.scout),
        );

  /// 現在のスカウトのレベル。潜在能力の推定レンジの精度にも影響する。
  int get scoutLevel =>
      _save == null ? 1 : _save!.infrastructure.staffLevel(StaffRole.scout);

  void _refreshScoutCandidates() {
    if (_save == null) {
      scoutCandidates = [];
      return;
    }
    final scoutLevel = _save!.infrastructure.staffLevel(StaffRole.scout);
    final count = ScoutingEngine.scoutCandidateCountFor(scoutLevel);
    scoutCandidates = List.generate(
      count,
      (_) => ScoutingEngine.generateScoutedProspect(scoutLevel: scoutLevel),
    );
  }

  /// スカウト網を手動で更新する1回あたりの費用(万円)。
  int get scoutRefreshCost => _save == null
      ? 0
      : ScoutingEngine.refreshCostFor(
          _save!.infrastructure.staffLevel(StaffRole.scout),
        );

  /// 費用を払ってスカウト網を更新し、候補選手の顔ぶれを一新する。
  /// 資金が足りない場合は何もせずfalseを返す。
  Future<bool> refreshScoutCandidates() async {
    if (_save == null) return false;
    final cost = scoutRefreshCost;
    if (_save!.budget < cost) return false;
    _save!.budget -= cost;
    _refreshScoutCandidates();
    notifyListeners();
    await _persist();
    return true;
  }

  /// 候補選手一覧から1人選んでスカウト費用を払い、ユース昇格候補として迎える。
  Future<bool> scoutProspect(String candidateId) async {
    if (_save == null) return false;
    final idx = scoutCandidates.indexWhere((p) => p.id == candidateId);
    if (idx < 0) return false;
    final infra = _save!.infrastructure;
    final cost = ScoutingEngine.scoutCostFor(infra.staffLevel(StaffRole.scout));
    final maxP = ScoutingEngine.maxProspectsFor(
      infra.facilityLevel(FacilityType.youthFacility),
    );
    if (_save!.budget < cost) return false;
    if (_save!.youthProspects.length >= maxP) return false;
    _save!.budget -= cost;
    final signed = scoutCandidates.removeAt(idx);
    _save!.youthProspects.add(signed);
    final scoutLevel = infra.staffLevel(StaffRole.scout);
    scoutCandidates.add(
      ScoutingEngine.generateScoutedProspect(scoutLevel: scoutLevel),
    );
    notifyListeners();
    await _persist();
    return true;
  }

  Future<bool> promoteYouthProspect(String playerId) async {
    if (_save == null) return false;
    if (userTeam.players.length >= maxSquadSize) return false;
    final idx = _save!.youthProspects.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    final player = _save!.youthProspects.removeAt(idx);
    userTeam.players.add(player);
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> releaseYouthProspect(String playerId) async {
    if (_save == null) return;
    _save!.youthProspects.removeWhere((p) => p.id == playerId);
    notifyListeners();
    await _persist();
  }

  /// シーズン終了時に一括生成された、選抜待ちのユースインテーク候補。
  List<Player> get pendingYouthIntake => _save?.pendingYouthIntake ?? [];

  /// ユースインテーク候補をユース昇格候補として引き取る(枠が一杯なら失敗)。
  Future<bool> keepYouthIntakePlayer(String playerId) async {
    if (_save == null) return false;
    if (_save!.youthProspects.length >= maxYouthProspects) return false;
    final idx = _save!.pendingYouthIntake.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    final player = _save!.pendingYouthIntake.removeAt(idx);
    _save!.youthProspects.add(player);
    notifyListeners();
    await _persist();
    return true;
  }

  /// ユースインテーク候補を解雇する。
  Future<void> releaseYouthIntakePlayer(String playerId) async {
    if (_save == null) return;
    _save!.pendingYouthIntake.removeWhere((p) => p.id == playerId);
    notifyListeners();
    await _persist();
  }

  /// 契約満了で放出された選手やベテラン選手からなる、移籍金なし(週俸のみ)
  /// で獲得できるフリーエージェントのプール。
  List<Player> get freeAgents => _save?.freeAgents ?? [];

  /// フリーエージェントを新規契約で獲得する(移籍金は発生しない)。
  Future<bool> signFreeAgent(String playerId) async {
    if (_save == null) return false;
    if (!isTransferWindowOpen) return false;
    if (userTeam.players.length >= maxSquadSize) return false;
    final idx = _save!.freeAgents.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    final player = _save!.freeAgents.removeAt(idx);
    ContractEngine.renewContract(player);
    userTeam.players.add(player);
    notifyListeners();
    await _persist();
    return true;
  }

  /// 選手のリリース条項(解放金額)を設定・解除する。nullで解除。
  Future<void> setReleaseClause(String playerId, int? amount) async {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.releaseClause = amount;
    notifyListeners();
    await _persist();
  }

  /// 選手の移籍リスト登録状態を切り替える。登録中は他クラブからのオファーが来やすくなる。
  Future<void> setTransferListed(String playerId, bool listed) async {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.isTransferListed = listed;
    notifyListeners();
    await _persist();
  }

  /// 若手有望株ランキングで選手を追跡対象(ウォッチリスト)に指定しているか。
  /// 自クラブ以外の選手も、将来獲得を検討するために追跡できる。
  bool isWatched(String playerId) =>
      _save?.watchlistPlayerIds.contains(playerId) ?? false;

  /// ウォッチリストへの追加・削除を切り替える。
  Future<void> toggleWatched(String playerId) async {
    if (_save == null) return;
    if (!_save!.watchlistPlayerIds.remove(playerId)) {
      _save!.watchlistPlayerIds.add(playerId);
    }
    notifyListeners();
    await _persist();
  }

  static const int loanOutMinWeeks = 4;
  static const int loanOutMaxWeeks = 16;

  /// 自クラブの選手を期限付きで他クラブへローン放出する。放出中は週俸を放出先が
  /// 負担し、自クラブの試合には出場できない。スタメンだった場合は自動で欠員を埋める。
  Future<bool> loanOutPlayer(String playerId, int weeks) async {
    if (_save == null) return false;
    if (!isTransferWindowOpen) return false;
    final team = userTeam;
    if (team.players.length <= minSquadSize) return false;
    final player = team.players.firstWhere((p) => p.id == playerId);
    if (player.isLoan || player.isLoanedOut) return false;

    final candidates =
        _save!.league.teams.where((t) => t.id != _save!.userTeamId).toList();
    if (candidates.isEmpty) return false;
    final destination = candidates[Random().nextInt(candidates.length)];

    player.loanedOutWeeksRemaining = weeks.clamp(
      loanOutMinWeeks,
      loanOutMaxWeeks,
    );
    player.loanedOutToClubName = destination.name;
    final wasStarter = team.startingXI.remove(player.id);
    if (wasStarter) {
      LineupUtils.autoFill(team);
    }
    notifyListeners();
    await _persist();
    return true;
  }

  /// プレシーズン親善試合(1試合分)を消化する。順位やカップ戦には影響しない。
  Future<MatchResult?> playFriendly(int index) async {
    if (_save == null) return null;
    if (index < 0 || index >= _save!.friendlies.length) return null;
    final f = _save!.friendlies[index];
    if (f.result != null) return null;
    final league = _save!.league;
    final home = league.teams.firstWhere((t) => t.id == f.homeTeamId);
    final away = league.teams.firstWhere((t) => t.id == f.awayTeamId);
    // MatchEngine.simulate()は内部でapplyPostMatchEffects()を呼び疲労蓄積・
    // 負傷判定を行ってしまうため、プレシーズン親善試合では使わない。前半・後半を
    // simulateMinutesで直接シミュレートし、疲労・負傷への影響を与えないようにする。
    final weather = WeatherEngine.roll();
    f.weather = weather;
    final first = MatchEngine.simulateMinutes(
      home: home,
      away: away,
      startMinute: 1,
      endMinute: 45,
      weather: weather,
    );
    final second = MatchEngine.simulateMinutes(
      home: home,
      away: away,
      startMinute: 46,
      endMinute: 90,
      weather: weather,
    );
    final friendlyChanceCount = first.chanceCount + second.chanceCount;
    final friendlyHomePossession = friendlyChanceCount > 0
        ? ((first.possessionShareSum + second.possessionShareSum) /
                friendlyChanceCount *
                100)
            .round()
            .clamp(0, 100)
        : 50;
    final result = MatchResult(
      matchday: 0,
      homeTeamId: home.id,
      awayTeamId: away.id,
      homeGoals: first.homeGoals + second.homeGoals,
      awayGoals: first.awayGoals + second.awayGoals,
      events: [...first.events, ...second.events],
      weather: weather,
      homePossession: friendlyHomePossession,
      awayPossession: 100 - friendlyHomePossession,
      homeShots: first.homeShots + second.homeShots,
      awayShots: first.awayShots + second.awayShots,
      homeShotsOnTarget: first.homeShotsOnTarget + second.homeShotsOnTarget,
      awayShotsOnTarget: first.awayShotsOnTarget + second.awayShotsOnTarget,
    );
    f.result = result;
    // 実戦感覚を養う程度の軽い士気向上(疲労・負傷への影響は与えない)。
    for (final p in MatchEngine.lineupOf(userTeam)) {
      p.morale = (p.morale + 3).clamp(0, 100);
    }
    notifyListeners();
    await _persist();
    return result;
  }

  /// 他クラブから届いている、自クラブ選手への移籍オファー。
  List<IncomingOffer> get incomingOffers => _save?.incomingOffers ?? [];

  Future<bool> acceptIncomingOffer(String offerId) async {
    if (_save == null) return false;
    if (!isTransferWindowOpen) return false;
    final idx = _save!.incomingOffers.indexWhere((o) => o.id == offerId);
    if (idx < 0) return false;
    final offer = _save!.incomingOffers[idx];
    final team = userTeam;
    // 対象選手が既にチームを離れている場合(他クラブへの就任・別オファーの
    // 承諾などで既に放出済み)は、対価を得ずにオファーだけを破棄する。
    if (!team.players.any((p) => p.id == offer.playerId)) {
      _save!.incomingOffers.removeAt(idx);
      notifyListeners();
      await _persist();
      return false;
    }
    if (team.players.length <= minSquadSize) return false;
    final player = team.players.firstWhere((p) => p.id == offer.playerId);
    if (player.isLoanedOut) {
      // ローン放出中の選手は貸出先クラブが保有しているため、その間はオファーを
      // 承諾できない(貸出期間が終われば復帰するので、オファー自体は保持する)。
      return false;
    }
    // 同じ選手への他クラブからの対抗オファーは、選手が既に売却されるため無効になる。
    _save!.incomingOffers.removeWhere((o) => o.playerId == offer.playerId);
    team.players.removeWhere((p) => p.id == offer.playerId);
    final wasStarter = team.startingXI.remove(offer.playerId);
    _clearPlayerRoleReferences(team, offer.playerId);
    if (wasStarter) {
      LineupUtils.autoFill(team);
    }
    _save!.budget += offer.amount;
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> declineIncomingOffer(String offerId) async {
    if (_save == null) return;
    _save!.incomingOffers.removeWhere((o) => o.id == offerId);
    notifyListeners();
    await _persist();
  }

  int _incomingOfferSeq = 0;

  /// 移籍オファーの週次処理: 期限切れの削除、新規オファーの抽選発生、
  /// リリース条項の自動成立を行う。売却済み選手の名前を返す(UI通知用)。
  static final Random _offerRng = Random();

  List<String> _advanceIncomingOffers() {
    final autoSold = <String>[];
    for (final o in List<IncomingOffer>.from(_save!.incomingOffers)) {
      o.weeksRemaining -= 1;
      if (o.weeksRemaining <= 0) {
        _save!.incomingOffers.remove(o);
      }
    }

    final team = userTeam;
    if (isTransferWindowOpen && _save!.incomingOffers.length < 3) {
      // 既に1クラブからオファーが来ている選手に、別クラブから対抗の競合
      // オファーが届くことがある(入札合戦。同一選手へのオファーは最大2件まで)。
      final offersByPlayer = <String, List<IncomingOffer>>{};
      for (final o in _save!.incomingOffers) {
        offersByPlayer.putIfAbsent(o.playerId, () => []).add(o);
      }
      final biddablePlayerIds = offersByPlayer.entries
          .where((e) => e.value.length == 1 && !e.value.first.viaReleaseClause)
          .map((e) => e.key)
          .where((id) => team.players.any((p) => p.id == id))
          .toList();
      if (biddablePlayerIds.isNotEmpty && _offerRng.nextDouble() < 0.20) {
        final targetId =
            biddablePlayerIds[_offerRng.nextInt(biddablePlayerIds.length)];
        final target = team.players.firstWhere((p) => p.id == targetId);
        final existing = offersByPlayer[targetId]!.first;
        final rivalCandidates = _save!.league.teams
            .where(
              (t) =>
                  t.id != _save!.userTeamId && t.name != existing.buyerClubName,
            )
            .toList();
        if (rivalCandidates.isNotEmpty) {
          final rival =
              rivalCandidates[_offerRng.nextInt(rivalCandidates.length)];
          final outbid =
              (existing.amount * (1.1 + _offerRng.nextDouble() * 0.2)).round();
          _save!.incomingOffers.add(
            IncomingOffer(
              id: 'offer${_incomingOfferSeq++}',
              playerId: target.id,
              playerName: target.name,
              buyerClubName: rival.name,
              amount: outbid,
            ),
          );
          return autoSold;
        }
      }
    }
    if (isTransferWindowOpen &&
        team.players.length > minSquadSize + 2 &&
        _save!.incomingOffers.length < 3) {
      final eligible = team.players
          .where(
            (p) =>
                !p.isLoan &&
                !p.isLoanedOut &&
                !_save!.incomingOffers.any((o) => o.playerId == p.id),
          )
          .toList();
      // 移籍リストに登録している選手がいるとオファーが来やすくなる。
      final hasListed = eligible.any((p) => p.isTransferListed);
      final triggerChance = hasListed ? 0.30 : 0.12;
      if (eligible.isNotEmpty && _offerRng.nextDouble() < triggerChance) {
        final weights = eligible
            .map(
              (p) =>
                  (p.overall - 30).clamp(1, 99) * (p.isTransferListed ? 3 : 1),
            )
            .toList();
        final totalWeight = weights.fold<int>(0, (s, w) => s + w);
        var r = _offerRng.nextInt(totalWeight);
        var chosen = eligible.last;
        for (int i = 0; i < eligible.length; i++) {
          if (r < weights[i]) {
            chosen = eligible[i];
            break;
          }
          r -= weights[i];
        }

        final buyerCandidates = _save!.league.teams
            .where((t) => t.id != _save!.userTeamId)
            .toList();
        final buyer =
            buyerCandidates[_offerRng.nextInt(buyerCandidates.length)];

        if (chosen.releaseClause != null) {
          // リリース条項がある場合は交渉なしで即成立する。
          final amount = chosen.releaseClause!;
          team.players.removeWhere((p) => p.id == chosen.id);
          final wasStarter = team.startingXI.remove(chosen.id);
          if (wasStarter) {
            // スタメンが抜けた穴を自動で埋める(次の試合が即座に行われるため、
            // ユーザーが手動で編成を直す猶予がない)。
            LineupUtils.autoFill(team);
          }
          _clearPlayerRoleReferences(team, chosen.id);
          _save!.budget += amount;
          autoSold.add(chosen.name);
        } else {
          final amount =
              (chosen.marketValue * (0.9 + _offerRng.nextDouble() * 0.4))
                  .round();
          _save!.incomingOffers.add(
            IncomingOffer(
              id: 'offer${_incomingOfferSeq++}',
              playerId: chosen.id,
              playerName: chosen.name,
              buyerClubName: buyer.name,
              amount: amount,
            ),
          );
        }
      }
    }
    return autoSold;
  }

  /// 直近のplayNextMatchdayでリリース条項により自動売却された選手名。
  List<String> lastReleaseClauseSales = [];

  /// 直近のplayNextMatchdayで代表召集された選手名。
  List<String> lastInternationalCallUps = [];

  /// 直近のplayNextMatchdayでローン放出から復帰した選手名。
  List<String> lastLoanReturns = [];

  /// 直近のplayNextMatchdayで満期を迎え、利息込みで払い戻された定期預金。
  List<FixedDeposit> lastMaturedDeposits = [];

  /// 直近のplayNextMatchdayで発生したCPUクラブ同士の移籍ニュース。ない場合はnull。
  String? lastAiTransferNews;

  /// 直近のplaySecondHalfでユーザーが月間最優秀監督賞を受賞した場合の対象節ラベル。ない場合はnull。
  String? lastMonthlyManagerAward;

  /// 直近のstartNextSeasonでユーザーが年間最優秀監督賞を受賞したかどうか。
  bool lastSeasonManagerAwardWon = false;

  /// 直近のplayNextMatchdayでスタメン出場手当として支払った総額(万円)。
  int lastAppearanceFeesPaid = 0;

  /// 資金マイナスの長期化により理事会の信頼度が下がった場合の警告文。ない場合はnull。
  String? lastBudgetCrisisWarning;

  static final Random _dutyRng = Random();
  static final Random _aiTransferRng = Random();

  /// 代表召集の週次処理: 期間終了・新規招集抽選を行う(ユーザークラブのみ)。
  /// スタメンから招集された場合は自動で欠員を埋める。招集された選手名を返す(UI通知用)。
  List<String> _advanceInternationalDuty() {
    final team = userTeam;
    for (final p in team.players) {
      if (p.internationalDutyWeeksRemaining > 0) {
        p.internationalDutyWeeksRemaining -= 1;
      }
    }

    final called = <String>[];
    var lineupChanged = false;
    final eligible = team.players.where(
      (p) =>
          !p.isInjured &&
          !p.isLoan &&
          !p.isOnInternationalDuty &&
          p.overall >= 78,
    );
    for (final p in eligible) {
      if (_dutyRng.nextDouble() < 0.06) {
        p.internationalDutyWeeksRemaining = 1 + _dutyRng.nextInt(2);
        called.add(p.name);
        if (team.startingXI.contains(p.id)) lineupChanged = true;
      }
    }
    if (lineupChanged) {
      LineupUtils.autoFill(team);
    }
    return called;
  }

  /// 監督としての世間の評価(0-100)。
  int get managerReputation => _save?.managerReputation ?? 50;

  /// ユーザークラブが現在所属するディビジョン(1が最上位、[totalDivisionTiers]が最下位)。
  int get currentDivisionTier => _save?.currentDivisionTier ?? 1;

  /// 画面表示用のリーグ名(2部以下所属時は「〇〇リーグ2部」のように部を付記する)。
  String get leagueDisplayName => currentDivisionTier == 1
      ? _save?.leagueName ?? 'リーグ'
      : '${_save!.leagueName}$currentDivisionTier部';

  /// 保存されているリーグ名から国風テーマを逆引きする(テーマ自体は
  /// SaveGameに保持していないため、開幕時に確定した表示名から復元する)。
  LeagueTheme get currentLeagueTheme => LeagueTheme.values.firstWhere(
        (t) => t.label == _save?.leagueName,
        orElse: () => LeagueTheme.england,
      );

  /// シーズンごとに確定した個人タイトル(得点王・年間MVP)の履歴。新しい順。
  List<SeasonAward> get seasonAwards =>
      (_save?.seasonAwards ?? const <SeasonAward>[]).reversed.toList();

  List<SeasonRecord> get seasonHistory =>
      (_save?.seasonHistory ?? const <SeasonRecord>[]).reversed.toList();

  List<SeasonBestEleven> get bestElevenHistory =>
      (_save?.bestElevenHistory ?? const <SeasonBestEleven>[])
          .reversed
          .toList();

  /// 表示待ちのシーズン中盤理事会レビュー講評。ない場合はnull。
  String? get pendingBoardReviewMessage => _save?.pendingBoardReviewMessage;

  /// シーズン中盤理事会レビューの内容を確認済みにする。
  Future<void> dismissBoardReview() async {
    if (_save == null) return;
    _save!.pendingBoardReviewMessage = null;
    notifyListeners();
    await _persist();
  }

  /// 回答待ちの記者会見の質問。ない場合はnull。
  PressQuestion? get pendingPressConference => _save?.pendingPressConference;

  /// 記者会見の質問に回答する。信頼度・選手全体の士気に選んだ選択肢の効果を反映する。
  Future<void> answerPressConference(int optionIndex) async {
    if (_save == null) return;
    final question = _save!.pendingPressConference;
    if (question == null ||
        optionIndex < 0 ||
        optionIndex >= question.options.length) {
      return;
    }
    final option = question.options[optionIndex];
    _save!.confidence = (_save!.confidence + option.confidenceDelta).clamp(
      0,
      100,
    );
    for (final p in userTeam.players) {
      p.morale = (p.morale + option.moraleDelta).clamp(0, 100);
    }
    _save!.pendingPressConference = null;
    notifyListeners();
    await _persist();
  }

  /// 他クラブから監督就任オファーが届いている場合、そのクラブ。
  Team? get pendingJobOfferTeam {
    final teamId = _save?.pendingJobOfferTeamId;
    if (teamId == null) return null;
    return _save!.league.teams.firstWhere((t) => t.id == teamId);
  }

  Future<bool> acceptJobOffer() async {
    if (_save == null || _save!.pendingJobOfferTeamId == null) return false;
    final newTeamId = _save!.pendingJobOfferTeamId!;
    final newTeamName =
        _save!.league.teams.firstWhere((t) => t.id == newTeamId).name;
    _save!.userTeamId = newTeamId;
    _save!.pendingJobOfferTeamId = null;
    _save!.confidence = 60;
    _save!.boardTargetRank = BoardEngine.estimateTargetRank(
      _save!.league,
      newTeamId,
    );
    _save!.clubHistory.add(newTeamName);
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> declineJobOffer() async {
    if (_save == null) return;
    _save!.pendingJobOfferTeamId = null;
    notifyListeners();
    await _persist();
  }

  /// ライバルクラブ(開幕時に決定、以後固定)。未設定の場合はnull。
  Team? get rivalTeam {
    final id = _save?.rivalTeamId;
    if (id == null) return null;
    try {
      return _save!.league.teams.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 指定した対戦カードが自クラブ対ライバルクラブの「ダービー」かどうか。
  bool isRivalFixture(Fixture f) {
    final rivalId = _save?.rivalTeamId;
    if (rivalId == null) return false;
    final userId = _save!.userTeamId;
    return (f.homeTeamId == userId && f.awayTeamId == rivalId) ||
        (f.homeTeamId == rivalId && f.awayTeamId == userId);
  }

  /// ダービー戦は観客動員(収入)・監督への信頼度への影響がともに増幅される。
  static const double derbyAttendanceMultiplier = 1.5;
  static const double derbyConfidenceMultiplier = 1.5;

  /// 観客動員率(0.0-1.0)。監督への信頼度と現在の順位に連動する(強豪・高信頼ほど満員に近づく)。
  double get userAttendanceFactor {
    if (_save == null) return 0.0;
    final league = _save!.league;
    final standings = league.sortedStandings;
    final rank = standings.indexWhere((r) => r.teamId == _save!.userTeamId) + 1;
    final teamCount = league.teams.length;
    var factor =
        (0.7 + _save!.confidence / 250 + (teamCount - rank) / teamCount * 0.3)
            .clamp(0.6, 1.4);
    // 下位ディビジョンほど観客動員が少ない(ティアごとに段階的に低下する)。
    factor *= pow(0.8, _save!.currentDivisionTier - 1).toDouble();
    factor *= _save!.ticketPricing.attendanceMultiplier;
    return factor.clamp(0.0, 1.0);
  }

  /// 自クラブのスタジアム収容人数。
  int get stadiumCapacity => _save == null
      ? 0
      : ClubInfrastructure.stadiumCapacity(
          _save!.infrastructure.facilityLevel(FacilityType.stadium),
        );

  /// 通常開催時に見込まれる観客動員数(収容人数 x 動員率)。
  int get expectedAttendance =>
      (stadiumCapacity * userAttendanceFactor).round();

  /// 直近の試合の観客動員数(ダービーなら増幅される)。未実施の場合はnull。
  int? lastMatchAttendance;

  int weeklyIncomeFor(String teamId) {
    if (_save == null) return 0;
    final league = _save!.league;
    final standings = league.sortedStandings;
    final rank = standings.indexWhere((r) => r.teamId == teamId) + 1;
    final teamCount = league.teams.length;
    final rankBonus = ((teamCount - rank) * 20).clamp(0, 999);
    final base = 150 + rankBonus;
    if (teamId != _save!.userTeamId) return base;

    final stadiumLevel = _save!.infrastructure.facilityLevel(
      FacilityType.stadium,
    );
    final commercialMultiplier = ClubInfrastructure.commercialRevenueMultiplier(
      _save!.infrastructure.facilityLevel(FacilityType.commercialFacility),
    );
    var matchdayIncome = ((base + (stadiumLevel - 1) * 80) *
            userAttendanceFactor *
            _save!.ticketPricing.revenueMultiplier *
            commercialMultiplier)
        .round();
    // 2部リーグは1部より観客動員が少ない(userAttendanceFactorに反映済み)。
    final sponsorIncome =
        ((_save!.sponsorDeal?.weeklyIncome ?? 0) * commercialMultiplier)
            .round();
    // グッズ収入(マーチャンダイジング)。試合の有無に関わらず、監督の評価
    // (=クラブの知名度)が高いほど、商業施設が充実しているほど増える。
    // チケット・スポンサーだけに依存しない収入源として資金繰りを下支えする。
    final merchandiseIncome =
        ((40 + managerReputation) * commercialMultiplier).round();
    return matchdayIncome + sponsorIncome + merchandiseIncome;
  }

  int get weeklyWageBill => _save == null
      ? 0
      : ContractEngine.weeklyWageBill(userTeam) +
          _save!.infrastructure.totalStaffWeeklyWage;

  /// 銀行から借り入れている融資一覧。
  List<BankLoan> get bankLoans => _save?.bankLoans ?? [];

  /// 融資の残り返済総額(元本+利息のうち未払い分)。
  int get outstandingLoanDebt =>
      bankLoans.fold<int>(0, (s, l) => s + l.totalRemaining);

  /// 現在追加で借り入れ可能な上限額。スタジアムの規模と監督としての評価が高いほど拡大する。
  int get maxLoanAmount => _save == null
      ? 0
      : LoanEngine.maxBorrowable(
          stadiumLevel: _save!.infrastructure.facilityLevel(
            FacilityType.stadium,
          ),
          reputation: _save!.managerReputation,
          outstandingDebt: outstandingLoanDebt,
        );

  int _loanSeq = 0;

  /// 銀行融資を申し込む。頭金なしで即座に資金を得られる代わりに、指定した返済プランで
  /// 毎週の返済が発生する。
  Future<bool> takeLoan(int amount, LoanTerm term) async {
    if (_save == null || amount <= 0) return false;
    if (amount > maxLoanAmount) return false;
    final weekly = LoanEngine.weeklyRepaymentFor(amount, term);
    _save!.bankLoans.add(
      BankLoan(
        id: 'loan${_loanSeq++}',
        principal: amount,
        weeklyRepayment: weekly,
        termWeeks: term.weeks,
        weeksRemaining: term.weeks,
      ),
    );
    _save!.budget += amount;
    notifyListeners();
    await _persist();
    return true;
  }

  /// 預け入れ中の定期預金一覧。
  List<FixedDeposit> get fixedDeposits => _save?.fixedDeposits ?? [];

  /// 定期預金として運用中の資金の合計(元本ベース)。
  int get totalDepositedFunds =>
      fixedDeposits.fold<int>(0, (s, d) => s + d.principal);

  int _depositSeq = 0;

  /// 定期預金を組む。指定額をただちに資金から差し引いて預け入れ、満期まで
  /// 引き出せない代わりに満期時に利息込みでまとめて払い戻される。
  Future<bool> openFixedDeposit(int amount, DepositTerm term) async {
    if (_save == null || amount <= 0) return false;
    if (amount > _save!.budget) return false;
    _save!.budget -= amount;
    _save!.fixedDeposits.add(
      FixedDeposit(
        id: 'deposit${_depositSeq++}',
        principal: amount,
        maturityValue: InvestmentEngine.maturityValueFor(amount, term),
        termWeeks: term.weeks,
        weeksRemaining: term.weeks,
      ),
    );
    notifyListeners();
    await _persist();
    return true;
  }

  /// フィジオ・メディカルセンターのレベルに応じた負傷の発生率・療養期間の
  /// 軽減係数(1.0で軽減なし)。両方に投資するほど軽減幅が大きくなる。
  double get _userInjuryFactor =>
      ClubInfrastructure.injuryFactor(
        _save!.infrastructure.staffLevel(StaffRole.physio),
      ) *
      ClubInfrastructure.medicalCenterInjuryFactor(
        _save!.infrastructure.facilityLevel(FacilityType.medicalCenter),
      );

  double _injuryFactorFor(String teamId) =>
      teamId == _save!.userTeamId ? _userInjuryFactor : 1.0;

  /// ホームアドバンテージ係数。自クラブが主催する試合は実際の観客動員率
  /// (収容人数に対する割合)に応じて変動する(満員に近いほど大きい)。
  /// 他クラブの主催試合は観客動員を管理していないため既定値のまま。
  double _homeAdvantageFor(String homeTeamId) {
    if (_save == null || homeTeamId != _save!.userTeamId) return 1.06;
    final capacity = stadiumCapacity;
    final ratio =
        capacity <= 0 ? 0.0 : (expectedAttendance / capacity).clamp(0.0, 1.0);
    return 1.03 + 0.06 * ratio;
  }

  // ---- ハーフタイム対応の試合進行(自クラブの試合のみ) ----
  Fixture? _liveFixture;
  HalfResult? _liveFirstHalf;
  int _liveSubstitutionsUsed = 0;
  static const int maxSubstitutionsPerMatch = 3;

  /// 自クラブの試合が前半終了・ハーフタイム待ちの状態かどうか。
  bool get isHalfTime => _liveFixture != null && _liveFirstHalf != null;

  Fixture? get liveFixture => _liveFixture;
  HalfResult? get liveFirstHalf => _liveFirstHalf;

  int get substitutionsUsed => _liveSubstitutionsUsed;
  bool get canMakeSubstitution =>
      _liveSubstitutionsUsed < maxSubstitutionsPerMatch;

  /// ハーフタイムの交代操作。通常のswapStartingPlayerに交代枠の消費を加える。
  bool makeHalfTimeSubstitution({
    required String outPlayerId,
    required String inPlayerId,
  }) {
    if (!canMakeSubstitution) return false;
    swapStartingPlayer(outPlayerId: outPlayerId, inPlayerId: inPlayerId);
    _liveSubstitutionsUsed++;
    notifyListeners();
    return true;
  }

  /// 次の節を進行する。CPU同士の試合は即座に消化するが、自クラブの試合は
  /// 前半のみをシミュレートしてハーフタイム状態にする(交代・戦術変更後、
  /// [playSecondHalf]で後半を消化する)。前半の結果を返す。
  Future<HalfResult?> playNextMatchday() async {
    if (_save == null) return null;
    // 前半消化中(ハーフタイム)のまま二重に呼び出される(例: 画面を閉じて
    // 戻った際の再タップ)と、この節の他カード全試合の結果が新たな乱数で
    // 上書きされてしまうため、多重実行を防止する。simulateAheadMatchdays等
    // 既にisBusyな状態からの正当なネスト呼び出しはここでは弾かない
    // (isBusyは他の重い処理とも共有する汎用フラグのため)。
    if (_liveFixture != null) return null;
    final league = _save!.league;
    final next = league.nextUnplayedFixture;
    if (next == null) return null;

    // 既に外側の処理(simulateAheadMatchdays等)がisBusyにしている場合は、
    // ここで自分がfalseに戻してしまわないようにする。
    final wasAlreadyBusy = isBusy;
    if (!wasAlreadyBusy) {
      isBusy = true;
      notifyListeners();
    }

    _save!.trainingDoneThisWeek = false;

    // トレーニング自動化が有効な場合、この節の分をここで自動的に実施する。
    if (userTeam.autoTrainingEnabled) {
      await runWeeklyTraining();
    }

    // 週の経過による負傷回復と自然な疲労回復(休養日)。
    // 疲労回復は個別のトレーニング方針(休養特訓)とは別に、全チーム・
    // 全選手へ毎週一律で適用する。CPUクラブは練習メニューを設定できず、
    // これを怠ると試合の疲労蓄積だけが積み重なって疲労が上限に張り付き
    // 続けてしまうため。復帰直後は試合勘が鈍っているためマッチシャープ
    // ネスを大きく下げる。
    for (final t in league.teams) {
      for (final p in t.players) {
        if (p.injuryWeeks > 0) {
          p.injuryWeeks -= 1;
          if (p.injuryWeeks == 0) {
            p.matchSharpness = min(p.matchSharpness, 40);
            p.injuryType = null;
          }
        }
        p.fatigue = (p.fatigue - 14).clamp(0, 100);
      }
    }

    // ユーザークラブのみローン期間(週単位)を処理する（CPUクラブは対象外）。
    // 選手契約自体は年単位で結ばれ、シーズン開始時にまとめて消化する
    // (startNextSeason参照)。
    final loanEnded = ContractEngine.advanceLoanWeek(userTeam);
    for (final p in loanEnded) {
      _clearPlayerRoleReferences(userTeam, p.id);
    }
    lastContractExpirations = loanEnded.map((p) => p.name).toList();
    lastContractWarnings = [];
    // ローン満了により編成人数が最低人数を割り込んだ場合、フリーエージェントを
    // 緊急補強してスカッドが組めなくなる事態を防ぐ(安全網)。
    lastEmergencySignings = [];
    while (userTeam.players.length < minSquadSize) {
      final signing = FreeAgentEngine.generateVeteran();
      ContractEngine.renewContract(signing);
      userTeam.players.add(signing);
      lastEmergencySignings.add(signing.name);
    }

    // 選手の不満度を更新する。
    final preMatchRank = league.sortedStandings.indexWhere(
          (r) => r.teamId == _save!.userTeamId,
        ) +
        1;
    HappinessEngine.applyWeekly(
      userTeam,
      leagueRank: preMatchRank,
      boardTargetRank: _save!.boardTargetRank,
    );
    // 個別声かけ(モチベーショントーク)のクールダウンも週次で減らす。
    for (final p in userTeam.players) {
      if (p.talkCooldownWeeks > 0) p.talkCooldownWeeks -= 1;
    }
    if (userTeam.tacticalMeetingCooldownWeeks > 0) {
      userTeam.tacticalMeetingCooldownWeeks -= 1;
    }
    // CPUクラブにも同様に反映する(目標順位という概念がないため、自クラブの
    // 順位をそのまま目標として扱い、出場機会・待遇の要素のみ効かせる)。
    for (final t in league.teams) {
      if (t.id == _save!.userTeamId) continue;
      final rank =
          league.sortedStandings.indexWhere((r) => r.teamId == t.id) + 1;
      HappinessEngine.applyWeekly(t, leagueRank: rank, boardTargetRank: rank);
    }

    // シーズン折り返し地点で、理事会が一度だけ中間レビューを行う。
    if (!_save!.boardReviewDoneThisSeason) {
      final total = _totalMatchdaysThisSeason;
      final midMatchday = total ~/ 2;
      if (total > 0 && next.matchday == midMatchday) {
        final delta = BoardEngine.midSeasonReviewDelta(
          currentRank: preMatchRank,
          targetRank: _save!.boardTargetRank,
        );
        _save!.confidence = (_save!.confidence + delta).clamp(0, 100);
        _save!.pendingBoardReviewMessage = BoardEngine.midSeasonReviewMessage(
          currentRank: preMatchRank,
          targetRank: _save!.boardTargetRank,
        );
        _save!.boardReviewDoneThisSeason = true;
      }
    }

    // スポンサー契約(年単位)の消化はシーズン開始時にまとめて処理する
    // (startNextSeason参照)。分割払いの引き落としは引き続き週次で行う。
    if (_save!.sponsorDeal == null && _save!.pendingSponsorOffers.isEmpty) {
      _save!.pendingSponsorOffers = SponsorEngine.generateOffers(
        userTeam.overallRating,
      );
    }
    for (final inst in List<Installment>.from(_save!.pendingInstallments)) {
      _save!.budget -= inst.weeklyAmount;
      inst.weeksRemaining -= 1;
      if (inst.weeksRemaining <= 0) {
        _save!.pendingInstallments.remove(inst);
      }
    }

    // 融資の週次返済。
    for (final loan in List<BankLoan>.from(_save!.bankLoans)) {
      _save!.budget -= loan.weeklyRepayment;
      loan.weeksRemaining -= 1;
      if (loan.weeksRemaining <= 0) {
        _save!.bankLoans.remove(loan);
      }
    }

    // 定期預金の週次経過。満期を迎えたものは利息込みで払い戻す。
    lastMaturedDeposits = [];
    for (final deposit in List<FixedDeposit>.from(_save!.fixedDeposits)) {
      deposit.weeksRemaining -= 1;
      if (deposit.weeksRemaining <= 0) {
        _save!.budget += deposit.maturityValue;
        _save!.fixedDeposits.remove(deposit);
        lastMaturedDeposits.add(deposit);
      }
    }

    // 移籍オファーの週次処理(期限切れ削除・新規発生・リリース条項の自動成立)。
    lastReleaseClauseSales = _advanceIncomingOffers();

    // 代表召集の週次処理(期間終了・新規招集抽選。スタメン欠員は自動で埋める)。
    lastInternationalCallUps = _advanceInternationalDuty();

    // CPUクラブ同士の移籍市場の週次処理(ユーザーは関与しない)。
    lastAiTransferNews = AiTransferEngine.maybeGenerate(
      league.teams,
      _save!.userTeamId,
      _aiTransferRng,
    );

    // CPUクラブの簡易的な週次成長(ユーザーのように個別指導はできないが、
    // 何もしないとユーザーだけがドリル等で伸び続けリーグ全体が停滞するため)。
    // あわせてセットプレー担当も自動更新し、移籍で放出入りした穴を埋める。
    for (final t in league.teams) {
      if (t.id == _save!.userTeamId) continue;
      TrainingEngine.applyPassiveCpuGrowth(t);
      LineupUtils.autoAssignSetPieceRoles(t);
    }

    // 昇格候補(有望株)はユース施設で育成され続ける。施設レベルが高いほど
    // 伸びが早く、じっくり育ててから昇格させる判断に意味を持たせる。
    TrainingEngine.applyYouthAcademyGrowth(
      _save!.youthProspects,
      _save!.infrastructure.facilityLevel(FacilityType.youthFacility),
    );

    // ローン放出の週次処理(期間終了で自動的にチームへ復帰する)。
    lastLoanReturns = [];
    for (final p in userTeam.players.where((p) => p.isLoanedOut)) {
      p.loanedOutWeeksRemaining -= 1;
      if (p.loanedOutWeeksRemaining <= 0) {
        p.loanedOutToClubName = null;
        lastLoanReturns.add(p.name);
      }
    }

    final md = next.matchday;
    Fixture? userFixture;
    HalfResult? userFirstHalf;
    for (final f in league.fixturesForMatchday(md)) {
      if (f.result != null) continue;
      final home = _findTeam(league.teams, f.homeTeamId);
      final away = _findTeam(league.teams, f.awayTeamId);
      if (home == null || away == null) {
        // 何らかの理由でチームが見つからない不整合データ。この1試合だけ
        // 0-0扱いで確定させ、未消化のまま残ってnextUnplayedFixtureが
        // 恒久的にこの節で止まってしまう(=節送り自体が二度とできなくなる)
        // 事態を避ける。
        f.result = MatchResult(
          matchday: md,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: 0,
          awayGoals: 0,
          events: const [],
        );
        continue;
      }
      final weather = WeatherEngine.roll();
      f.weather = weather;
      final isUserFixture = f.homeTeamId == _save!.userTeamId ||
          f.awayTeamId == _save!.userTeamId;
      if (isUserFixture) {
        userFixture = f;
        userFirstHalf = MatchEngine.simulateMinutes(
          home: home,
          away: away,
          startMinute: 1,
          endMinute: 45,
          weather: weather,
          homeAdvantageFactor: _homeAdvantageFor(home.id),
        );
        MatchEngine.applyHalfTimeFatigue(
          home: home,
          away: away,
          weather: weather,
        );
      } else {
        f.result = MatchEngine.simulate(
          home: home,
          away: away,
          matchday: md,
          weather: weather,
          homeAdvantageFactor: _homeAdvantageFor(home.id),
        );
      }
    }

    // ユーザーが所属していない他の全ディビジョンも同じ節番号の試合を裏で
    // 消化しておく。こうすることで昇格・降格に意味のある順位表を常時
    // 閲覧できるようにする。
    for (final otherLeague in _save!.otherDivisionLeagues) {
      if (otherLeague == null) continue;
      for (final f in otherLeague.fixturesForMatchday(md)) {
        if (f.result != null) continue;
        final home = _findTeam(otherLeague.teams, f.homeTeamId);
        final away = _findTeam(otherLeague.teams, f.awayTeamId);
        if (home == null || away == null) continue;
        f.result = BackgroundMatchEngine.simulate(
          home: home,
          away: away,
          matchday: md,
        );
      }
    }

    var income = weeklyIncomeFor(_save!.userTeamId);
    final isDerby = userFixture != null && isRivalFixture(userFixture);
    if (isDerby) {
      income = (income * derbyAttendanceMultiplier).round();
    }
    var attendance = expectedAttendance;
    if (isDerby) attendance = (attendance * derbyAttendanceMultiplier).round();
    lastMatchAttendance = attendance.clamp(0, stadiumCapacity);
    _save!.budget += income;
    _save!.budget -= weeklyWageBill;

    // リーグ公式戦にスタメン出場した選手には出場手当を支払う(親善試合・カップ戦は対象外)。
    if (userFixture != null) {
      lastAppearanceFeesPaid = userTeam.players
          .where((p) => userTeam.startingXI.contains(p.id))
          .fold<int>(0, (s, p) => s + p.appearanceFee);
      _save!.budget -= lastAppearanceFeesPaid;
    } else {
      lastAppearanceFeesPaid = 0;
    }

    if (_save!.budget < 0) {
      _save!.consecutiveNegativeBudgetWeeks += 1;
    } else {
      _save!.consecutiveNegativeBudgetWeeks = 0;
    }
    final budgetConfidenceDelta = BoardEngine.negativeBudgetConfidenceDelta(
      _save!.consecutiveNegativeBudgetWeeks,
    );
    if (budgetConfidenceDelta != 0) {
      _save!.confidence = (_save!.confidence + budgetConfidenceDelta).clamp(
        0,
        100,
      );
      lastBudgetCrisisWarning =
          '資金マイナスが${_save!.consecutiveNegativeBudgetWeeks}週続いています。理事会の信頼度が低下しました。';
    }

    transferMarket = TransferMarket.generate();
    _refreshScoutCandidates();

    if (userFixture != null && userFirstHalf != null) {
      _liveFixture = userFixture;
      _liveFirstHalf = userFirstHalf;
      _liveSubstitutionsUsed = 0;
    }

    if (!wasAlreadyBusy) {
      isBusy = false;
    }
    notifyListeners();
    await _persist();
    return userFirstHalf;
  }

  /// ハーフタイムでの交代・戦術変更を反映して後半を消化し、試合を確定する。
  Future<MatchResult?> playSecondHalf() async {
    if (_save == null || _liveFixture == null || _liveFirstHalf == null) {
      return null;
    }
    final league = _save!.league;
    final f = _liveFixture!;
    final home = league.teams.firstWhere((t) => t.id == f.homeTeamId);
    final away = league.teams.firstWhere((t) => t.id == f.awayTeamId);

    final weather = f.weather ?? Weather.clear;
    final second = MatchEngine.simulateMinutes(
      home: home,
      away: away,
      startMinute: 46,
      endMinute: 90,
      weather: weather,
      homeAdvantageFactor: _homeAdvantageFor(home.id),
    );
    final allEvents = [..._liveFirstHalf!.events, ...second.events];
    final homeGoals = _liveFirstHalf!.homeGoals + second.homeGoals;
    final awayGoals = _liveFirstHalf!.awayGoals + second.awayGoals;
    final homeShots = _liveFirstHalf!.homeShots + second.homeShots;
    final awayShots = _liveFirstHalf!.awayShots + second.awayShots;
    final homeShotsOnTarget =
        _liveFirstHalf!.homeShotsOnTarget + second.homeShotsOnTarget;
    final awayShotsOnTarget =
        _liveFirstHalf!.awayShotsOnTarget + second.awayShotsOnTarget;
    final totalChanceCount = _liveFirstHalf!.chanceCount + second.chanceCount;
    final homePossession = totalChanceCount > 0
        ? ((_liveFirstHalf!.possessionShareSum + second.possessionShareSum) /
                totalChanceCount *
                100)
            .round()
            .clamp(0, 100)
        : 50;
    final awayPossession = 100 - homePossession;
    // 採点は今節の出場停止・負傷が反映される前に算出する必要があるため、
    // applyPostMatchEffectsより先に計算する。
    final ratings = MatchEngine.computePlayerRatings(
      home: home,
      away: away,
      events: allEvents,
      homeGoals: homeGoals,
      awayGoals: awayGoals,
    );
    final statsBefore = {
      for (final p in userTeam.players)
        p.id: (goals: p.careerGoals, apps: p.careerAppearances),
    };
    MatchEngine.applyPostMatchEffects(
      home: home,
      away: away,
      homeInjuryFactor: _injuryFactorFor(home.id),
      awayInjuryFactor: _injuryFactorFor(away.id),
      events: allEvents,
      weather: weather,
    );
    lastMilestones = _detectMilestones(userTeam, allEvents, statsBefore);
    for (final m in lastMilestones) {
      _save!.trophyHistory.add('シーズン${league.season}: $m');
    }
    _evaluateAchievements();

    final merged = MatchResult(
      matchday: f.matchday,
      homeTeamId: f.homeTeamId,
      awayTeamId: f.awayTeamId,
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      events: allEvents,
      playerRatings: ratings,
      weather: weather,
      homePossession: homePossession,
      awayPossession: awayPossession,
      homeShots: homeShots,
      awayShots: awayShots,
      homeShotsOnTarget: homeShotsOnTarget,
      awayShotsOnTarget: awayShotsOnTarget,
    );
    f.result = merged;

    // 4節ごとに月間最優秀監督賞を判定する(ユーザーが受賞した場合のみ通知・記録する)。
    if (f.matchday - _save!.lastManagerOfMonthCheckpoint >= 4) {
      final fromMatchday = _save!.lastManagerOfMonthCheckpoint + 1;
      final winnerName = AwardsEngine.computeManagerOfPeriod(
        league,
        fromMatchday: fromMatchday,
        toMatchday: f.matchday,
      );
      if (winnerName == userTeam.name) {
        final label = '第$fromMatchday-${f.matchday}節';
        _save!.trophyHistory.add('シーズン${league.season} 月間最優秀監督賞($label)');
        lastMonthlyManagerAward = label;
      }
      _save!.lastManagerOfMonthCheckpoint = f.matchday;
    }

    var delta = BoardEngine.confidenceDeltaForMatch(merged, _save!.userTeamId);
    if (isRivalFixture(f)) {
      delta = (delta * derbyConfidenceMultiplier).round();
    }
    _save!.confidence = (_save!.confidence + delta).clamp(0, 100);
    _save!.pendingPressConference = PressConferenceEngine.generateFor(
      result: merged,
      userTeamId: _save!.userTeamId,
    );

    _liveFixture = null;
    _liveFirstHalf = null;
    _liveSubstitutionsUsed = 0;

    notifyListeners();
    await _persist();
    return merged;
  }

  static const List<int> _goalMilestones = [50, 100, 150, 200, 250, 300];
  static const List<int> _appearanceMilestones = [100, 200, 300, 400, 500];

  /// 今節の試合で自クラブの選手が達成したハットトリック・通算記録の
  /// 節目を検出し、表示・記録用の説明文リストとして返す。
  List<String> _detectMilestones(
    Team team,
    List<MatchEvent> events,
    Map<String, ({int goals, int apps})> before,
  ) {
    final milestones = <String>[];
    final goalsThisMatch = <String, int>{};
    for (final e in events) {
      if (e.type == MatchEventType.goal && e.scorerId != null) {
        goalsThisMatch[e.scorerId!] = (goalsThisMatch[e.scorerId!] ?? 0) + 1;
      }
    }
    for (final p in team.players) {
      final scored = goalsThisMatch[p.id] ?? 0;
      if (scored >= 3) {
        milestones.add('${p.name}がハットトリック達成($scored得点)');
      }
      final prev = before[p.id];
      if (prev == null) continue;
      for (final m in _goalMilestones) {
        if (prev.goals < m && p.careerGoals >= m) {
          milestones.add('${p.name}が通算$m得点を達成');
        }
      }
      for (final m in _appearanceMilestones) {
        if (prev.apps < m && p.careerAppearances >= m) {
          milestones.add('${p.name}が通算$m試合出場を達成');
        }
      }
    }
    return milestones;
  }

  /// 現在のセーブデータの状態から新たに解除された実績を判定し、
  /// 解除済みIDとして記録する(通知はlastUnlockedAchievementsへ追加し、
  /// 呼び出し側が表示後にクリアする想定)。
  void _evaluateAchievements({int? season}) {
    if (_save == null) return;
    final newly = AchievementEngine.evaluate(_save!, userTeam);
    if (newly.isEmpty) return;
    final recordedSeason = season ?? _save!.league.season;
    for (final a in newly) {
      _save!.unlockedAchievements[a.id] = recordedSeason;
    }
    lastUnlockedAchievements = [...lastUnlockedAchievements, ...newly];
  }

  /// 実績画面向け: 全実績の定義一覧。
  List<Achievement> get allAchievements => AchievementEngine.all;

  bool isAchievementUnlocked(String id) =>
      _save?.unlockedAchievements.containsKey(id) ?? false;

  /// 実績を達成したシーズン番号(未達成の場合はnull)。
  int? achievementUnlockedSeason(String id) => _save?.unlockedAchievements[id];

  int get unlockedAchievementCount => _save?.unlockedAchievements.length ?? 0;

  /// ライブ観戦せず、前半・後半を一括で消化して確定結果のみを返す
  /// (クイックシム)。ユーザーの試合がない、またはシーズンが既に終了して
  /// いる場合はnull。
  Future<MatchResult?> playNextMatchdayQuickSim() async {
    final firstHalf = await playNextMatchday();
    if (firstHalf == null) return null;
    return playSecondHalf();
  }

  /// クイックシムを最大[matchdays]節分繰り返し、確定した結果を節の順で返す。
  /// シーズンが終了する、またはユーザーの試合がない節に達した時点で止まる。
  Future<List<MatchResult>> simulateAheadMatchdays(int matchdays) async {
    isBusy = true;
    notifyListeners();
    final results = <MatchResult>[];
    try {
      for (int i = 0; i < matchdays; i++) {
        if (_save == null || _save!.league.isSeasonComplete) break;
        final result = await playNextMatchdayQuickSim();
        if (result == null) break;
        results.add(result);
      }
    } finally {
      isBusy = false;
      notifyListeners();
    }
    return results;
  }

  /// 現在の順位表を起点に、残り試合をチーム総合力ベースで簡易シミュレー
  /// ションし、シーズン最終順位の見込み(優勝/大陸カップ出場/降格の確率)
  /// を算出する。実際の試合結果には影響しない参考情報。
  List<TeamProjection> get seasonProjection => SeasonProjectionEngine.project(
        _save!.league,
        relegationCount: PromotionEngine.swapCount,
        // 大陸カップ出場枠は1部の上位2チームのみ(2部は対象外)。
        continentalQualifyCount: _save!.currentDivisionTier == 1 ? 2 : 0,
      );

  List<Team> get allTeamsForCups => [
        ..._save!.league.teams,
        ..._save!.continentalTeams,
      ];

  Cup? _cupOfType(CupType type) {
    for (final c in _save!.cups) {
      if (c.type == type) return c;
    }
    return null;
  }

  /// 現在の実際の暦日(次に消化する節の日付。シーズンが完了している場合は
  /// 最終節の翌週)。カレンダー画面・ホーム画面の日付表示に使う。
  DateTime get currentDate {
    final league = _save!.league;
    final next = league.nextUnplayedFixture;
    if (next != null) {
      return CalendarEngine.dateForMatchday(league.season, next.matchday);
    }
    final maxMatchday = league.fixtures.fold<int>(
      0,
      (m, f) => f.matchday > m ? f.matchday : m,
    );
    return CalendarEngine.dateForMatchday(league.season, maxMatchday + 1);
  }

  Cup? get domesticCup => _save == null ? null : _cupOfType(CupType.domestic);

  /// 大陸カップ(グループステージ+決勝トーナメント)。出場資格がない間はnull。
  ContinentalCup? get continentalCup => _save?.continentalCup;

  /// 前シーズンの最終順位に基づき、来季の大陸カップ出場資格があるか。
  bool get qualifiedForContinentalCup => (_save?.lastSeasonRank ?? 99) <= 2;

  /// 国内カップ戦で、ブラケット全体の中で次に消化されるべき試合が自クラブの
  /// 試合であるかどうか。日程画面・ホーム画面から「カップ戦の順番が来ている」
  /// ことに気づけるようにするためのフラグ。
  bool get isUserDomesticCupMatchUpNext {
    final match = domesticCup?.nextUnplayedMatch;
    if (match == null || _save == null) return false;
    final userId = _save!.userTeamId;
    return match.homeTeamId == userId || match.awayTeamId == userId;
  }

  /// リーグの現在の節番号(シーズン終了後は最終節+1)。カップ戦の消化間隔
  /// (現実の試合間隔の再現)を判定する基準として使う。
  int get _currentLeagueMatchdayMarker {
    final nextMd = _save!.league.nextUnplayedFixture?.matchday;
    return nextMd ?? (_totalMatchdaysThisSeason + 1);
  }

  bool _canAdvanceCup(int? lastPlayedAtMatchday) {
    if (_save == null) return false;
    // リーグ戦が全節消化済み(オフシーズン)の間は、もう間隔を置く相手がいない
    // ため無制限に消化できる。そうしないと、リーグ完了後に残ったカップ戦は
    // 節数が二度と進まず永久に足止めされてしまう。
    if (_save!.league.nextUnplayedFixture == null) return true;
    return lastPlayedAtMatchday == null ||
        _currentLeagueMatchdayMarker > lastPlayedAtMatchday;
  }

  /// 国内カップ戦の次の試合を消化できるか。直前の消化からリーグが1節も
  /// 進んでいない場合は、現実の試合間隔を再現するためfalseになる。
  bool get canPlayNextDomesticCupMatch =>
      domesticCup?.nextUnplayedMatch != null &&
      _canAdvanceCup(domesticCup!.lastPlayedAtMatchday);

  Future<MatchResult?> playNextCupMatch() async {
    if (_save == null) return null;
    final cup = domesticCup;
    if (cup == null || cup.nextUnplayedMatch == null) return null;
    if (!_canAdvanceCup(cup.lastPlayedAtMatchday)) return null;
    final userId = _save!.userTeamId;

    final result = CupEngine.playNextMatch(cup, allTeamsForCups);
    cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
    if (result != null &&
        (result.homeTeamId == userId || result.awayTeamId == userId)) {
      if (cup.isEliminated(userId)) {
        _save!.confidence = (_save!.confidence - 1).clamp(0, 100);
      }
    }
    if (cup.isComplete && cup.championId == userId && !cup.rewardClaimed) {
      cup.rewardClaimed = true;
      _save!.budget += 700;
      _save!.confidence = (_save!.confidence + 10).clamp(0, 100);
      _save!.trophyHistory.add('シーズン${_save!.league.season}: ${cup.name} 優勝');
    }
    notifyListeners();
    await _persist();
    return result;
  }

  /// 大陸カップに次に消化すべき試合(グループステージ、または決勝
  /// トーナメント)が残っているか。
  bool _continentalHasNextMatch(ContinentalCup cup) {
    if (!cup.isGroupStageComplete) {
      return ContinentalCupEngine.nextGroupMatch(cup) != null;
    }
    return cup.knockoutRounds.isNotEmpty &&
        cup.knockoutRounds.last.any((t) => !t.isComplete);
  }

  /// 大陸カップの次の試合を消化できるか。直前の消化からリーグが1節も
  /// 進んでいない場合は、現実の試合間隔を再現するためfalseになる。
  bool get canPlayNextContinentalMatch {
    final cup = _save?.continentalCup;
    if (cup == null || !_continentalHasNextMatch(cup)) return false;
    return _canAdvanceCup(cup.lastPlayedAtMatchday);
  }

  /// 大陸カップのグループステージ次の1試合を消化する。全組が終わると
  /// 自動的に決勝トーナメントの組み合わせが決定される。
  Future<MatchResult?> playNextContinentalGroupMatch() async {
    if (_save == null || _save!.continentalCup == null) return null;
    final cup = _save!.continentalCup!;
    if (!_continentalHasNextMatch(cup)) return null;
    if (!_canAdvanceCup(cup.lastPlayedAtMatchday)) return null;
    final userId = _save!.userTeamId;
    final result = ContinentalCupEngine.playNextGroupMatch(
      cup,
      allTeamsForCups,
    );
    cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
    if (result != null &&
        (result.homeTeamId == userId || result.awayTeamId == userId) &&
        cup.isEliminated(userId)) {
      _save!.confidence = (_save!.confidence - 3).clamp(0, 100);
    }
    notifyListeners();
    await _persist();
    return result;
  }

  /// 大陸カップの決勝トーナメント次の1レグを消化する。
  Future<MatchResult?> playNextContinentalKnockoutLeg() async {
    if (_save == null || _save!.continentalCup == null) return null;
    final cup = _save!.continentalCup!;
    if (!_continentalHasNextMatch(cup)) return null;
    if (!_canAdvanceCup(cup.lastPlayedAtMatchday)) return null;
    final userId = _save!.userTeamId;
    final result = ContinentalCupEngine.playNextKnockoutLeg(
      cup,
      allTeamsForCups,
    );
    cup.lastPlayedAtMatchday = _currentLeagueMatchdayMarker;
    if (result != null &&
        (result.homeTeamId == userId || result.awayTeamId == userId) &&
        cup.isEliminated(userId)) {
      _save!.confidence = (_save!.confidence - 3).clamp(0, 100);
    }
    if (cup.isComplete && cup.championId == userId && !cup.rewardClaimed) {
      cup.rewardClaimed = true;
      _save!.budget += 1500;
      _save!.confidence = (_save!.confidence + 20).clamp(0, 100);
      _save!.trophyHistory.add('シーズン${_save!.league.season}: ${cup.name} 優勝');
    }
    notifyListeners();
    await _persist();
    return result;
  }

  /// 新シーズン開幕前のスーパーカップ(ユーザークラブが出場する場合のみ保留される)。
  CupMatch? get pendingSuperCup => _save?.pendingSuperCup;

  /// 直近のstartNextSeasonでユーザーが出場しないスーパーカップが自動消化された
  /// 場合のニュース文言。ない場合はnull(表示後は呼び出し側でクリアする想定)。
  String? lastSuperCupNews;

  /// 保留中のスーパーカップを消化する。ユーザークラブが出場する場合のみ有効。
  Future<MatchResult?> playSuperCup() async {
    if (_save == null || _save!.pendingSuperCup == null) return null;
    final match = _save!.pendingSuperCup!;
    final teams = _save!.allTeams;
    final home = teams.firstWhere((t) => t.id == match.homeTeamId);
    final away = teams.firstWhere((t) => t.id == match.awayTeamId);
    final result = MatchEngine.simulate(
      home: home,
      away: away,
      matchday: 0,
      weather: WeatherEngine.roll(),
    );
    match.result = result;
    if (result.homeGoals == result.awayGoals) {
      match.penaltyWinnerId = CupEngine.decidePenaltyWinner(home, away);
    }
    if (match.winnerId == _save!.userTeamId) {
      _save!.trophyHistory.add('シーズン${_save!.league.season} スーパーカップ優勝');
    }
    _save!.pendingSuperCup = null;
    notifyListeners();
    await _persist();
    return result;
  }

  /// 大陸カップに参加する海外クラブ名を生成する。5つの国風テーマから
  /// バランスよく取り混ぜることで、実際の大陸カップのように様々な国風の
  /// クラブが顔をそろえるようにする(自国リーグと同じ命名規則を流用しつつ、
  /// テーマを散らして「他国のクラブ」らしさを出す)。
  List<Team> _generateContinentalTeams() {
    final rng = Random();
    const totalTeams = 7;
    final themes = List<LeagueTheme>.from(LeagueTheme.values)..shuffle(rng);
    final names = <String>[];
    var remaining = totalTeams;
    for (int i = 0; i < themes.length && remaining > 0; i++) {
      final take = (remaining / (themes.length - i)).ceil();
      names.addAll(NamePool.themedClubNames(themes[i], take));
      remaining -= take;
    }
    final teams = <Team>[];
    for (int i = 0; i < totalTeams; i++) {
      final t = PlayerGenerator.generateSquad(
        id: 'continental$i',
        name: names[i],
        strengthTier: 65 + rng.nextInt(20),
      );
      LineupUtils.autoFill(t);
      teams.add(t);
    }
    return teams;
  }

  /// 直近のstartNextSeasonでの昇格・降格結果メッセージ(なければnull)。
  String? lastDivisionChangeMessage;

  /// 直近のstartNextSeasonで昇格プレーオフが行われた場合の各試合結果
  /// (準決勝2試合+決勝の順、表示用に整形済み)。行われなかった場合は空。
  List<String> lastPromotionPlayoffResults = [];

  /// 直近のプレーオフにユーザークラブが出場していたかどうか。
  bool userInvolvedInLastPromotionPlayoff = false;

  Future<void> startNextSeason() async {
    if (_save == null) return;
    isBusy = true;
    notifyListeners();
    // ローディング表示を1フレーム描画させてから、裏ディビジョンの1シーズン分の
    // シミュレーションなど重い処理に入る。
    await Future<void>.delayed(Duration.zero);
    final league = _save!.league;
    final standings = league.sortedStandings;
    final finalRank =
        standings.indexWhere((r) => r.teamId == _save!.userTeamId) + 1;
    final playedOrder = standings
        .map((r) => league.teams.firstWhere((t) => t.id == r.teamId))
        .toList();
    final playedTier = _save!.currentDivisionTier;

    // シーズン開始時点の総合力からの成長を選手ごとに算出し、シーズン終了時に
    // 一覧表示できるようにする。
    final previousOverallSnapshot = _save!.seasonStartOverallByPlayerId;
    lastSeasonGrowthSummary = [
      for (final p in userTeam.players)
        if (previousOverallSnapshot.containsKey(p.id))
          PlayerGrowthSummary(
            playerId: p.id,
            playerName: p.name,
            overallBefore: previousOverallSnapshot[p.id]!,
            overallAfter: p.overall,
            attributeDeltas: const {},
          ),
    ];

    _save!.seasonAwards.add(AwardsEngine.computeAwards(league, league.season));
    _save!.bestElevenHistory.add(
      BestElevenEngine.compute(league, league.season),
    );

    // 監督としての通算成績を更新する。
    final userRow = standings.firstWhere((r) => r.teamId == _save!.userTeamId);
    _save!.careerWins += userRow.won;
    _save!.careerDraws += userRow.draw;
    _save!.careerLosses += userRow.lost;
    _save!.careerSeasons += 1;
    if (finalRank == 1) {
      final divisionLabel = playedTier == 1
          ? _save!.leagueName
          : '${_save!.leagueName}($playedTier部)';
      _save!.trophyHistory.add('シーズン${league.season}: $divisionLabel 優勝');
    }

    // 年間最優秀監督賞: 総合力から見た期待順位を最も上回ったクラブに贈られる。
    lastSeasonManagerAwardWon = false;
    if (AwardsEngine.computeManagerOfSeason(league) == userTeam.name) {
      _save!.trophyHistory.add('シーズン${league.season} 年間最優秀監督賞');
      lastSeasonManagerAwardWon = true;
    }

    // 下位ディビジョンほど観客動員・賞金が少ない(ティアごとに段階的に低下する)。
    var prizeMoney = BoardEngine.seasonPrizeMoney(
      finalRank: finalRank,
      teamCount: league.teams.length,
    );
    prizeMoney = (prizeMoney * pow(0.6, playedTier - 1)).round();
    _save!.budget += prizeMoney;
    final confidenceDelta = BoardEngine.confidenceDeltaForSeasonEnd(
      finalRank: finalRank,
      targetRank: _save!.boardTargetRank,
    );
    _save!.confidence = (_save!.confidence + confidenceDelta).clamp(0, 100);

    for (final t in _save!.allTeams) {
      for (final p in t.players) {
        p.age += 1;
      }
      // CPUクラブは自クラブ(userTeam、下でRetirementEngine.resolveRetirements
      // を個別に呼ぶ)と違って移籍市場で世代交代しないため、ここで代わりに
      // 引退+若手補充を行う。行わないと選手が永遠に加齢し続けてしまう。
      if (t.id != _save!.userTeamId) {
        RetirementEngine.resolveAndReplaceForCpu(t);
      }
    }
    final infra = _save!.infrastructure;
    // ユースインテーク: 複数候補を一括生成し、選抜はユーザーに委ねる。
    final intakeCount = 3 + Random().nextInt(3);
    _save!.pendingYouthIntake = List.generate(
      intakeCount,
      (_) => ScoutingEngine.generateAcademyGraduate(
        youthCoachLevel: infra.staffLevel(StaffRole.youthCoach),
      ),
    );

    // 監督としての世間の評価を更新する(目標達成なら上昇、大きく未達なら下降)。
    if (finalRank <= _save!.boardTargetRank) {
      _save!.managerReputation = (_save!.managerReputation + 8).clamp(0, 100);
    } else if (finalRank > _save!.boardTargetRank + 2) {
      _save!.managerReputation = (_save!.managerReputation - 5).clamp(0, 100);
    }
    // 評価が高く好成績を残すと、他クラブから監督就任オファーが届くことがある(1部のみ)。
    if (playedTier == 1 &&
        _save!.pendingJobOfferTeamId == null &&
        _save!.managerReputation >= 55 &&
        finalRank <= (league.teams.length / 2).ceil()) {
      final candidates = league.teams
          .where(
            (t) =>
                t.id != _save!.userTeamId &&
                t.overallRating > userTeam.overallRating,
          )
          .toList()
        ..sort((a, b) => b.overallRating.compareTo(a.overallRating));
      if (candidates.isNotEmpty && Random().nextDouble() < 0.25) {
        _save!.pendingJobOfferTeamId = candidates.first.id;
      }
    }

    // 昇格・降格を解決する。ユーザーの現在ティア以外は節ごとに並行して
    // 消化してきたため、その最終順位順をそのまま使う(改めてシミュレート
    // し直さない)。各境界(1部/2部、2部/3部、…)は隣接ティアの実際の最終
    // 順位のみを根拠に独立して解決する。前の境界の解決結果を次の境界に
    // 連鎖させると、降格してきたばかりのチームがその配列内の並び順の都合で
    // さらに1段降格してしまう(1シーズンで複数ティア移動する)バグになるため、
    // 各ティアの「移動元(outgoing)」「移動先(incoming)」だけを集計し、
    // 最後にまとめて新編成を組み立てる。
    List<Team> orderedTeamsForTier(int tier) {
      if (tier == playedTier) return playedOrder;
      final other = _save!.otherDivisionLeagues[tier - 1]!;
      final otherStandings = other.sortedStandings;
      return otherStandings
          .map((r) => other.teams.firstWhere((t) => t.id == r.teamId))
          .toList();
    }

    final tierOrder = <int, List<Team>>{
      for (int tier = 1; tier <= totalDivisionTiers; tier++)
        tier: orderedTeamsForTier(tier),
    };
    final outgoingIds = <int, Set<String>>{
      for (int tier = 1; tier <= totalDivisionTiers; tier++) tier: <String>{},
    };
    final incomingTeams = <int, List<Team>>{
      for (int tier = 1; tier <= totalDivisionTiers; tier++) tier: <Team>[],
    };
    var relevantPlayoffMatches = const <PromotionPlayoffMatch>[];
    for (int upperTier = 1; upperTier < totalDivisionTiers; upperTier++) {
      final lowerTier = upperTier + 1;
      final upperOrder = tierOrder[upperTier]!;
      final lowerOrder = tierOrder[lowerTier]!;
      final result = PromotionEngine.resolve(
        tier1Teams: upperOrder,
        tier2Teams: lowerOrder,
        tier1PlayedOrder: upperOrder,
        tier2PlayedOrder: lowerOrder,
      );
      final upperIds = upperOrder.map((t) => t.id).toSet();
      final lowerIds = lowerOrder.map((t) => t.id).toSet();
      final promoted =
          result.tier1.where((t) => !upperIds.contains(t.id)).toList();
      final relegated =
          result.tier2.where((t) => !lowerIds.contains(t.id)).toList();

      outgoingIds[upperTier]!.addAll(relegated.map((t) => t.id));
      outgoingIds[lowerTier]!.addAll(promoted.map((t) => t.id));
      incomingTeams[upperTier]!.addAll(promoted);
      incomingTeams[lowerTier]!.addAll(relegated);

      if (lowerTier == playedTier) {
        relevantPlayoffMatches = result.promotionPlayoff;
      }
    }

    final newTeamsByTier = <int, List<Team>>{
      for (int tier = 1; tier <= totalDivisionTiers; tier++)
        tier: [
          ...tierOrder[tier]!.where((t) => !outgoingIds[tier]!.contains(t.id)),
          ...incomingTeams[tier]!,
        ],
    };

    var newTier = playedTier;
    for (final entry in newTeamsByTier.entries) {
      if (entry.value.any((t) => t.id == _save!.userTeamId)) {
        newTier = entry.key;
        break;
      }
    }
    final newActiveTeams = newTeamsByTier[newTier]!;

    final userInPromotionPlayoff = relevantPlayoffMatches.any(
      (m) => m.homeId == _save!.userTeamId || m.awayId == _save!.userTeamId,
    );
    lastPromotionPlayoffResults = relevantPlayoffMatches
        .map(
          (m) => '${m.roundLabel}: ${m.homeName} ${m.homeGoals}-'
              '${m.awayGoals} ${m.awayName}'
              '${m.decidedByPenalties ? '(PK: ${m.winnerName}が勝利)' : ''}',
        )
        .toList();
    userInvolvedInLastPromotionPlayoff = userInPromotionPlayoff;
    if (newTier > playedTier) {
      lastDivisionChangeMessage = '降格が決まりました。来シーズンは$newTier部リーグでの再出発です。';
    } else if (newTier < playedTier) {
      lastDivisionChangeMessage = userInPromotionPlayoff
          ? '昇格プレーオフを勝ち抜き、来シーズンは$newTier部リーグに昇格します！'
          : '昇格達成！来シーズンは$newTier部リーグに昇格します。';
    } else if (userInPromotionPlayoff) {
      lastDivisionChangeMessage = '昇格プレーオフで敗れ、来シーズンも$playedTier部リーグで戦います。';
    } else {
      lastDivisionChangeMessage = null;
    }
    _save!.currentDivisionTier = newTier;
    for (int tier = 1; tier <= totalDivisionTiers; tier++) {
      if (tier == newTier) {
        _save!.otherDivisionLeagues[tier - 1] = null;
        continue;
      }
      final tierTeams = newTeamsByTier[tier]!;
      _save!.otherDivisionLeagues[tier - 1] = League(
        teams: tierTeams,
        fixtures: FixtureGenerator.generateDoubleRoundRobin(tierTeams),
        season: league.season + 1,
      );
    }

    final newFixtures = FixtureGenerator.generateDoubleRoundRobin(
      newActiveTeams,
    );
    _save!.league = League(
      teams: newActiveTeams,
      fixtures: newFixtures,
      season: league.season + 1,
    );
    _save!.boardTargetRank = BoardEngine.estimateTargetRank(
      _save!.league,
      _save!.userTeamId,
    );
    transferMarket = TransferMarket.generate();
    _refreshScoutCandidates();
    FreeAgentEngine.topUp(_save!.freeAgents);

    // スポンサー契約(年単位)はシーズン境界で1年分消化する。
    if (_save!.sponsorDeal != null) {
      _save!.sponsorDeal!.yearsRemaining -= 1;
      if (_save!.sponsorDeal!.yearsRemaining <= 0) {
        _save!.sponsorDeal = null;
      }
    }
    if (_save!.sponsorDeal == null && _save!.pendingSponsorOffers.isEmpty) {
      _save!.pendingSponsorOffers = SponsorEngine.generateOffers(
        userTeam.overallRating,
      );
    }

    // 高齢選手の引退判定(ユースプロスペクトは対象外)。
    final retirees = RetirementEngine.resolveRetirements(userTeam);
    for (final p in retirees) {
      _clearPlayerRoleReferences(userTeam, p.id);
    }
    _save!.retiredLegends.addAll(retirees);
    lastRetirements = retirees.map((p) => p.name).toList();

    // 選手契約(年単位)をシーズン境界で1年分消化する(CPUクラブの契約は
    // 管理対象外)。切れた契約はフリーエージェントプールへ移す。引退判定より
    // 後に行うことで、緊急補強の安全網が最終的なスカッド人数を保証できる
    // ようにする。
    final contractResult = ContractEngine.advanceSeason(userTeam);
    lastContractExpirations =
        contractResult.expired.map((p) => p.name).toList();
    lastContractWarnings =
        contractResult.nearingExpiry.map((p) => p.name).toList();
    for (final p in contractResult.expired) {
      _clearPlayerRoleReferences(userTeam, p.id);
      if (_save!.freeAgents.length < FreeAgentEngine.maxPoolSize) {
        _save!.freeAgents.add(p);
      }
    }
    // 契約満了・引退により編成人数が最低人数を割り込んだ場合の緊急補強(安全網)。
    lastEmergencySignings = [];
    while (userTeam.players.length < minSquadSize) {
      final signing = FreeAgentEngine.generateVeteran();
      ContractEngine.renewContract(signing);
      userTeam.players.add(signing);
      lastEmergencySignings.add(signing.name);
    }

    _save!.lastSeasonRank = finalRank;

    final cupsWonThisSeason = [
      ..._save!.cups
          .where((c) => c.championId == _save!.userTeamId)
          .map((c) => c.name),
      if (_save!.continentalCup?.championId == _save!.userTeamId)
        _save!.continentalCup!.name,
    ];
    _save!.seasonHistory.add(
      SeasonRecord(
        season: league.season,
        clubName: _save!.clubName,
        leagueName: _save!.leagueName,
        divisionTier: playedTier,
        finalRank: finalRank,
        teamCount: league.teams.length,
        played: userRow.played,
        won: userRow.won,
        draw: userRow.draw,
        lost: userRow.lost,
        goalsFor: userRow.goalsFor,
        goalsAgainst: userRow.goalsAgainst,
        wonLeague: finalRank == 1,
        promoted: newTier < playedTier,
        relegated: newTier > playedTier,
        cupsWon: cupsWonThisSeason,
      ),
    );
    _evaluateAchievements(season: league.season);

    // スーパーカップ: 前シーズンのリーグ王者と国内カップ王者(同一クラブが両方
    // 制した場合はカップ準優勝クラブ)が新シーズン開幕前に対戦する。カップが
    // 未消化のままシーズンが終わった場合は開催しない。
    lastSuperCupNews = null;
    Cup? previousDomesticCup;
    for (final c in _save!.cups) {
      if (c.type == CupType.domestic) {
        previousDomesticCup = c;
        break;
      }
    }
    if (previousDomesticCup != null) {
      final pairing = SuperCupEngine.pairing(
        leagueChampionId: standings.first.teamId,
        domesticCup: previousDomesticCup,
      );
      final teamsThisSeason = newTeamsByTier.values.expand((t) => t).toList();
      Team? findTeam(String id) {
        for (final t in teamsThisSeason) {
          if (t.id == id) return t;
        }
        return null;
      }

      final champion = pairing == null ? null : findTeam(pairing.$1);
      final opponent = pairing == null ? null : findTeam(pairing.$2);
      if (champion != null && opponent != null && champion.id != opponent.id) {
        final superCup = CupMatch(
          round: 1,
          homeTeamId: champion.id,
          awayTeamId: opponent.id,
        );
        if (champion.id == _save!.userTeamId ||
            opponent.id == _save!.userTeamId) {
          _save!.pendingSuperCup = superCup;
        } else {
          final result = MatchEngine.simulate(
            home: champion,
            away: opponent,
            matchday: 0,
            weather: WeatherEngine.roll(),
          );
          superCup.result = result;
          if (result.homeGoals == result.awayGoals) {
            superCup.penaltyWinnerId = CupEngine.decidePenaltyWinner(
              champion,
              opponent,
            );
          }
          final winnerName =
              superCup.winnerId == champion.id ? champion.name : opponent.name;
          lastSuperCupNews = '$winnerNameがスーパーカップを制した。';
        }
      }
    }

    _save!.cups = [
      CupEngine.createKnockout(
        type: CupType.domestic,
        name: currentLeagueTheme.domesticCupName,
        teamIds: newActiveTeams.map((t) => t.id).toList(),
      ),
    ];
    if (playedTier == 1 && finalRank <= 2) {
      final continentalTeams = _generateContinentalTeams();
      _save!.continentalTeams = continentalTeams;
      _save!.continentalCup = ContinentalCupEngine.create(
        name: '大陸チャンピオンズカップ',
        teamIds: [_save!.userTeamId, ...continentalTeams.map((t) => t.id)],
      );
    } else {
      _save!.continentalTeams = [];
      _save!.continentalCup = null;
    }
    _save!.friendlies = _generateFriendlies(newActiveTeams, _save!.userTeamId);
    _save!.boardReviewDoneThisSeason = false;
    _save!.pendingBoardReviewMessage = null;
    _save!.lastManagerOfMonthCheckpoint = 0;
    // シーズン最終週に自動実施等でトレーニング済みのまま次シーズンへ入ると、
    // プレシーズン中ずっとrunWeeklyTrainingが「実施済み」扱いでブロックされて
    // しまうため、週次フラグも明示的にリセットする。
    _save!.trainingDoneThisWeek = false;

    // 次シーズン終了時の成長算出のため、開始時点の総合力を記録しておく。
    _save!.seasonStartOverallByPlayerId = {
      for (final p in userTeam.players) p.id: p.overall,
    };

    isBusy = false;
    notifyListeners();
    await _persist();
  }
}
