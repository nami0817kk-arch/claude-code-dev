import 'bank_loan.dart';
import 'best_eleven.dart';
import 'club_infrastructure.dart';
import 'enum_json.dart';
import 'continental_cup.dart';
import 'contract_negotiation.dart';
import 'cup.dart';
import 'incoming_offer.dart';
import 'installment.dart';
import 'investment.dart';
import 'league.dart';
import 'news_item.dart';
import 'player.dart';
import 'press_question.dart';
import 'season_award.dart';
import 'season_record.dart';
import 'sponsor.dart';
import 'team.dart';

/// ゲーム難易度。ニューゲーム時に選択し、初期資金と理事会の目標順位の
/// 厳しさに影響する(旧セーブには存在しないためnormalへフォールバック)。
enum GameDifficulty { easy, normal, hard }

extension GameDifficultyInfo on GameDifficulty {
  String get label => switch (this) {
        GameDifficulty.easy => 'イージー',
        GameDifficulty.normal => 'ノーマル',
        GameDifficulty.hard => 'ハード',
      };

  String get description => switch (this) {
        GameDifficulty.easy => '初期資金1.5倍・理事会の目標が2つ緩い',
        GameDifficulty.normal => '標準バランス',
        GameDifficulty.hard => '初期資金0.6倍・理事会の目標が1つ厳しい',
      };

  /// 初期資金に掛ける倍率。
  double get initialBudgetFactor => switch (this) {
        GameDifficulty.easy => 1.5,
        GameDifficulty.normal => 1.0,
        GameDifficulty.hard => 0.6,
      };

  /// 理事会の目標順位への補正(正の値ほど目標が緩くなる)。
  int get boardTargetDelta => switch (this) {
        GameDifficulty.easy => 2,
        GameDifficulty.normal => 0,
        GameDifficulty.hard => -1,
      };
}

class SaveGame {
  String clubName;
  String userTeamId;
  League league;

  /// 所属リーグの表示名(例: 「アルビオン・リーグ」)。
  String leagueName;

  /// クラブ資金（万円）
  int budget;

  /// 理事会が今シーズンに求める目標順位（1が最高位）
  int boardTargetRank;

  /// 監督への信頼度（0-100）。0になると解任される。
  int confidence;

  /// 監督としての世間の評価（0-100）。信頼度と異なり解任されても引き継がれ、
  /// 他クラブからのオファーの受けやすさに影響する。
  int managerReputation;

  /// 他クラブから監督就任オファーが届いている場合、そのクラブのID。
  String? pendingJobOfferTeamId;

  /// ユース昇格候補・スカウトした有望株。
  List<Player> youthProspects;

  /// 移籍市場に出ている選手(海外リーグからの移籍候補)。毎節ごとに
  /// 全員を作り直すのではなく数人ずつ入れ替わる持続的な市場で、
  /// ロードしても同じ顔ぶれが維持されるようセーブに含める。
  List<Player> transferMarketPlayers;

  /// シーズン終了時に一括生成された、選抜待ちのユースインテーク候補。
  List<Player> pendingYouthIntake;

  /// 若手有望株ランキングで追跡対象に指定した選手のID一覧
  /// (自クラブ以外の選手も含む、閲覧専用のウォッチリスト)。
  List<String> watchlistPlayerIds;

  /// 現在のチケット価格戦略(観客動員率と1人あたり収入のトレードオフ)。
  TicketPricing ticketPricing;

  /// スタッフ・施設のレベル。
  ClubInfrastructure infrastructure;

  /// 今シーズン進行中の国内カップ戦。
  List<Cup> cups;

  /// 今シーズン進行中の大陸カップ(グループステージ+決勝トーナメント)。
  /// 出場資格がない間はnull。
  ContinentalCup? continentalCup;

  /// 前シーズン終了時の最終順位(大陸カップ出場資格判定に使用)。未経験の場合はnull。
  int? lastSeasonRank;

  /// 大陸カップに参加する海外クラブ(出場資格がある間のみ生成される)。
  List<Team> continentalTeams;

  /// 現在契約中のスポンサー。未契約の場合はnull。
  SponsorDeal? sponsorDeal;

  /// 契約更新・新規契約のために提示されている候補(未選択の間はスポンサー収入が発生しない)。
  List<SponsorDeal> pendingSponsorOffers;

  /// 分割払いで獲得した選手の残金支払い予定。
  List<Installment> pendingInstallments;

  /// シーズン開幕前の親善試合日程。
  List<Fixture> friendlies;

  /// 他クラブから届いている、自クラブ選手への移籍オファー。
  List<IncomingOffer> incomingOffers;

  /// 銀行から借り入れている融資。
  List<BankLoan> bankLoans;

  /// 銀行に預け入れている定期預金(資金運用)。満期まで引き出せない。
  List<FixedDeposit> fixedDeposits;

  /// シーズンごとに確定した個人タイトル(得点王・年間MVP)の履歴。
  List<SeasonAward> seasonAwards;

  /// ライバルクラブのID・表示名(開幕時に決定し、以後固定)。
  String? rivalTeamId;
  String? rivalTeamName;

  /// 回答待ちの記者会見の質問。ない場合はnull。
  PressQuestion? pendingPressConference;

  /// ユーザーの現在の所属ディビジョン以外の各ディビジョンのリーグ。添字0が1部、
  /// 添字[totalDivisionTiers]-1が最下位ティア。ユーザーの現在の所属ティアに
  /// 対応する添字は使用しない(null)。ユーザーの節送りに合わせて同じ節番号の
  /// 試合を裏で消化しておくことで、昇格・降格に意味のある他ディビジョンの
  /// 順位表を常時閲覧できるようにする。シーズン終了時はこの順位確定順を
  /// 昇格・降格の判定にそのまま使う。
  List<League?> otherDivisionLeagues;

  /// ユーザークラブが現在所属するディビジョン(1が最上位、[totalDivisionTiers]が最下位)。
  int currentDivisionTier;

  /// 監督としての通算成績。
  int careerWins;
  int careerDraws;
  int careerLosses;
  int careerSeasons;

  /// 実績(アチーブメント)判定に使う通算カウンター群。旧セーブには
  /// 存在しないためfromJsonでは0にフォールバックする(過去分は遡って
  /// 数えられないが、読み込んだ時点からカウントが始まる)。
  int negotiationSignings; // 値切り交渉で獲得が成立した回数
  int breakthroughCount; // 自クラブ選手の才能開花を見届けた回数
  int traitsAcquired; // 特訓・指導で特性を習得させた回数
  int liveWins; // ライブ観戦(決定機の判断あり)で勝利した回数
  int careerCupPrize; // カップ戦で獲得した賞金・優勝報酬の通算(万円)
  int pkShootoutWins; // ライブ観戦のPK戦を制した回数

  /// ゲーム難易度(ニューゲーム時に選択)。
  GameDifficulty difficulty;

  /// クラブニュース(お知らせ履歴)。新しいものが先頭。SnackBar等で
  /// 一度流れて消える通知を、あとから見返せるように保存する。件数は
  /// GameState側で上限管理する。旧セーブには存在しないため空で補完する。
  List<NewsItem> newsLog;

  /// 獲得したタイトルの履歴(リーグ優勝・カップ優勝など)。
  List<String> trophyHistory;

  /// これまで指揮したクラブ名の履歴(就任順)。
  List<String> clubHistory;

  /// 契約満了で放出された選手や、市場に出回っているベテランなど、
  /// 移籍金なし(週俸のみ)で獲得できるフリーエージェントのプール。
  List<Player> freeAgents;

  /// 引退した選手(殿堂)。契約満了で単に自由契約になった選手とは異なり、
  /// 高齢による正式な引退のため再契約はできない。
  List<Player> retiredLegends;

  /// シーズンごとの成績アーカイブ(最終順位・勝敗・昇降格・カップ優勝歴)。
  List<SeasonRecord> seasonHistory;

  /// シーズンごとのベストイレブン選出履歴。
  List<SeasonBestEleven> bestElevenHistory;

  /// シーズン中盤の理事会レビューを既に実施したかどうか(シーズン開始時にリセット)。
  bool boardReviewDoneThisSeason;

  /// 表示待ちのシーズン中盤レビューの講評文(ない場合はnull)。
  String? pendingBoardReviewMessage;

  /// 月間最優秀監督賞の集計済み節数(この節までの成績は既に賞の判定に使用済み)。
  /// シーズン開始時に0へリセットされる。
  int lastManagerOfMonthCheckpoint;

  /// 今週すでにトレーニングを実施済みかどうか(節が進むとリセットされる)。
  bool trainingDoneThisWeek;

  /// 進行中の契約交渉(週俸の駆け引き)。ない場合はnull。
  ContractNegotiation? pendingContractNegotiation;

  /// 新シーズン開幕前のスーパーカップ(前シーズンのリーグ王者 対 国内カップ王者)。
  /// ユーザークラブが出場する場合のみ、結果が未確定のまま保持される。
  CupMatch? pendingSuperCup;

  /// 資金がマイナスのまま連続している週数(黒字化した時点で0にリセットされる)。
  /// 一定週数を超えると理事会の信頼度にペナルティが科される。
  int consecutiveNegativeBudgetWeeks;

  /// 解除済みの実績(アチーブメント)ID→達成したシーズン番号。
  Map<String, int> unlockedAchievements;

  /// 現在のシーズン開始時点での自クラブ選手の総合力(選手ID→総合力)。
  /// シーズン終了時に、この時点からの成長を選手ごとに算出するために使う。
  Map<String, int> seasonStartOverallByPlayerId;

  SaveGame({
    required this.clubName,
    required this.userTeamId,
    required this.league,
    this.leagueName = 'リーグ',
    this.budget = 6000,
    this.boardTargetRank = 4,
    this.confidence = 60,
    this.managerReputation = 50,
    this.pendingJobOfferTeamId,
    List<Player>? youthProspects,
    List<Player>? transferMarketPlayers,
    List<Player>? pendingYouthIntake,
    List<String>? watchlistPlayerIds,
    this.ticketPricing = TicketPricing.standard,
    ClubInfrastructure? infrastructure,
    List<Cup>? cups,
    this.continentalCup,
    this.lastSeasonRank,
    List<Team>? continentalTeams,
    this.sponsorDeal,
    List<SponsorDeal>? pendingSponsorOffers,
    List<Installment>? pendingInstallments,
    List<Fixture>? friendlies,
    List<IncomingOffer>? incomingOffers,
    List<BankLoan>? bankLoans,
    List<FixedDeposit>? fixedDeposits,
    List<SeasonAward>? seasonAwards,
    this.rivalTeamId,
    this.rivalTeamName,
    this.pendingPressConference,
    List<League?>? otherDivisionLeagues,
    this.currentDivisionTier = 1,
    this.careerWins = 0,
    this.careerDraws = 0,
    this.careerLosses = 0,
    this.careerSeasons = 0,
    this.negotiationSignings = 0,
    this.breakthroughCount = 0,
    this.traitsAcquired = 0,
    this.liveWins = 0,
    this.careerCupPrize = 0,
    this.pkShootoutWins = 0,
    this.difficulty = GameDifficulty.normal,
    List<NewsItem>? newsLog,
    List<String>? trophyHistory,
    List<String>? clubHistory,
    List<Player>? freeAgents,
    List<Player>? retiredLegends,
    List<SeasonRecord>? seasonHistory,
    List<SeasonBestEleven>? bestElevenHistory,
    this.boardReviewDoneThisSeason = false,
    this.pendingBoardReviewMessage,
    this.lastManagerOfMonthCheckpoint = 0,
    this.trainingDoneThisWeek = false,
    this.pendingContractNegotiation,
    this.pendingSuperCup,
    this.consecutiveNegativeBudgetWeeks = 0,
    Map<String, int>? unlockedAchievements,
    Map<String, int>? seasonStartOverallByPlayerId,
  })  : unlockedAchievements = unlockedAchievements ?? {},
        seasonStartOverallByPlayerId = seasonStartOverallByPlayerId ?? {},
        newsLog = newsLog ?? [],
        trophyHistory = trophyHistory ?? [],
        clubHistory = clubHistory ?? [],
        freeAgents = freeAgents ?? [],
        retiredLegends = retiredLegends ?? [],
        seasonHistory = seasonHistory ?? [],
        bestElevenHistory = bestElevenHistory ?? [],
        youthProspects = youthProspects ?? [],
        transferMarketPlayers = transferMarketPlayers ?? [],
        pendingYouthIntake = pendingYouthIntake ?? [],
        watchlistPlayerIds = watchlistPlayerIds ?? [],
        infrastructure = infrastructure ?? ClubInfrastructure(),
        cups = cups ?? [],
        continentalTeams = continentalTeams ?? [],
        pendingSponsorOffers = pendingSponsorOffers ?? [],
        pendingInstallments = pendingInstallments ?? [],
        friendlies = friendlies ?? [],
        incomingOffers = incomingOffers ?? [],
        bankLoans = bankLoans ?? [],
        fixedDeposits = fixedDeposits ?? [],
        seasonAwards = seasonAwards ?? [],
        otherDivisionLeagues = otherDivisionLeagues ??
            List<League?>.filled(totalDivisionTiers, null);

  /// 全ディビジョンの全チーム(現在の所属ディビジョンも含む)。ID再採番や
  /// スーパーカップの対戦相手検索など、所属ティアを問わず全チームが必要な
  /// 場面で使う。
  List<Team> get allTeams => [
        ...league.teams,
        for (final l in otherDivisionLeagues)
          if (l != null) ...l.teams,
      ];

  Map<String, dynamic> toJson() => {
        'clubName': clubName,
        'userTeamId': userTeamId,
        'league': league.toJson(),
        'leagueName': leagueName,
        'budget': budget,
        'boardTargetRank': boardTargetRank,
        'confidence': confidence,
        'managerReputation': managerReputation,
        'pendingJobOfferTeamId': pendingJobOfferTeamId,
        'youthProspects': youthProspects.map((p) => p.toJson()).toList(),
        'transferMarketPlayers':
            transferMarketPlayers.map((p) => p.toJson()).toList(),
        'pendingYouthIntake':
            pendingYouthIntake.map((p) => p.toJson()).toList(),
        'watchlistPlayerIds': watchlistPlayerIds,
        'ticketPricing': ticketPricing.name,
        'infrastructure': infrastructure.toJson(),
        'cups': cups.map((c) => c.toJson()).toList(),
        'continentalCup': continentalCup?.toJson(),
        'lastSeasonRank': lastSeasonRank,
        'continentalTeams': continentalTeams.map((t) => t.toJson()).toList(),
        'sponsorDeal': sponsorDeal?.toJson(),
        'pendingSponsorOffers':
            pendingSponsorOffers.map((s) => s.toJson()).toList(),
        'pendingInstallments':
            pendingInstallments.map((i) => i.toJson()).toList(),
        'friendlies': friendlies.map((f) => f.toJson()).toList(),
        'incomingOffers': incomingOffers.map((o) => o.toJson()).toList(),
        'bankLoans': bankLoans.map((l) => l.toJson()).toList(),
        'fixedDeposits': fixedDeposits.map((d) => d.toJson()).toList(),
        'seasonAwards': seasonAwards.map((a) => a.toJson()).toList(),
        'rivalTeamId': rivalTeamId,
        'rivalTeamName': rivalTeamName,
        'pendingPressConference': pendingPressConference?.toJson(),
        'otherDivisionLeagues':
            otherDivisionLeagues.map((l) => l?.toJson()).toList(),
        'currentDivisionTier': currentDivisionTier,
        'careerWins': careerWins,
        'careerDraws': careerDraws,
        'careerLosses': careerLosses,
        'careerSeasons': careerSeasons,
        'negotiationSignings': negotiationSignings,
        'breakthroughCount': breakthroughCount,
        'traitsAcquired': traitsAcquired,
        'liveWins': liveWins,
        'careerCupPrize': careerCupPrize,
        'pkShootoutWins': pkShootoutWins,
        'difficulty': difficulty.name,
        'newsLog': newsLog.map((n) => n.toJson()).toList(),
        'trophyHistory': trophyHistory,
        'clubHistory': clubHistory,
        'freeAgents': freeAgents.map((p) => p.toJson()).toList(),
        'retiredLegends': retiredLegends.map((p) => p.toJson()).toList(),
        'seasonHistory': seasonHistory.map((r) => r.toJson()).toList(),
        'bestElevenHistory': bestElevenHistory.map((r) => r.toJson()).toList(),
        'boardReviewDoneThisSeason': boardReviewDoneThisSeason,
        'pendingBoardReviewMessage': pendingBoardReviewMessage,
        'lastManagerOfMonthCheckpoint': lastManagerOfMonthCheckpoint,
        'trainingDoneThisWeek': trainingDoneThisWeek,
        'pendingContractNegotiation': pendingContractNegotiation?.toJson(),
        'pendingSuperCup': pendingSuperCup?.toJson(),
        'consecutiveNegativeBudgetWeeks': consecutiveNegativeBudgetWeeks,
        'unlockedAchievements': unlockedAchievements,
        'seasonStartOverallByPlayerId': seasonStartOverallByPlayerId,
      };

  factory SaveGame.fromJson(Map<String, dynamic> json) => SaveGame(
        clubName: json['clubName'] as String,
        userTeamId: json['userTeamId'] as String,
        league: League.fromJson(json['league'] as Map<String, dynamic>),
        leagueName: json['leagueName'] as String? ?? 'リーグ',
        budget: json['budget'] as int? ?? 3000,
        boardTargetRank: json['boardTargetRank'] as int? ?? 4,
        confidence: json['confidence'] as int? ?? 60,
        managerReputation: json['managerReputation'] as int? ?? 50,
        pendingJobOfferTeamId: json['pendingJobOfferTeamId'] as String?,
        youthProspects: (json['youthProspects'] as List?)
                ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        transferMarketPlayers: (json['transferMarketPlayers'] as List?)
                ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        pendingYouthIntake: (json['pendingYouthIntake'] as List?)
                ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        watchlistPlayerIds: (json['watchlistPlayerIds'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        ticketPricing: enumFromName(
          TicketPricing.values,
          json['ticketPricing'] as String?,
          TicketPricing.standard,
        ),
        infrastructure: ClubInfrastructure.fromJson(
          json['infrastructure'] as Map<String, dynamic>?,
        ),
        cups: (json['cups'] as List?)
                ?.map((e) => Cup.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        continentalCup: json['continentalCup'] == null
            ? null
            : ContinentalCup.fromJson(
                json['continentalCup'] as Map<String, dynamic>,
              ),
        lastSeasonRank: json['lastSeasonRank'] as int?,
        continentalTeams: (json['continentalTeams'] as List?)
                ?.map((e) => Team.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        sponsorDeal: json['sponsorDeal'] == null
            ? null
            : SponsorDeal.fromJson(json['sponsorDeal'] as Map<String, dynamic>),
        pendingSponsorOffers: (json['pendingSponsorOffers'] as List?)
                ?.map((e) => SponsorDeal.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        pendingInstallments: (json['pendingInstallments'] as List?)
                ?.map((e) => Installment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        friendlies: (json['friendlies'] as List?)
                ?.map((e) => Fixture.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        incomingOffers: (json['incomingOffers'] as List?)
                ?.map((e) => IncomingOffer.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        bankLoans: (json['bankLoans'] as List?)
                ?.map((e) => BankLoan.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        fixedDeposits: (json['fixedDeposits'] as List?)
                ?.map((e) => FixedDeposit.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        seasonAwards: (json['seasonAwards'] as List?)
                ?.map((e) => SeasonAward.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        rivalTeamId: json['rivalTeamId'] as String?,
        rivalTeamName: json['rivalTeamName'] as String?,
        pendingPressConference: json['pendingPressConference'] == null
            ? null
            : PressQuestion.fromJson(
                json['pendingPressConference'] as Map<String, dynamic>,
              ),
        otherDivisionLeagues: json['otherDivisionLeagues'] != null
            ? (json['otherDivisionLeagues'] as List)
                .map(
                  (e) => e == null
                      ? null
                      : League.fromJson(e as Map<String, dynamic>),
                )
                .toList()
            : _legacyOtherDivisionLeagues(json),
        currentDivisionTier: json['currentDivisionTier'] as int? ?? 1,
        careerWins: json['careerWins'] as int? ?? 0,
        careerDraws: json['careerDraws'] as int? ?? 0,
        careerLosses: json['careerLosses'] as int? ?? 0,
        careerSeasons: json['careerSeasons'] as int? ?? 0,
        negotiationSignings: json['negotiationSignings'] as int? ?? 0,
        breakthroughCount: json['breakthroughCount'] as int? ?? 0,
        traitsAcquired: json['traitsAcquired'] as int? ?? 0,
        liveWins: json['liveWins'] as int? ?? 0,
        careerCupPrize: json['careerCupPrize'] as int? ?? 0,
        pkShootoutWins: json['pkShootoutWins'] as int? ?? 0,
        difficulty: GameDifficulty.values.firstWhere(
          (d) => d.name == json['difficulty'],
          orElse: () => GameDifficulty.normal,
        ),
        newsLog: (json['newsLog'] as List?)
            ?.map((e) => NewsItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        trophyHistory: (json['trophyHistory'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        clubHistory:
            (json['clubHistory'] as List?)?.map((e) => e as String).toList() ??
                [],
        freeAgents: (json['freeAgents'] as List?)
                ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        retiredLegends: (json['retiredLegends'] as List?)
                ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        seasonHistory: (json['seasonHistory'] as List?)
                ?.map((e) => SeasonRecord.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        bestElevenHistory: (json['bestElevenHistory'] as List?)
                ?.map(
                    (e) => SeasonBestEleven.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        boardReviewDoneThisSeason:
            json['boardReviewDoneThisSeason'] as bool? ?? false,
        pendingBoardReviewMessage: json['pendingBoardReviewMessage'] as String?,
        lastManagerOfMonthCheckpoint:
            json['lastManagerOfMonthCheckpoint'] as int? ?? 0,
        trainingDoneThisWeek: json['trainingDoneThisWeek'] as bool? ?? false,
        pendingContractNegotiation: json['pendingContractNegotiation'] == null
            ? null
            : ContractNegotiation.fromJson(
                json['pendingContractNegotiation'] as Map<String, dynamic>,
              ),
        pendingSuperCup: json['pendingSuperCup'] == null
            ? null
            : CupMatch.fromJson(
                json['pendingSuperCup'] as Map<String, dynamic>),
        consecutiveNegativeBudgetWeeks:
            json['consecutiveNegativeBudgetWeeks'] as int? ?? 0,
        unlockedAchievements: (json['unlockedAchievements'] as Map?)?.map(
              (k, v) => MapEntry(k as String, v as int),
            ) ??
            {},
        seasonStartOverallByPlayerId:
            (json['seasonStartOverallByPlayerId'] as Map?)?.map(
                  (k, v) => MapEntry(k as String, v as int),
                ) ??
                {},
      );

  /// 5部制ピラミッド導入前の旧セーブデータ(`otherDivisionLeagues`キーが
  /// 存在しない)を読み込む際、旧来の単一`otherDivisionLeague`
  /// (`secondDivisionTeams`しかない、さらに古い世代のデータの場合はチーム
  /// 一覧のみ)を、現在のティア以外の添字がnullな[totalDivisionTiers]要素の
  /// リストへ変換する。新たに追加された下位ティア(3部以下)は、この時点では
  /// 生成できないためnullのままにし、GameState起動時のマイグレーションで
  /// 補充する。
  static List<League?> _legacyOtherDivisionLeagues(Map<String, dynamic> json) {
    final tier = json['currentDivisionTier'] as int? ?? 1;
    final result = List<League?>.filled(totalDivisionTiers, null);
    final otherTier = tier == 1 ? 2 : 1;
    if (otherTier < 1 || otherTier > totalDivisionTiers) return result;
    if (json['otherDivisionLeague'] != null) {
      result[otherTier - 1] = League.fromJson(
        json['otherDivisionLeague'] as Map<String, dynamic>,
      );
    } else if (json['secondDivisionTeams'] != null) {
      final teams = (json['secondDivisionTeams'] as List)
          .map((e) => Team.fromJson(e as Map<String, dynamic>))
          .toList();
      result[otherTier - 1] = League(teams: teams, fixtures: const []);
    }
    return result;
  }
}
