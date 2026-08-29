import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/achievement_engine.dart';
import 'package:soccer_manager/logic/ai_transfer_engine.dart';
import 'package:soccer_manager/logic/calendar_engine.dart';
import 'package:soccer_manager/logic/awards_engine.dart';
import 'package:soccer_manager/logic/best_eleven_engine.dart';
import 'package:soccer_manager/logic/board_engine.dart';
import 'package:soccer_manager/logic/contract_engine.dart';
import 'package:soccer_manager/logic/continental_cup_engine.dart';
import 'package:soccer_manager/logic/cup_engine.dart';
import 'package:soccer_manager/logic/happiness_engine.dart';
import 'package:soccer_manager/logic/lineup_utils.dart';
import 'package:soccer_manager/logic/investment_engine.dart';
import 'package:soccer_manager/logic/loan_engine.dart';
import 'package:soccer_manager/logic/manager_career_engine.dart';
import 'package:soccer_manager/logic/match_engine.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/promotion_engine.dart';
import 'package:soccer_manager/logic/retirement_engine.dart';
import 'package:soccer_manager/logic/rotation_engine.dart';
import 'package:soccer_manager/logic/super_cup_engine.dart';
import 'package:soccer_manager/logic/scout_report_engine.dart';
import 'package:soccer_manager/logic/scouting_engine.dart';
import 'package:soccer_manager/logic/season_projection_engine.dart';
import 'package:soccer_manager/logic/sponsor_engine.dart';
import 'package:soccer_manager/logic/training_engine.dart';
import 'package:soccer_manager/logic/transfer_market.dart';
import 'package:soccer_manager/logic/weather_engine.dart';
import 'package:soccer_manager/data/name_pool.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/contract_negotiation.dart';
import 'package:soccer_manager/models/cup.dart';
import 'package:soccer_manager/models/enum_json.dart';
import 'package:soccer_manager/models/formation.dart';
import 'package:soccer_manager/models/incoming_offer.dart';
import 'package:soccer_manager/models/league.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/season_award.dart';
import 'package:soccer_manager/models/season_record.dart';
import 'package:soccer_manager/models/sponsor.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/models/team_talk.dart';
import 'package:soccer_manager/models/weather.dart';
import 'package:soccer_manager/screens/squad_screen.dart';
import 'package:soccer_manager/screens/transfer_screen.dart';
import 'package:soccer_manager/screens/youth_screen.dart';
import 'package:soccer_manager/screens/glossary_screen.dart';
import 'package:soccer_manager/data/glossary_entries.dart';
import 'package:soccer_manager/data/guide_sections.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/widgets/formation_layout.dart';
import 'package:soccer_manager/widgets/match_widgets.dart'
    show matchCommentaryText;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
      'LineupUtils.autoFill fills all 11 formation slots with a real goalkeeper in goal',
      () {
    final team = PlayerGenerator.generateSquad(
        id: 't1', name: 'Test FC', strengthTier: 60);
    team.formation = Formation.f433;
    LineupUtils.autoFill(team);

    expect(team.startingXI.length, 11);
    expect(team.startingXI.toSet().length, 11);
    final byId = {for (final p in team.players) p.id: p};
    // 副ポジションはグループを跨いで設定されうる(例: トップ下がセンターMFを兼任)ため、
    // グループ単位の人数一致までは保証されない。ただしGK枠は他ポジションの副ポジション
    // 候補になり得ないため、常にGKで埋まることは保証できる。
    expect(byId[team.startingXI.first]!.position, Position.gk);
  });

  test('LineupUtils.autoFill excludes injured players', () {
    final team = PlayerGenerator.generateSquad(
        id: 't2', name: 'Test FC', strengthTier: 60);
    for (final p in team.players.where((p) => p.position == Position.st)) {
      p.injuryWeeks = 2;
    }
    LineupUtils.autoFill(team);
    final byId = {for (final p in team.players) p.id: p};
    final lineup = team.startingXI.map((id) => byId[id]!).toList();
    expect(lineup.every((p) => !p.isInjured), isTrue);
  });

  test(
      'LineupUtils.autoFill falls back to same-group players when a position is missing',
      () {
    final team = PlayerGenerator.generateSquad(
        id: 't1b', name: 'Test FC', strengthTier: 60);
    team.players.removeWhere((p) => p.position == Position.st);
    team.formation = Formation.f442; // needs 2 ST, none available
    LineupUtils.autoFill(team);

    expect(team.startingXI.length, 11);
    final byId = {for (final p in team.players) p.id: p};
    final lineup = team.startingXI.map((id) => byId[id]!).toList();
    // ST枠はATTグループの他ポジション(AMR/AMC/AML)で代用されているはず
    expect(lineup.any((p) => p.position.group == PositionGroup.att), isTrue);
  });

  test('TransferMarket.generate returns the requested count', () {
    final market = TransferMarket.generate(count: 7);
    expect(market.length, 7);
  });

  test('TransferMarket.generate tags every candidate with an origin club name',
      () {
    final market = TransferMarket.generate(count: 12);
    for (final p in market) {
      expect(p.originClubName, isNotNull);
      expect(p.originClubName, isNotEmpty);
    }
  });

  test('BoardEngine confidence deltas reward wins and punish bad losses', () {
    final win = MatchResult(
        matchday: 1,
        homeTeamId: 'user',
        awayTeamId: 'cpu',
        homeGoals: 2,
        awayGoals: 0,
        events: []);
    final loss = MatchResult(
        matchday: 1,
        homeTeamId: 'user',
        awayTeamId: 'cpu',
        homeGoals: 0,
        awayGoals: 2,
        events: []);
    expect(BoardEngine.confidenceDeltaForMatch(win, 'user'), greaterThan(0));
    expect(BoardEngine.confidenceDeltaForMatch(loss, 'user'), lessThan(0));
  });

  test('BoardEngine.seasonPrizeMoney gives 1st place more than last place', () {
    final first = BoardEngine.seasonPrizeMoney(finalRank: 1, teamCount: 8);
    final last = BoardEngine.seasonPrizeMoney(finalRank: 8, teamCount: 8);
    expect(first, greaterThan(last));
  });

  test(
      'BoardEngine.negativeBudgetConfidenceDelta only penalizes at the '
      'threshold multiple of consecutive negative-budget weeks', () {
    expect(BoardEngine.negativeBudgetConfidenceDelta(0), 0);
    expect(BoardEngine.negativeBudgetConfidenceDelta(7), 0);
    expect(BoardEngine.negativeBudgetConfidenceDelta(8), lessThan(0));
    expect(BoardEngine.negativeBudgetConfidenceDelta(9), 0);
    expect(BoardEngine.negativeBudgetConfidenceDelta(16), lessThan(0));
  });

  test(
      'GameState.playNextMatchday raises consecutiveNegativeBudgetWeeks while '
      'the budget stays negative and resets it once the budget recovers',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.budget = -999999;
    await gameState.playNextMatchday();
    if (gameState.isHalfTime) await gameState.playSecondHalf();
    expect(gameState.save!.consecutiveNegativeBudgetWeeks, 1);

    gameState.save!.budget = 999999;
    await gameState.playNextMatchday();
    if (gameState.isHalfTime) await gameState.playSecondHalf();
    expect(gameState.save!.consecutiveNegativeBudgetWeeks, 0);
  });

  test(
      'BoardEngine.midSeasonReviewDelta rewards being on pace and punishes '
      'badly trailing the target', () {
    expect(BoardEngine.midSeasonReviewDelta(currentRank: 2, targetRank: 4),
        greaterThan(0));
    expect(BoardEngine.midSeasonReviewDelta(currentRank: 5, targetRank: 4), 0);
    expect(BoardEngine.midSeasonReviewDelta(currentRank: 10, targetRank: 4),
        lessThan(0));
  });

  test(
      'GameState.playNextMatchday triggers exactly one board review at mid-season',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    expect(gameState.save!.boardReviewDoneThisSeason, isFalse);

    var reviewSeenCount = 0;
    while (!gameState.save!.league.isSeasonComplete) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
      if (gameState.pendingBoardReviewMessage != null) {
        reviewSeenCount++;
        await gameState.dismissBoardReview();
      }
    }

    expect(reviewSeenCount, 1);
    expect(gameState.save!.boardReviewDoneThisSeason, isTrue);
  });

  test(
      'GameState.playSecondHalf advances the manager-of-the-month checkpoint '
      'in steps of 4 matchdays and resets it for the next season', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    var lastCheckpoint = 0;
    while (!gameState.save!.league.isSeasonComplete) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
      final checkpoint = gameState.save!.lastManagerOfMonthCheckpoint;
      expect(checkpoint - lastCheckpoint, anyOf(0, 4));
      lastCheckpoint = checkpoint;
    }

    await gameState.startNextSeason();
    expect(gameState.save!.lastManagerOfMonthCheckpoint, 0);
  });

  test(
      'GameState.playSecondHalf records a career milestone once a userTeam '
      "player's careerGoals crosses a round-number threshold", () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    for (final p in gameState.userTeam.players) {
      p.careerGoals = 49;
    }

    var found = false;
    for (int i = 0;
        i < 10 && !found && !gameState.save!.league.isSeasonComplete;
        i++) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
        if (gameState.lastMilestones.any((m) => m.contains('通算50得点'))) {
          found = true;
        }
      }
      for (final p in gameState.userTeam.players) {
        if (p.careerGoals > 49) p.careerGoals = 49;
      }
    }

    expect(found, isTrue);
  });

  test('GameState.buyPlayer deducts budget and adds the player to the squad',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final beforeCount = gameState.userTeam.players.length;
    final target = gameState.transferMarket.first;
    gameState.save!.budget = target.marketValue + 100;

    final ok = await gameState.buyPlayer(target.id);

    expect(ok, isTrue);
    expect(gameState.userTeam.players.length, beforeCount + 1);
    expect(gameState.save!.budget, 100);
  });

  test('GameState.buyPlayer fails when budget is insufficient', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.transferMarket.first;
    gameState.save!.budget = 0;

    final ok = await gameState.buyPlayer(target.id);

    expect(ok, isFalse);
  });

  test('GameState.sellPlayer refuses to drop below the minimum squad size',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    while (gameState.userTeam.players.length > minSquadSize) {
      final id = gameState.userTeam.players.first.id;
      await gameState.sellPlayer(id);
    }
    final lastId = gameState.userTeam.players.first.id;
    final ok = await gameState.sellPlayer(lastId);
    expect(ok, isFalse);
  });

  test(
      'ContractEngine.advanceSeason decrements contracts by one year and '
      'removes expired players', () {
    final team = PlayerGenerator.generateSquad(
        id: 't3', name: 'Test FC', strengthTier: 60);
    // 他の選手が偶然同じタイミングで契約切れにならないよう、十分な年数にしておく。
    for (final p in team.players) {
      p.contractYearsRemaining = 99;
    }
    final soonToExpire = team.players.first;
    soonToExpire.contractYearsRemaining = 1;
    team.startingXI = [soonToExpire.id];
    final beforeCount = team.players.length;

    final result = ContractEngine.advanceSeason(team);

    expect(result.expired.map((p) => p.id), contains(soonToExpire.id));
    expect(team.players.length, beforeCount - 1);
    expect(team.startingXI, isNot(contains(soonToExpire.id)));
  });

  test(
      'ContractEngine.advanceSeason warns once a contract enters its final '
      'year, without removing the player', () {
    final team = PlayerGenerator.generateSquad(
        id: 't3b', name: 'Test FC', strengthTier: 60);
    // 他の選手が偶然同じタイミングで契約切れにならないよう、十分な年数にしておく。
    for (final p in team.players) {
      p.contractYearsRemaining = 99;
    }
    final enteringFinalYear = team.players.first;
    enteringFinalYear.contractYearsRemaining = 2;
    final beforeCount = team.players.length;

    final result = ContractEngine.advanceSeason(team);

    expect(enteringFinalYear.contractYearsRemaining, 1);
    expect(
        result.nearingExpiry.map((p) => p.id), contains(enteringFinalYear.id));
    expect(result.expired, isEmpty);
    expect(team.players.length, beforeCount);
  });

  test('ContractEngine.weeklyWageBill sums all player wages', () {
    final team = PlayerGenerator.generateSquad(
        id: 't4', name: 'Test FC', strengthTier: 60);
    final expectedTotal = team.players.fold<int>(0, (s, p) => s + p.wage);
    expect(ContractEngine.weeklyWageBill(team), expectedTotal);
  });

  test('ScoutingEngine prospects are young academy-age players', () {
    final scouted = ScoutingEngine.generateScoutedProspect();
    final academy = ScoutingEngine.generateAcademyGraduate();
    expect(scouted.age, inInclusiveRange(16, 19));
    expect(academy.age, inInclusiveRange(16, 19));
  });

  test('TrainingEngine respects a player individual focus override', () {
    final team = PlayerGenerator.generateSquad(
        id: 't5', name: 'Test FC', strengthTier: 60);
    team.defaultTrainingFocus = TrainingFocus.rest;
    final target = team.players.firstWhere((p) => p.position == Position.st);
    target.individualFocus = TrainingFocus.attack;
    target.setAttributeValue(AttributeKeys.finishing, 40);
    target.potential = 99;
    target.fatigue = 50;

    // 個別方針(attack)が休養より疲労を増やす方向に働くことを確認する。
    final fatigueBefore = target.fatigue;
    TrainingEngine.applyWeeklyTraining(team);
    expect(target.fatigue, greaterThanOrEqualTo(fatigueBefore));
  });

  test('MatchEngine.simulate runs without error under extreme tactic settings',
      () {
    final aggressive = PlayerGenerator.generateSquad(
        id: 'agg', name: 'Aggressive FC', strengthTier: 60);
    final defensive = PlayerGenerator.generateSquad(
        id: 'def', name: 'Defensive FC', strengthTier: 60);
    aggressive.lineHeight = 100;
    aggressive.pressing = 100;
    defensive.lineHeight = 0;
    defensive.pressing = 0;
    LineupUtils.autoFill(aggressive);
    LineupUtils.autoFill(defensive);

    final result =
        MatchEngine.simulate(home: aggressive, away: defensive, matchday: 1);

    expect(result.homeGoals, greaterThanOrEqualTo(0));
    expect(result.awayGoals, greaterThanOrEqualTo(0));
  });

  test('MatchEngine.lineupOf excludes suspended players from the starting XI',
      () {
    final team = PlayerGenerator.generateSquad(
        id: 'susp', name: 'Suspend FC', strengthTier: 60);
    LineupUtils.autoFill(team);
    final suspended =
        team.players.firstWhere((p) => team.startingXI.contains(p.id));
    suspended.suspendedMatches = 1;

    final lineup = MatchEngine.lineupOf(team);

    expect(lineup.any((p) => p.id == suspended.id), isFalse);
  });

  test(
      'MatchEngine.applyPostMatchEffects only counts down suspensions for '
      'players who actually sat the match out', () {
    final home = PlayerGenerator.generateSquad(
        id: 'home', name: 'Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'away', name: 'Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    // 出場停止中でスタメン対象外の選手(前節までに受けた出場停止): 今節を
    // 消化したので1減るはず。
    final benched =
        home.players.firstWhere((p) => !home.startingXI.contains(p.id));
    benched.suspendedMatches = 2;
    // 今節に退場処分を受けるスタメン選手: 今節はまだ出場するので、退場の
    // 出場停止は今節では消化されず、次節から適用されるはず(据え置きで1)。
    final justSentOff =
        home.players.firstWhere((p) => home.startingXI.contains(p.id));

    MatchEngine.applyPostMatchEffects(
      home: home,
      away: away,
      events: [
        MatchEvent(
          minute: 10,
          teamId: home.id,
          scorerName: justSentOff.name,
          scorerId: justSentOff.id,
          type: MatchEventType.redCard,
        ),
      ],
    );

    expect(benched.suspendedMatches, 1);
    expect(justSentOff.suspendedMatches, 1);
  });

  test(
      'MatchEngine.applyPostMatchEffects suspends a player once yellow cards '
      'reach the threshold, and resets the counter', () {
    final home = PlayerGenerator.generateSquad(
        id: 'home2', name: 'Home FC 2', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'away2', name: 'Away FC 2', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    final player =
        home.players.firstWhere((p) => home.startingXI.contains(p.id));
    player.yellowCards = yellowCardSuspensionThreshold - 1;

    MatchEngine.applyPostMatchEffects(
      home: home,
      away: away,
      events: [
        MatchEvent(
          minute: 20,
          teamId: home.id,
          scorerName: player.name,
          scorerId: player.id,
          type: MatchEventType.yellowCard,
        ),
      ],
    );

    expect(player.yellowCards, 0);
    expect(player.suspendedMatches, 1);
  });

  test(
      'MatchEngine.computePlayerRatings rewards goals and penalizes red '
      'cards, and MatchResult.manOfTheMatchId picks the top scorer', () {
    final home = PlayerGenerator.generateSquad(
        id: 'home3', name: 'Home FC 3', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'away3', name: 'Away FC 3', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    final scorer =
        home.players.firstWhere((p) => home.startingXI.contains(p.id));
    final cardedAwayPlayer =
        away.players.firstWhere((p) => away.startingXI.contains(p.id));

    final events = [
      MatchEvent(
          minute: 10,
          teamId: home.id,
          scorerName: scorer.name,
          scorerId: scorer.id),
      MatchEvent(
        minute: 30,
        teamId: away.id,
        scorerName: cardedAwayPlayer.name,
        scorerId: cardedAwayPlayer.id,
        type: MatchEventType.redCard,
      ),
    ];

    final ratings = MatchEngine.computePlayerRatings(
      home: home,
      away: away,
      events: events,
      homeGoals: 1,
      awayGoals: 0,
    );

    expect(ratings[scorer.id], greaterThan(6.0));
    expect(ratings[cardedAwayPlayer.id], lessThan(6.0));

    final result = MatchResult(
      matchday: 1,
      homeTeamId: home.id,
      awayTeamId: away.id,
      homeGoals: 1,
      awayGoals: 0,
      events: events,
      playerRatings: ratings,
    );
    expect(result.manOfTheMatchId, scorer.id);
  });

  test(
      'MatchEngine.applyPostMatchEffects tallies career appearances and '
      'goals for the players who took part', () {
    final home = PlayerGenerator.generateSquad(
        id: 'home4', name: 'Home FC 4', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'away4', name: 'Away FC 4', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    final scorer =
        home.players.firstWhere((p) => home.startingXI.contains(p.id));
    final benched =
        home.players.firstWhere((p) => !home.startingXI.contains(p.id));

    MatchEngine.applyPostMatchEffects(
      home: home,
      away: away,
      events: [
        MatchEvent(
            minute: 5,
            teamId: home.id,
            scorerName: scorer.name,
            scorerId: scorer.id),
      ],
    );

    expect(scorer.careerAppearances, 1);
    expect(scorer.careerGoals, 1);
    expect(benched.careerAppearances, 0);
  });

  test('RetirementEngine.retirementChance is zero below 32 and rises with age',
      () {
    final young = PlayerGenerator.generate(
        position: Position.st, strengthTier: 60, ageOverride: 25);
    final veteran = PlayerGenerator.generate(
        position: Position.st, strengthTier: 60, ageOverride: 37);

    expect(RetirementEngine.retirementChance(young), 0.0);
    expect(RetirementEngine.retirementChance(veteran), greaterThan(0.0));
  });

  test('RetirementEngine.resolveRetirements removes retirees from the squad',
      () {
    final team = PlayerGenerator.generateSquad(
        id: 'ret', name: 'Retire FC', strengthTier: 60);
    LineupUtils.autoFill(team);
    // 90%の確率で引退する年齢に全員を揃え、23人独立試行でほぼ確実に
    // 1人以上引退する状況を作る(単独選手の抽選に依存しない安定したテストにする)。
    for (final p in team.players) {
      p.age = 45;
    }

    final retirees = RetirementEngine.resolveRetirements(team);

    expect(retirees, isNotEmpty);
    for (final r in retirees) {
      expect(team.players.contains(r), isFalse);
      expect(team.startingXI.contains(r.id), isFalse);
    }
  });

  test('GameState.scoutProspect deducts budget and adds a youth prospect',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.budget = ScoutingEngine.scoutCost;
    final candidateId = gameState.scoutCandidates.first.id;
    final poolSizeBefore = gameState.scoutCandidates.length;

    final ok = await gameState.scoutProspect(candidateId);

    expect(ok, isTrue);
    expect(gameState.save!.youthProspects.length, 1);
    expect(gameState.save!.youthProspects.first.id, candidateId);
    expect(gameState.save!.budget, 0);
    // 選んだ候補は補充され、閲覧できる候補数は変わらない。
    expect(gameState.scoutCandidates.length, poolSizeBefore);
    expect(gameState.scoutCandidates.any((p) => p.id == candidateId), isFalse);
  });

  test(
      'GameState.scoutCandidates offers more candidates as scout staff level rises',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final baseCount = gameState.scoutCandidates.length;
    gameState.save!.budget = 100000;

    await gameState.upgradeStaff(StaffRole.scout);

    expect(gameState.scoutCandidateCount, baseCount + 1);
  });

  test('GameState.promoteYouthProspect moves the prospect into the squad',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.budget = ScoutingEngine.scoutCost;
    final candidateId = gameState.scoutCandidates.first.id;
    await gameState.scoutProspect(candidateId);
    final prospect = gameState.save!.youthProspects.first;
    final beforeCount = gameState.userTeam.players.length;

    final ok = await gameState.promoteYouthProspect(prospect.id);

    expect(ok, isTrue);
    expect(gameState.save!.youthProspects, isEmpty);
    expect(gameState.userTeam.players.length, beforeCount + 1);
  });

  test('PlayerGenerator populates all 42 detailed attributes within range', () {
    final p = PlayerGenerator.generate(position: Position.mc, strengthTier: 60);
    expect(p.attributes.keys.toSet(), AttributeKeys.all.toSet());
    for (final key in AttributeKeys.all) {
      expect(p.attributeValue(key), inInclusiveRange(1, 99));
    }
  });

  test(
      'PlayerGenerator.generate never assigns an attribute value above the '
      "player's own potential", () {
    for (final position in Position.values) {
      for (int i = 0; i < 100; i++) {
        final p = PlayerGenerator.generate(
            position: position, strengthTier: 60 + Random().nextInt(35));
        for (final key in AttributeKeys.all) {
          expect(p.attributeValue(key), lessThanOrEqualTo(p.potential));
        }
      }
    }
  });

  test('Goalkeepers have much higher goalkeeping attributes than forwards', () {
    final gk =
        PlayerGenerator.generate(position: Position.gk, strengthTier: 60);
    final fw =
        PlayerGenerator.generate(position: Position.st, strengthTier: 60);
    expect(gk.attributeValue(AttributeKeys.handling),
        greaterThan(fw.attributeValue(AttributeKeys.handling)));
    expect(gk.attributeValue(AttributeKeys.reflexes),
        greaterThan(fw.attributeValue(AttributeKeys.reflexes)));
  });

  test('Player.overall is the average of the four composite ratings', () {
    final p = PlayerGenerator.generate(position: Position.mc, strengthTier: 60);
    final expected =
        ((p.attack + p.defense + p.technique + p.stamina) / 4).round();
    expect(p.overall, expected);
  });

  test('Player.fromJson migrates a legacy save without an attributes map', () {
    final legacyJson = {
      'id': 'legacy1',
      'name': 'Legacy Player',
      'age': 25,
      'position': 'mf',
      'attack': 70,
      'defense': 60,
      'technique': 65,
      'stamina': 55,
      'potential': 75,
    };
    final p = Player.fromJson(legacyJson);
    expect(p.attributeValue(AttributeKeys.finishing), 70);
    expect(p.attributeValue(AttributeKeys.tackling), 60);
    expect(p.attributeValue(AttributeKeys.passing), 65);
    expect(p.attributeValue(AttributeKeys.stamina), 55);
  });

  test(
      'Player.fromJson still reads the old key-named attributes map '
      '(pre-compaction saves), and toJson now writes the compact '
      'value-array format', () {
    final legacyMapJson = {
      'id': 'legacymap1',
      'name': 'Legacy Map Player',
      'age': 25,
      'position': 'mc',
      'attributes': {
        for (final k in AttributeKeys.all) k: 50,
      }
        ..[AttributeKeys.passing] = 77
        ..[AttributeKeys.vision] = 66,
      'potential': 80,
    };
    final p = Player.fromJson(legacyMapJson);
    expect(p.attributeValue(AttributeKeys.passing), 77);
    expect(p.attributeValue(AttributeKeys.vision), 66);
    expect(p.attributeValue(AttributeKeys.finishing), 50);

    final roundTripped = Player.fromJson(p.toJson());
    expect(p.toJson()['attributes'], isA<List>());
    expect(roundTripped.attributeValue(AttributeKeys.passing), 77);
    expect(roundTripped.attributeValue(AttributeKeys.vision), 66);
  });

  test('parsePosition migrates legacy df/mf/fw position names', () {
    expect(parsePosition('df'), Position.dc);
    expect(parsePosition('mf'), Position.mc);
    expect(parsePosition('fw'), Position.st);
    expect(parsePosition('gk'), Position.gk);
    expect(parsePosition('amc'), Position.amc);
  });

  test('Formation.f442 has 11 slots matching its label composition', () {
    final slots = Formation.f442.slots;
    expect(slots.length, 11);
    expect(slots.where((p) => p == Position.gk).length, 1);
    expect(slots.where((p) => p == Position.st).length, 2);
    expect(slots.where((p) => p.group == PositionGroup.def).length, 4);
    expect(slots.where((p) => p.group == PositionGroup.mid).length, 4);
  });

  test(
      'Every Formation has 11 slots and a matching FormationLayout coordinate entry',
      () {
    for (final formation in Formation.values) {
      final slots = formation.slots;
      expect(slots.length, 11,
          reason: '${formation.name} should have exactly 11 slots');
      final offsets = FormationLayout.offsetsFor(formation);
      expect(offsets.length, slots.length,
          reason:
              '${formation.name} layout coordinates must match its slot count');
    }
  });

  test(
      'Formation.f4141 and f343 add distinct shapes not covered by the original four',
      () {
    expect(Formation.f4141.slots.where((p) => p == Position.dm).length, 1);
    expect(
        Formation.f4141.slots.where((p) => p.group == PositionGroup.def).length,
        4);
    expect(Formation.f343.slots.where((p) => p == Position.dc).length, 3);
    expect(Formation.f343.slots.where((p) => p == Position.st).length, 1);
  });

  test(
      'Formation.f541 and f424 sit at opposite ends of the attack/defense '
      'spectrum, and every formation has exactly 11 slots with a layout '
      'offset for each', () {
    expect(Formation.f541.slots.length, 11);
    expect(
        Formation.f541.slots.where((p) => p.group == PositionGroup.def).length,
        5);
    expect(Formation.f424.slots.length, 11);
    expect(Formation.f424.slots.where((p) => p == Position.st).length, 2);
    expect(Formation.f541.defenseBias, greaterThan(Formation.f424.defenseBias));
    expect(Formation.f424.attackBias, greaterThan(Formation.f541.attackBias));

    for (final f in Formation.values) {
      expect(f.slots.length, 11, reason: '${f.name} should have 11 slots');
      expect(FormationLayout.offsetsFor(f).length, 11,
          reason: '${f.name} should have a layout offset per slot');
    }
  });

  test('Team.fromJson falls back to f442 for a removed formation name', () {
    final team = PlayerGenerator.generateSquad(
        id: 'tf', name: 'Test FC', strengthTier: 60);
    final json = team.toJson();
    json['formation'] = 'f532'; // 廃止された旧フォーメーション名
    final restored = Team.fromJson(json);
    expect(restored.formation, Formation.f442);
  });

  test('GameState.renewContract deducts cost and resets contract length',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    player.contractYearsRemaining = 1;
    final cost = gameState.renewalCostFor(player.id) +
        gameState.signingBonusFor(player.id);
    gameState.save!.budget = cost;

    final ok = await gameState.renewContract(player.id);

    expect(ok, isTrue);
    expect(
        player.contractYearsRemaining, ContractEngine.negotiatedYears(player));
    expect(gameState.save!.budget, 0);
  });

  test('ClubInfrastructure upgrades increase level and cost more each time',
      () {
    final infra = ClubInfrastructure();
    expect(infra.staffLevel(StaffRole.physio), 1);
    final firstCost =
        ClubInfrastructure.staffUpgradeCost(infra.staffLevel(StaffRole.physio));

    final upgraded = infra.upgradeStaff(StaffRole.physio);

    expect(upgraded, isTrue);
    expect(infra.staffLevel(StaffRole.physio), 2);
    final secondCost =
        ClubInfrastructure.staffUpgradeCost(infra.staffLevel(StaffRole.physio));
    expect(secondCost, greaterThan(firstCost));
  });

  test('ClubInfrastructure staff cannot upgrade past max level', () {
    final infra = ClubInfrastructure();
    for (int i = 0; i < ClubInfrastructure.maxLevel - 1; i++) {
      expect(infra.upgradeStaff(StaffRole.scout), isTrue);
    }
    expect(infra.staffLevel(StaffRole.scout), ClubInfrastructure.maxLevel);
    expect(infra.upgradeStaff(StaffRole.scout), isFalse);
  });

  test('GameState.upgradeFacility deducts budget and raises the level',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final cost = gameState.facilityUpgradeCostFor(FacilityType.stadium);
    gameState.save!.budget = cost;

    final ok = await gameState.upgradeFacility(FacilityType.stadium);

    expect(ok, isTrue);
    expect(
        gameState.save!.infrastructure.facilityLevel(FacilityType.stadium), 2);
    expect(gameState.save!.budget, 0);
  });

  test(
      'GameState.weeklyIncomeFor rises with the commercial facility level, '
      'boosting both matchday and sponsor income', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.sponsorDeal =
        SponsorDeal(name: 'Sponsor', weeklyIncome: 200, yearsRemaining: 2);
    final incomeAtLevel1 = gameState.weeklyIncomeFor(gameState.userTeam.id);

    gameState.save!.infrastructure
            .facilityLevels[FacilityType.commercialFacility] =
        ClubInfrastructure.maxLevel;

    expect(gameState.weeklyIncomeFor(gameState.userTeam.id),
        greaterThan(incomeAtLevel1));
  });

  test('GameState.upgradeStaff fails when budget is insufficient', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.budget = 0;

    final ok = await gameState.upgradeStaff(StaffRole.headCoach);

    expect(ok, isFalse);
    expect(gameState.save!.infrastructure.staffLevel(StaffRole.headCoach), 1);
  });

  test(
      'CupEngine.createKnockout builds a full bracket for a power-of-two field with no byes',
      () {
    final teamIds = List.generate(8, (i) => 't$i');
    final cup = CupEngine.createKnockout(
        type: CupType.domestic, name: '国内カップ', teamIds: teamIds);

    expect(cup.rounds.length, 1);
    expect(cup.rounds.first.length, 4);
    expect(cup.rounds.first.every((m) => !m.isBye), isTrue);
  });

  test(
      'CupEngine.playNextMatch advances rounds until a single champion remains',
      () {
    final teams = List.generate(
        8,
        (i) => PlayerGenerator.generateSquad(
            id: 't$i', name: 'Club $i', strengthTier: 60));
    for (final t in teams) {
      LineupUtils.autoFill(t);
    }
    final cup = CupEngine.createKnockout(
      type: CupType.domestic,
      name: '国内カップ',
      teamIds: teams.map((t) => t.id).toList(),
    );

    // 8チーム(準々決勝4+準決勝2+決勝1=7試合)を全て消化する。
    for (int i = 0; i < 7; i++) {
      final result = CupEngine.playNextMatch(cup, teams);
      expect(result, isNotNull);
    }

    expect(cup.isComplete, isTrue);
    expect(cup.championId, isNotNull);
    expect(cup.rounds.length, 3);
    expect(CupEngine.playNextMatch(cup, teams), isNull);
  });

  test(
      'GameState creates a domestic cup on new game that can be played to completion',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    expect(gameState.domesticCup, isNotNull);
    expect(gameState.continentalCup, isNull);

    // カップ戦は現実の試合間隔を再現するため、直前の消化からリーグが1節
    // 進むまで次の試合を消化できない。そのため毎回リーグも1節進める。
    int guard = 0;
    do {
      await gameState.playNextCupMatch();
      await gameState.playNextMatchdayQuickSim();
      guard++;
    } while (gameState.domesticCup!.nextUnplayedMatch != null && guard < 60);

    expect(gameState.domesticCup!.isComplete, isTrue);
  });

  test(
      'GameState.isUserDomesticCupMatchUpNext is true exactly when the '
      'bracket\'s next unplayed match involves the user\'s club', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final userId = gameState.userTeam.id;

    int guard = 0;
    while (gameState.domesticCup!.nextUnplayedMatch != null && guard < 60) {
      final next = gameState.domesticCup!.nextUnplayedMatch!;
      final expected = next.homeTeamId == userId || next.awayTeamId == userId;
      expect(gameState.isUserDomesticCupMatchUpNext, expected);
      await gameState.playNextCupMatch();
      // カップ戦は現実の試合間隔を再現するため、直前の消化からリーグが
      // 1節進むまで次の試合を消化できない。そのため毎回リーグも1節進める。
      await gameState.playNextMatchdayQuickSim();
      guard++;
    }

    expect(gameState.isUserDomesticCupMatchUpNext, isFalse);
  });

  test(
      'GameState.startNewGame names the domestic cup after the chosen '
      'league theme', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC', theme: LeagueTheme.spain);

    expect(gameState.domesticCup!.name, LeagueTheme.spain.domesticCupName);
  });

  test(
      'ContinentalCupEngine.create splits teams into 4-team groups with a '
      'full round robin', () {
    final ids = List.generate(8, (i) => 't$i');
    final cup = ContinentalCupEngine.create(name: '大陸カップ', teamIds: ids);

    expect(cup.groups.length, 2);
    expect(cup.groups.expand((g) => g).toSet(), ids.toSet());
    expect(cup.groupMatches.length, 12);
    for (final group in cup.groups) {
      for (final id in group) {
        final played = cup.groupMatches
            .where((m) => m.homeTeamId == id || m.awayTeamId == id)
            .length;
        expect(played, 3);
      }
    }
  });

  test(
      'ContinentalCupEngine plays from the group stage through to a champion, '
      'swapping home/away for the second knockout leg', () {
    final teams = List.generate(
        8,
        (i) => PlayerGenerator.generateSquad(
            id: 'c$i', name: 'Club $i', strengthTier: 60));
    for (final t in teams) {
      LineupUtils.autoFill(t);
    }
    final cup = ContinentalCupEngine.create(
        name: '大陸カップ', teamIds: teams.map((t) => t.id).toList());

    int guard = 0;
    while (!cup.isGroupStageComplete && guard < 50) {
      ContinentalCupEngine.playNextGroupMatch(cup, teams);
      guard++;
    }
    expect(cup.isGroupStageComplete, isTrue);
    expect(cup.knockoutRounds.length, 1);
    expect(cup.knockoutRounds.first.length, 2);

    // 準決勝は同組同士が当たらないよう、他組の2位とクロスで組まれる。
    for (final tie in cup.knockoutRounds.first) {
      final groupOfA = cup.groups.indexWhere((g) => g.contains(tie.teamAId));
      final groupOfB = cup.groups.indexWhere((g) => g.contains(tie.teamBId));
      expect(groupOfA, isNot(groupOfB));
    }

    guard = 0;
    while (!cup.isComplete && guard < 50) {
      ContinentalCupEngine.playNextKnockoutLeg(cup, teams);
      guard++;
    }

    expect(cup.isComplete, isTrue);
    expect(cup.championId, isNotNull);
    expect(cup.knockoutRounds.length, 2);
    final finalTie = cup.knockoutRounds.last.first;
    expect(finalTie.singleLeg, isTrue);
    expect(finalTie.legs.length, 1);

    final semi = cup.knockoutRounds.first.first;
    expect(semi.legs.length, 2);
    expect(semi.legs[0].homeTeamId, semi.teamAId);
    expect(semi.legs[1].homeTeamId, semi.teamBId);
  });

  test(
      "GameState.startNextSeason creates a continental cup with two 4-team "
      "groups when the user finishes in the league's top two", () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    // 大陸カップは1部限定のため、1部でプレー中という前提に切り替える
    // (5部の枠は元々nullなので、1部の枠にあった実データを5部の枠へ移し、
    // 1部の枠をnull化して整合を取る)。
    final vacatedTier1League = gameState.save!.otherDivisionLeagues[0];
    gameState.save!.otherDivisionLeagues[0] = null;
    gameState.save!.otherDivisionLeagues[4] = vacatedTier1League;
    gameState.save!.currentDivisionTier = 1;
    final userId = gameState.userTeam.id;
    for (final f in gameState.save!.league.fixtures) {
      final userIsHome = f.homeTeamId == userId;
      final userIsAway = f.awayTeamId == userId;
      f.result = MatchResult(
        matchday: f.matchday,
        homeTeamId: f.homeTeamId,
        awayTeamId: f.awayTeamId,
        homeGoals: userIsHome ? 3 : (userIsAway ? 0 : 1),
        awayGoals: userIsHome ? 0 : (userIsAway ? 3 : 1),
        events: [],
      );
    }

    await gameState.startNextSeason();

    expect(gameState.continentalCup, isNotNull);
    final cup = gameState.continentalCup!;
    expect(cup.groups.length, 2);
    expect(cup.groups.expand((g) => g), contains(userId));
  });

  test(
      'HappinessEngine boosts happiness for starters and penalizes benched players',
      () {
    final team = PlayerGenerator.generateSquad(
        id: 'hteam', name: 'Happy FC', strengthTier: 60);
    LineupUtils.autoFill(team);
    for (final p in team.players) {
      p.happiness = 50;
      p.personality = PlayerPersonality.balanced;
    }
    final starter =
        team.players.firstWhere((p) => team.startingXI.contains(p.id));
    final benched =
        team.players.firstWhere((p) => !team.startingXI.contains(p.id));
    // 待遇要因を打ち消して出場機会の影響だけを検証できるようにする。
    starter.wage = 99999;
    benched.wage = 1;

    HappinessEngine.applyWeekly(team, leagueRank: 1, boardTargetRank: 4);

    expect(starter.happiness, greaterThan(50));
    expect(benched.happiness, lessThan(50));
  });

  test(
      'HappinessEngine.reassure raises happiness but not above the threshold gate',
      () {
    final p = PlayerGenerator.generate(position: Position.st, strengthTier: 60);
    p.happiness = 20;

    final ok = HappinessEngine.reassure(p);

    expect(ok, isTrue);
    expect(p.happiness, 40);
  });

  test('HappinessEngine.reassure fails once happiness is already high', () {
    final p = PlayerGenerator.generate(position: Position.st, strengthTier: 60);
    p.happiness = 80;

    final ok = HappinessEngine.reassure(p);

    expect(ok, isFalse);
    expect(p.happiness, 80);
  });

  test('Player.wantsTransfer reflects personality-specific thresholds', () {
    final p = PlayerGenerator.generate(position: Position.st, strengthTier: 60);
    p.personality = PlayerPersonality.ambitious; // 閾値30

    p.happiness = 35;
    expect(p.wantsTransfer, isFalse);

    p.happiness = 29;
    expect(p.wantsTransfer, isTrue);
  });

  test('SponsorEngine.generateOffers trades higher income for shorter duration',
      () {
    final offers = SponsorEngine.generateOffers(70);
    expect(offers.length, 3);
    final sorted = [...offers]
      ..sort((a, b) => a.weeklyIncome.compareTo(b.weeklyIncome));
    expect(
        sorted.first.yearsRemaining, greaterThan(sorted.last.yearsRemaining));
  });

  test('GameState.chooseSponsor applies the selected deal and clears offers',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    expect(gameState.pendingSponsorOffers, isNotEmpty);

    final ok = await gameState.chooseSponsor(0);

    expect(ok, isTrue);
    expect(gameState.save!.sponsorDeal, isNotNull);
    expect(gameState.pendingSponsorOffers, isEmpty);
  });

  test(
      'GameState.signLoanPlayer adds a loan player that returns after loanDurationWeeks',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.transferMarket.first;
    gameState.save!.budget = target.marketValue; // ローン料は移籍金の一部で足りるはず

    final ok = await gameState.signLoanPlayer(target.id);

    expect(ok, isTrue);
    final signed =
        gameState.userTeam.players.firstWhere((p) => p.id == target.id);
    expect(signed.isLoan, isTrue);
    expect(signed.loanWeeksRemaining, GameState.loanDurationWeeks);
  });

  test(
      'GameState.signLoanPlayer with a buy option lets exerciseLoanBuyOption '
      'convert the loan into a permanent signing', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.transferMarket.first;
    final expectedFee =
        (target.marketValue * GameState.loanBuyOptionRatio).round();
    gameState.save!.budget = target.marketValue + expectedFee;

    final signed =
        await gameState.signLoanPlayer(target.id, withBuyOption: true);
    expect(signed, isTrue);
    final player =
        gameState.userTeam.players.firstWhere((p) => p.id == target.id);
    expect(player.loanBuyOptionFee, expectedFee);
    final budgetBeforeBuyout = gameState.save!.budget;

    final bought = await gameState.exerciseLoanBuyOption(target.id);

    expect(bought, isTrue);
    expect(player.isLoan, isFalse);
    expect(player.loanWeeksRemaining, 0);
    expect(player.loanBuyOptionFee, isNull);
    expect(gameState.save!.budget, budgetBeforeBuyout - expectedFee);
  });

  test(
      'GameState.exerciseLoanBuyOption fails for a plain loan without a buy option',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.transferMarket.first;
    gameState.save!.budget = target.marketValue;
    await gameState.signLoanPlayer(target.id);
    gameState.save!.budget = 999999;

    final bought = await gameState.exerciseLoanBuyOption(target.id);

    expect(bought, isFalse);
  });

  test('Weather multipliers reflect worsening conditions for bad weather', () {
    expect(Weather.clear.attackMultiplier, 1.0);
    expect(Weather.clear.defenseMultiplier, 1.0);
    expect(Weather.clear.chanceCountMultiplier, 1.0);
    expect(Weather.clear.fatigueMultiplier, 1.0);

    for (final bad in [
      Weather.rain,
      Weather.wind,
      Weather.heatwave,
      Weather.snow,
    ]) {
      expect(bad.attackMultiplier, lessThan(1.0));
    }
    expect(Weather.heatwave.fatigueMultiplier, greaterThan(1.0));
    expect(Weather.snow.chanceCountMultiplier,
        lessThan(Weather.rain.chanceCountMultiplier));
  });

  test('WeatherEngine.roll eventually produces every weather type', () {
    final seen = <Weather>{};
    for (int i = 0; i < 2000 && seen.length < Weather.values.length; i++) {
      seen.add(WeatherEngine.roll());
    }
    expect(seen, containsAll(Weather.values));
  });

  test('MatchEngine.simulate records the requested weather on the result', () {
    final home = PlayerGenerator.generateSquad(
        id: 'wh', name: 'Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'wa', name: 'Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    final result = MatchEngine.simulate(
        home: home, away: away, matchday: 1, weather: Weather.snow);

    expect(result.weather, Weather.snow);
  });

  test('Fixture and MatchResult round-trip their weather through JSON', () {
    final fixture = Fixture(
      matchday: 3,
      homeTeamId: 'h',
      awayTeamId: 'a',
      weather: Weather.wind,
      result: MatchResult(
        matchday: 3,
        homeTeamId: 'h',
        awayTeamId: 'a',
        homeGoals: 1,
        awayGoals: 1,
        events: [],
        weather: Weather.wind,
      ),
    );

    final restored = Fixture.fromJson(fixture.toJson());

    expect(restored.weather, Weather.wind);
    expect(restored.result!.weather, Weather.wind);
  });

  test(
      'GameState.playNextMatchday assigns a weather to the fixture that carries through to playSecondHalf',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    await gameState.playNextMatchday();
    final fixture = gameState.liveFixture;
    expect(fixture, isNotNull);
    expect(fixture!.weather, isNotNull);

    if (gameState.isHalfTime) {
      final result = await gameState.playSecondHalf();
      expect(result!.weather, fixture.weather);
    }
  });

  test(
      'A designated penalty taker scores more often than a teammate with '
      'equal attack but no set-piece duty', () {
    Player makeOutfield(String id, Position pos, {int penalties = 50}) {
      final attrs = {for (final k in AttributeKeys.all) k: 60};
      attrs[AttributeKeys.penalties] = penalties;
      return Player(
        id: id,
        name: id,
        age: 25,
        position: pos,
        potential: 70,
        attributes: attrs,
      );
    }

    final gk = makeOutfield('gk', Position.gk);
    final defs = [for (int i = 0; i < 4; i++) makeOutfield('d$i', Position.dc)];
    final mids = [for (int i = 0; i < 4; i++) makeOutfield('m$i', Position.mc)];
    final strikerA = makeOutfield('strikerA', Position.st, penalties: 99);
    final strikerB = makeOutfield('strikerB', Position.st, penalties: 1);
    final allPlayers = [gk, ...defs, ...mids, strikerA, strikerB];
    final team = Team(
        id: 'setpiece',
        name: 'Set Piece FC',
        players: allPlayers,
        formation: Formation.f442);
    team.startingXI = allPlayers.map((p) => p.id).toList();
    team.penaltyTakerId = strikerA.id;

    final away = PlayerGenerator.generateSquad(
        id: 'weak', name: 'Weak FC', strengthTier: 10);
    LineupUtils.autoFill(away);

    var strikerAGoals = 0;
    var strikerBGoals = 0;
    for (int i = 0; i < 300; i++) {
      final result = MatchEngine.simulateMinutes(
          home: team, away: away, startMinute: 1, endMinute: 90);
      for (final e in result.events) {
        if (e.type != MatchEventType.goal) continue;
        if (e.scorerId == strikerA.id) strikerAGoals++;
        if (e.scorerId == strikerB.id) strikerBGoals++;
      }
    }

    expect(strikerAGoals, greaterThan(strikerBGoals));
  });

  test(
      'RotationEngine.suggest recommends swapping in a fresher bench player '
      'of the same position', () {
    final team = PlayerGenerator.generateSquad(
        id: 'rot', name: 'Rotation FC', strengthTier: 60);
    LineupUtils.autoFill(team);
    final tired =
        team.players.firstWhere((p) => team.startingXI.contains(p.id));
    tired.fatigue = 90;
    for (final p
        in team.players.where((p) => !team.startingXI.contains(p.id))) {
      p.fatigue = 80;
    }
    final fresh = team.players.firstWhere(
        (p) => !team.startingXI.contains(p.id) && p.canPlay(tired.position));
    fresh.fatigue = 10;

    final suggestions = RotationEngine.suggest(team);
    final match = suggestions.where((s) => s.tiredPlayerId == tired.id);

    expect(match, isNotEmpty);
    expect(match.first.replacementId, fresh.id);
  });

  test('RotationEngine.suggest ignores starters below the fatigue threshold',
      () {
    final team = PlayerGenerator.generateSquad(
        id: 'rot2', name: 'Rested FC', strengthTier: 60);
    LineupUtils.autoFill(team);
    for (final p in team.players) {
      p.fatigue = 10;
    }

    final suggestions = RotationEngine.suggest(team);

    expect(suggestions, isEmpty);
  });

  test(
      'GameState.buyPlayerOnInstallments splits the remaining cost into weekly payments',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.transferMarket.first;
    gameState.save!.budget = target.marketValue; // 頭金分は十分ある

    final ok = await gameState.buyPlayerOnInstallments(target.id);

    expect(ok, isTrue);
    expect(gameState.save!.pendingInstallments.length, 1);
    expect(gameState.userTeam.players.any((p) => p.id == target.id), isTrue);
  });

  test(
      'ContractEngine.advanceLoanWeek removes a loan player once loanWeeksRemaining reaches 0',
      () {
    final team = PlayerGenerator.generateSquad(
        id: 'lteam', name: 'Loan FC', strengthTier: 60);
    final loanPlayer = team.players.first;
    loanPlayer.isLoan = true;
    loanPlayer.loanWeeksRemaining = 1;

    final expired = ContractEngine.advanceLoanWeek(team);

    expect(expired.any((p) => p.id == loanPlayer.id), isTrue);
    expect(team.players.any((p) => p.id == loanPlayer.id), isFalse);
  });

  test(
      'NamePool.themedClubNames generates enough unique names for a full league',
      () {
    for (final theme in LeagueTheme.values) {
      final names = NamePool.themedClubNames(theme, teamsPerLeague - 1);
      expect(names.toSet().length, teamsPerLeague - 1);
    }
  });

  test(
      'CupEngine.createKnockout never leaves a bye-vs-bye match unresolved for a non-power-of-two field',
      () {
    // 20チーム(2の累乗ではない)は32枠に切り上げられ、12個のBYEが生じる。
    final teamIds = List.generate(teamsPerLeague, (i) => 't$i');
    final teams = teamIds
        .map((id) =>
            PlayerGenerator.generateSquad(id: id, name: id, strengthTier: 60))
        .toList();
    for (final t in teams) {
      LineupUtils.autoFill(t);
    }
    final cup = CupEngine.createKnockout(
        type: CupType.domestic, name: '国内カップ', teamIds: teamIds);

    // 全てのBYEを含む試合が単独で解決済み(勝者が決まっている)ことを確認する。
    for (final m in cup.rounds.first) {
      if (m.isBye) {
        expect(m.winnerId, isNotNull);
      }
    }

    // 決勝まで全試合を消化できる(BYE同士の対戦で永久に止まらない)ことを確認する。
    var guard = 0;
    while (cup.nextUnplayedMatch != null && guard < 100) {
      CupEngine.playNextMatch(cup, teams);
      guard++;
    }
    expect(cup.isComplete, isTrue);
    expect(cup.championId, isNotNull);
  });

  test(
      'GameState.startNewGame creates a full-size league with the selected theme name',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC', theme: LeagueTheme.spain);

    expect(gameState.save!.league.teams.length, teamsPerLeague);
    expect(gameState.save!.leagueName, LeagueTheme.spain.label);
  });

  test(
      'GameState.startNewGame succeeds and clears lastSaveError when persistence works normally',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    expect(gameState.save, isNotNull);
    expect(gameState.lastSaveError, isNull);
  });

  test(
      'MatchEngine.simulateMinutes only generates events within the requested minute range',
      () {
    final home = PlayerGenerator.generateSquad(
        id: 'h', name: 'Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'a', name: 'Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    final half = MatchEngine.simulateMinutes(
        home: home, away: away, startMinute: 46, endMinute: 90);

    expect(half.events.every((e) => e.minute >= 46 && e.minute <= 90), isTrue);
  });

  test(
      'MatchEngine.beginInteractiveHalf only pauses for the interactive '
      "team's open-play chances, and auto-resolving every pending "
      'decision with shoot always reaches isFinished', () {
    final home = PlayerGenerator.generateSquad(
        id: 'ih', name: 'Interactive Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'ia', name: 'Interactive Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);
    final homeIds = MatchEngine.lineupOf(home).map((p) => p.id).toSet();

    var pendingCount = 0;
    for (int i = 0; i < 40; i++) {
      final state = MatchEngine.beginInteractiveHalf(
        home: home,
        away: away,
        startMinute: 1,
        endMinute: 45,
        interactiveTeamId: home.id,
      );
      while (!state.isFinished) {
        final pending = state.pending!;
        if (pending.context == ChanceContext.attack) {
          expect(homeIds.contains(pending.shooter!.id), isTrue);
        }
        pendingCount++;
        MatchEngine.resolvePendingChance(state, ChanceDecision.shoot);
      }
      expect(state.isFinished, isTrue);
    }
    expect(pendingCount, greaterThan(0));
  });

  test(
      'MatchEngine.resolvePendingChance with pass redirects scoring credit '
      'to the passTarget and makes the original shooter the assist '
      'provider on a goal', () {
    final home = PlayerGenerator.generateSquad(
        id: 'ph', name: 'Pass Home FC', strengthTier: 85);
    final away = PlayerGenerator.generateSquad(
        id: 'pa', name: 'Pass Away FC', strengthTier: 15);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    MatchEvent? passGoal;
    Player? shooterAtDecision;
    Player? passTargetAtDecision;
    for (int i = 0; i < 4000 && passGoal == null; i++) {
      final state = MatchEngine.beginInteractiveHalf(
        home: home,
        away: away,
        startMinute: 1,
        endMinute: 45,
        interactiveTeamId: home.id,
      );
      while (!state.isFinished) {
        final pending = state.pending!;
        if (pending.passTarget == null) {
          MatchEngine.resolvePendingChance(state, ChanceDecision.shoot);
          continue;
        }
        final eventsBefore = state.events.length;
        final shooter = pending.shooter;
        final passTarget = pending.passTarget!;
        MatchEngine.resolvePendingChance(state, ChanceDecision.pass);
        if (state.events.length > eventsBefore) {
          final e = state.events[eventsBefore];
          if (e.type == MatchEventType.goal && e.teamId == home.id) {
            passGoal = e;
            shooterAtDecision = shooter;
            passTargetAtDecision = passTarget;
            break;
          }
        }
      }
    }
    expect(passGoal, isNotNull);
    expect(passGoal!.scorerId, passTargetAtDecision!.id);
    expect(passGoal.assistId, shooterAtDecision!.id);
  });

  test(
      'GameState.playNextMatchday(interactive: true) can pause on '
      'pendingChanceDecision, and resolving every decision with shoot '
      'reaches a fully completed match just like the non-interactive path',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    final firstHalf = await gameState.playNextMatchday(interactive: true);
    expect(firstHalf, isNotNull);

    while (gameState.pendingChanceDecision != null) {
      final result =
          await gameState.resolveChanceDecision(ChanceDecision.shoot);
      expect(result.merged, isNull);
    }
    expect(gameState.isHalfTime, isTrue);

    MatchResult? merged = await gameState.playSecondHalf(interactive: true);
    while (merged == null && gameState.pendingChanceDecision != null) {
      merged =
          (await gameState.resolveChanceDecision(ChanceDecision.shoot)).merged;
    }

    expect(merged, isNotNull);
    expect(gameState.isHalfTime, isFalse);
    expect(gameState.liveFixture, isNull);
    expect(gameState.pendingChanceDecision, isNull);
    final mergedResult = merged!;
    final fixture = gameState.save!.league
        .fixturesForMatchday(mergedResult.matchday)
        .firstWhere((f) =>
            f.homeTeamId == mergedResult.homeTeamId &&
            f.awayTeamId == mergedResult.awayTeamId);
    expect(fixture.result, isNotNull);
  });

  test(
      'MatchEngine.resolvePendingChance with longShot uses '
      'pending.longShotChance instead of shootChance, and always advances '
      'past the decision', () {
    final home = PlayerGenerator.generateSquad(
        id: 'lsh', name: 'LongShot Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'lsa', name: 'LongShot Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    var sawAttackChance = false;
    for (int i = 0; i < 40; i++) {
      final state = MatchEngine.beginInteractiveHalf(
        home: home,
        away: away,
        startMinute: 1,
        endMinute: 45,
        interactiveTeamId: home.id,
      );
      while (!state.isFinished) {
        final pending = state.pending!;
        if (pending.context != ChanceContext.attack) {
          MatchEngine.resolvePendingChance(state, ChanceDecision.coverSpace);
          continue;
        }
        expect(pending.longShotChance, isNotNull);
        expect(pending.shootChance, isNotNull);
        sawAttackChance = true;
        MatchEngine.resolvePendingChance(state, ChanceDecision.longShot);
      }
      expect(state.isFinished, isTrue);
    }
    expect(sawAttackChance, isTrue);
  });

  test(
      'MatchEngine.beginInteractiveHalf pauses with a defense decision when '
      "the interactive team is defending, offering a lower success chance "
      'against for aggressiveTackle than coverSpace, and repeatedly '
      'choosing aggressiveTackle eventually produces a card event', () {
    final home = PlayerGenerator.generateSquad(
        id: 'dh', name: 'Defense Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'da', name: 'Defense Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    var sawDefenseChance = false;
    var sawCardEvent = false;
    for (int i = 0; i < 60; i++) {
      final state = MatchEngine.beginInteractiveHalf(
        home: home,
        away: away,
        startMinute: 1,
        endMinute: 45,
        interactiveTeamId: away.id,
      );
      while (!state.isFinished) {
        final pending = state.pending!;
        if (pending.context != ChanceContext.defense) {
          MatchEngine.resolvePendingChance(state, ChanceDecision.shoot);
          continue;
        }
        sawDefenseChance = true;
        expect(pending.aggressiveChanceAgainst, isNotNull);
        expect(pending.safeChanceAgainst, isNotNull);
        expect(
          pending.aggressiveChanceAgainst!,
          lessThan(pending.safeChanceAgainst!),
        );
        final eventsBefore = state.events.length;
        MatchEngine.resolvePendingChance(
            state, ChanceDecision.aggressiveTackle);
        for (int j = eventsBefore; j < state.events.length; j++) {
          final e = state.events[j];
          if (e.type == MatchEventType.yellowCard ||
              e.type == MatchEventType.redCard) {
            sawCardEvent = true;
          }
        }
      }
      expect(state.isFinished, isTrue);
    }
    expect(sawDefenseChance, isTrue);
    expect(sawCardEvent, isTrue);
  });

  test(
      'MatchEngine.applyInteractiveSubstitution swaps in an eligible bench '
      'player mid-half, raises the recomputed defense base when the incoming '
      'defender is far stronger, and rejects injured or decision-involved '
      'players', () {
    InteractiveHalfState? found;
    Team? homeTeam;
    // 稀にハーフ内で自チームの決定機が一度も発生しない(=pendingなしで
    // 即完了する)ことがあるため、pendingを持つ状態が得られるまで再試行。
    for (int attempt = 0; attempt < 30 && found == null; attempt++) {
      final home = PlayerGenerator.generateSquad(
          id: 'sub-h$attempt', name: 'Sub Home FC', strengthTier: 60);
      final away = PlayerGenerator.generateSquad(
          id: 'sub-a$attempt', name: 'Sub Away FC', strengthTier: 60);
      LineupUtils.autoFill(home);
      LineupUtils.autoFill(away);
      final state = MatchEngine.beginInteractiveHalf(
        home: home,
        away: away,
        startMinute: 1,
        endMinute: 45,
        interactiveTeamId: home.id,
      );
      if (state.pending != null) {
        found = state;
        homeTeam = home;
      }
    }
    final state = found!;
    final home = homeTeam!;
    final pending = state.pending!;
    final involved = {
      pending.shooter?.id,
      pending.passTarget?.id,
      pending.keeper?.id,
      pending.attacker?.id,
      pending.defender?.id,
    };

    bool onPitch(Player p) => state.homeLineup.any((l) => l.id == p.id);
    bool eligible(Player p) =>
        !p.isInjured &&
        !p.isSuspended &&
        !p.isOnInternationalDuty &&
        !p.isLoanedOut;

    final incoming = home.players.firstWhere((p) =>
        !onPitch(p) && p.position.group == PositionGroup.def && eligible(p));
    for (final key in AttributeKeys.all) {
      incoming.setAttributeValue(key, 99);
    }
    incoming.trait = null;

    final outDefender = state.homeLineup.firstWhere((p) =>
        p.position.group == PositionGroup.def && !involved.contains(p.id));

    final injuredBench = home.players
        .firstWhere((p) => p.id != incoming.id && !onPitch(p) && eligible(p));
    injuredBench.injuryWeeks = 2;
    expect(
      MatchEngine.applyInteractiveSubstitution(
        state,
        teamId: home.id,
        outPlayerId: outDefender.id,
        inPlayerId: injuredBench.id,
      ),
      isFalse,
      reason: '負傷中のベンチ選手は投入できない',
    );

    final involvedOnPitch =
        state.homeLineup.where((p) => involved.contains(p.id)).toList();
    if (involvedOnPitch.isNotEmpty) {
      expect(
        MatchEngine.applyInteractiveSubstitution(
          state,
          teamId: home.id,
          outPlayerId: involvedOnPitch.first.id,
          inPlayerId: incoming.id,
        ),
        isFalse,
        reason: '目前の決定機に関与している選手は交代できない',
      );
    }

    final before = state.homeDefenseBase;
    expect(
      MatchEngine.applyInteractiveSubstitution(
        state,
        teamId: home.id,
        outPlayerId: outDefender.id,
        inPlayerId: incoming.id,
      ),
      isTrue,
    );
    expect(state.homeLineup.any((p) => p.id == incoming.id), isTrue);
    expect(state.homeLineup.any((p) => p.id == outDefender.id), isFalse);
    expect(state.homeDefenseBase, greaterThan(before),
        reason: '全能力99の守備者投入で守備力が再計算されて上がるはず');
    expect(incoming.matchFormRolledThisMatch, isTrue);

    // 交代後もハーフの進行は通常通り最後まで解決できる。
    while (!state.isFinished) {
      final p2 = state.pending!;
      MatchEngine.resolvePendingChance(
          state,
          p2.context == ChanceContext.attack
              ? ChanceDecision.shoot
              : ChanceDecision.coverSpace);
    }
  });

  test(
      'GameState.makeLiveSubstitution consumes a substitution slot mid-half '
      'and keeps startingXI in sync with the on-pitch lineup', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    for (int matchdayAttempt = 0; matchdayAttempt < 5; matchdayAttempt++) {
      await gameState.playNextMatchday(interactive: true);
      if (gameState.pendingChanceDecision == null) {
        // 稀に前半に自クラブの決定機が発生しないことがあるため、その試合は
        // 消化して次の節で再試行する。
        await gameState.playSecondHalf(interactive: false);
        continue;
      }
      final team = gameState.userTeam;
      final pending = gameState.pendingChanceDecision;
      final involved = {
        pending?.shooter?.id,
        pending?.passTarget?.id,
        pending?.keeper?.id,
        pending?.attacker?.id,
        pending?.defender?.id,
      };
      final outId = team.startingXI.firstWhere((id) => !involved.contains(id));
      final bench = team.players.firstWhere((p) =>
          !team.startingXI.contains(p.id) &&
          !p.isInjured &&
          !p.isSuspended &&
          !p.isOnInternationalDuty &&
          !p.isLoanedOut);
      expect(
        gameState.makeLiveSubstitution(
            outPlayerId: outId, inPlayerId: bench.id),
        isTrue,
      );
      expect(gameState.substitutionsUsed, 1);
      expect(team.startingXI.contains(bench.id), isTrue);
      expect(team.startingXI.contains(outId), isFalse);

      while (gameState.pendingChanceDecision != null) {
        await gameState.resolveChanceDecision(ChanceDecision.shoot);
      }
      return;
    }
    fail('5節試しても前半に自クラブの決定機が発生しなかった');
  });

  test(
      'GameState.resolveChanceDecision returns the produced MatchEvent as '
      'decisionEvent, matching MatchEngine.resolvePendingChance', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    await gameState.playNextMatchday(interactive: true);
    var sawDecisionEvent = false;
    while (gameState.pendingChanceDecision != null) {
      final result =
          await gameState.resolveChanceDecision(ChanceDecision.shoot);
      if (result.decisionEvent != null) {
        sawDecisionEvent = true;
      }
    }
    expect(gameState.isHalfTime, isTrue);

    MatchResult? merged = await gameState.playSecondHalf(interactive: true);
    while (merged == null && gameState.pendingChanceDecision != null) {
      final result =
          await gameState.resolveChanceDecision(ChanceDecision.shoot);
      if (result.decisionEvent != null) {
        sawDecisionEvent = true;
      }
      merged = result.merged;
    }
    expect(merged, isNotNull);
    expect(sawDecisionEvent, isTrue);
  });

  test(
      'MatchEngine.setInstruction(aggressive) raises the average attacking '
      'success chance offered in PendingChanceDecision.attack compared to '
      'cautious, across many interactive halves', () {
    final home = PlayerGenerator.generateSquad(
        id: 'insh', name: 'Instruction Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'insa', name: 'Instruction Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    double averageShootChanceFor(MatchInstruction instruction) {
      var sum = 0.0;
      var count = 0;
      for (int i = 0; i < 150; i++) {
        final state = MatchEngine.beginInteractiveHalf(
          home: home,
          away: away,
          startMinute: 1,
          endMinute: 45,
          interactiveTeamId: home.id,
        );
        MatchEngine.setInstruction(state, instruction);
        while (!state.isFinished) {
          final pending = state.pending!;
          if (pending.context == ChanceContext.attack) {
            sum += pending.shootChance!;
            count++;
            MatchEngine.resolvePendingChance(state, ChanceDecision.shoot);
          } else {
            MatchEngine.resolvePendingChance(state, ChanceDecision.coverSpace);
          }
        }
      }
      expect(count, greaterThan(0));
      return sum / count;
    }

    final aggressiveAvg = averageShootChanceFor(MatchInstruction.aggressive);
    final cautiousAvg = averageShootChanceFor(MatchInstruction.cautious);
    expect(aggressiveAvg, greaterThan(cautiousAvg));
  });

  test(
      'GameState.setMatchInstruction changes currentMatchInstruction for the '
      'live half in progress, and has no effect before any match is live',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    expect(gameState.currentMatchInstruction, MatchInstruction.balanced);

    // 進行中のハーフが存在しない間は変更しても既定のままとなる。
    gameState.setMatchInstruction(MatchInstruction.aggressive);
    expect(gameState.currentMatchInstruction, MatchInstruction.balanced);

    await gameState.playNextMatchday(interactive: true);
    gameState.setMatchInstruction(MatchInstruction.aggressive);
    expect(gameState.currentMatchInstruction, MatchInstruction.aggressive);

    while (gameState.pendingChanceDecision != null) {
      await gameState.resolveChanceDecision(ChanceDecision.shoot);
    }
  });

  test(
      'MatchEngine.beginInteractiveHalf assigns the defending goalkeeper as '
      "PendingChanceDecision.attack.keeper, and a shooter with much higher "
      "finishing/technique/composure than the keeper's reflexes/oneOnOnes/"
      'handling gets a higher average shootChance', () {
    Team buildAttackSide(String id, String name, {required bool sharp}) {
      final team =
          PlayerGenerator.generateSquad(id: id, name: name, strengthTier: 60);
      LineupUtils.autoFill(team);
      for (final p in MatchEngine.lineupOf(team)) {
        if (p.position.group == PositionGroup.att) {
          p.setAttributeValue(AttributeKeys.finishing, sharp ? 95 : 30);
          p.setAttributeValue(AttributeKeys.technique, sharp ? 95 : 30);
          p.setAttributeValue(AttributeKeys.composure, sharp ? 95 : 30);
        }
      }
      return team;
    }

    double averageShootChance(Team home, Team away) {
      var sum = 0.0;
      var count = 0;
      var sawKeeper = false;
      for (int i = 0; i < 60; i++) {
        final state = MatchEngine.beginInteractiveHalf(
          home: home,
          away: away,
          startMinute: 1,
          endMinute: 45,
          interactiveTeamId: home.id,
        );
        while (!state.isFinished) {
          final pending = state.pending!;
          if (pending.context == ChanceContext.attack) {
            sum += pending.shootChance!;
            count++;
            if (pending.keeper != null) sawKeeper = true;
            MatchEngine.resolvePendingChance(state, ChanceDecision.shoot);
          } else {
            MatchEngine.resolvePendingChance(state, ChanceDecision.coverSpace);
          }
        }
      }
      expect(count, greaterThan(0));
      expect(sawKeeper, isTrue);
      return sum / count;
    }

    final away = PlayerGenerator.generateSquad(
        id: 'keepera', name: 'Keeper Away FC', strengthTier: 60);
    LineupUtils.autoFill(away);

    final sharpAvg = averageShootChance(
        buildAttackSide('keeperh1', 'Sharp Home FC', sharp: true), away);
    final dullAvg = averageShootChance(
        buildAttackSide('keeperh2', 'Dull Home FC', sharp: false), away);
    expect(sharpAvg, greaterThan(dullAvg));
  });

  test(
      'MatchEngine.beginInteractiveHalf assigns a specific defender as '
      "PendingChanceDecision.defense.defender, and that same defender is "
      'the one at risk of a card on aggressiveTackle', () {
    final home = PlayerGenerator.generateSquad(
        id: 'duelh', name: 'Duel Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'duela', name: 'Duel Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    var sawDefenseChance = false;
    var sawMatchingCardTarget = false;
    for (int i = 0; i < 60; i++) {
      final state = MatchEngine.beginInteractiveHalf(
        home: home,
        away: away,
        startMinute: 1,
        endMinute: 45,
        interactiveTeamId: away.id,
      );
      while (!state.isFinished) {
        final pending = state.pending!;
        if (pending.context != ChanceContext.defense) {
          MatchEngine.resolvePendingChance(state, ChanceDecision.shoot);
          continue;
        }
        sawDefenseChance = true;
        final defender = pending.defender;
        final eventsBefore = state.events.length;
        MatchEngine.resolvePendingChance(
            state, ChanceDecision.aggressiveTackle);
        for (int j = eventsBefore; j < state.events.length; j++) {
          final e = state.events[j];
          if ((e.type == MatchEventType.yellowCard ||
                  e.type == MatchEventType.redCard) &&
              defender != null &&
              e.scorerId == defender.id) {
            sawMatchingCardTarget = true;
          }
        }
      }
      expect(state.isFinished, isTrue);
    }
    expect(sawDefenseChance, isTrue);
    expect(sawMatchingCardTarget, isTrue);
  });

  test(
      'PlayerGenerator.generate correlates attributes within the same '
      'category (technical/mental/physical/goalkeeping) more tightly than '
      'across categories, via a shared per-category generation bias', () {
    // corners/crossing(技術)・aggression(メンタル)はPosition.mcの
    // strong/weak補正のどちらにも該当せず、ポジション補正が常に0になるため、
    // カテゴリ相関バイアスの効果だけを切り出して比較できる。
    const trials = 300;
    var sameCategoryDiffSum = 0;
    var crossCategoryDiffSum = 0;
    for (int i = 0; i < trials; i++) {
      final p =
          PlayerGenerator.generate(position: Position.mc, strengthTier: 60);
      sameCategoryDiffSum += (p.attributeValue(AttributeKeys.corners) -
              p.attributeValue(AttributeKeys.crossing))
          .abs();
      crossCategoryDiffSum += (p.attributeValue(AttributeKeys.corners) -
              p.attributeValue(AttributeKeys.aggression))
          .abs();
    }
    expect(
      sameCategoryDiffSum / trials,
      lessThan(crossCategoryDiffSum / trials),
    );
  });

  test(
      'TrainingEngine growth chance for an attribute diminishes as it '
      'nears the potential ceiling, compared to when far from it', () {
    const potential = 90;
    const trials = 1500;

    int successesFor(int startingValue) {
      var successes = 0;
      for (int i = 0; i < trials; i++) {
        final p = Player(
          id: 'gp',
          name: 'gp',
          age: 24,
          position: Position.st,
          potential: potential,
        );
        for (final key in AttributeKeys.all) {
          p.setAttributeValue(key, 50);
        }
        p.setAttributeValue(AttributeKeys.stamina, startingValue);
        final team = Team(id: 'gt', name: 'gt', players: [p]);
        team.defaultTrainingFocus = TrainingFocus.fitness;
        TrainingEngine.applyWeeklyTraining(team);
        if (p.attributeValue(AttributeKeys.stamina) > startingValue) {
          successes++;
        }
      }
      return successes;
    }

    final closeSuccesses = successesFor(potential - 3);
    final farSuccesses = successesFor(potential - 30);
    expect(closeSuccesses, lessThan(farSuccesses));
  });

  test(
      'MatchEngine wires the previously-unused agility attribute into the '
      "attacker side of the defender-vs-attacker duel: a higher-agility "
      'attacking side yields a higher average aggressiveChanceAgainst for '
      'the defending team', () {
    final home = PlayerGenerator.generateSquad(
        id: 'agih', name: 'Agility Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'agia', name: 'Agility Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    double averageAggressiveChanceAgainst(int attackerAgility) {
      for (final p in MatchEngine.lineupOf(home)) {
        if (p.position.group == PositionGroup.att) {
          p.setAttributeValue(AttributeKeys.agility, attackerAgility);
        }
      }
      var sum = 0.0;
      var count = 0;
      for (int i = 0; i < 400; i++) {
        final state = MatchEngine.beginInteractiveHalf(
          home: home,
          away: away,
          startMinute: 1,
          endMinute: 45,
          interactiveTeamId: away.id,
        );
        while (!state.isFinished) {
          final pending = state.pending!;
          if (pending.context == ChanceContext.defense) {
            // agilityを操作したのはattグループの選手のみなので、それ以外が
            // 攻撃者だったサンプルは信号が薄まるため平均対象から除く。
            if (pending.attacker!.position.group == PositionGroup.att) {
              sum += pending.aggressiveChanceAgainst!;
              count++;
            }
            MatchEngine.resolvePendingChance(state, ChanceDecision.coverSpace);
          } else {
            MatchEngine.resolvePendingChance(state, ChanceDecision.shoot);
          }
        }
      }
      expect(count, greaterThan(0));
      return sum / count;
    }

    final agileAvg = averageAggressiveChanceAgainst(99);
    final dullAvg = averageAggressiveChanceAgainst(1);
    expect(agileAvg, greaterThan(dullAvg));
  });

  test(
      'GameState.playNextMatchday stops at half-time for the user fixture; playSecondHalf finalizes it',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    final firstHalf = await gameState.playNextMatchday();

    expect(firstHalf, isNotNull);
    expect(gameState.isHalfTime, isTrue);
    expect(firstHalf!.events.every((e) => e.minute <= 45), isTrue);

    final merged = await gameState.playSecondHalf();

    expect(merged, isNotNull);
    expect(gameState.isHalfTime, isFalse);
    final fixture = gameState.save!.league
        .fixturesForMatchday(merged!.matchday)
        .firstWhere((f) =>
            f.homeTeamId == merged.homeTeamId &&
            f.awayTeamId == merged.awayTeamId);
    expect(fixture.result, isNotNull);
  });

  test(
      'GameState.makeHalfTimeSubstitution swaps players and enforces the substitution limit',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    await gameState.playNextMatchday();
    expect(gameState.isHalfTime, isTrue);

    final team = gameState.userTeam;
    final outId = team.startingXI.first;
    final inId = team.players
        .firstWhere((p) => !team.startingXI.contains(p.id) && !p.isInjured)
        .id;

    final ok = gameState.makeHalfTimeSubstitution(
        outPlayerId: outId, inPlayerId: inId);

    expect(ok, isTrue);
    expect(team.startingXI.contains(inId), isTrue);
    expect(team.startingXI.contains(outId), isFalse);
    expect(gameState.substitutionsUsed, 1);
  });

  test(
      'GameState.playFriendly resolves a friendly without affecting league standings',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    expect(gameState.save!.friendlies, isNotEmpty);

    final result = await gameState.playFriendly(0);

    expect(result, isNotNull);
    expect(gameState.save!.friendlies[0].result, isNotNull);
    expect(
        gameState.save!.league.fixtures.every((f) => f.result == null), isTrue);
  });

  test(
      'GameState.acceptIncomingOffer sells the player and adds the offered amount to budget',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.userTeam.players.first;
    gameState.save!.budget = 0;
    gameState.save!.incomingOffers.add(IncomingOffer(
      id: 'o1',
      playerId: target.id,
      playerName: target.name,
      buyerClubName: 'よそのクラブ',
      amount: 500,
    ));

    final ok = await gameState.acceptIncomingOffer('o1');

    expect(ok, isTrue);
    expect(gameState.save!.budget, 500);
    expect(gameState.userTeam.players.any((p) => p.id == target.id), isFalse);
    expect(gameState.incomingOffers, isEmpty);
  });

  test(
      'GameState.acceptIncomingOffer discards rival competing offers for the same player',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.userTeam.players.first;
    gameState.save!.budget = 0;
    gameState.save!.incomingOffers.addAll([
      IncomingOffer(
        id: 'o1',
        playerId: target.id,
        playerName: target.name,
        buyerClubName: 'クラブA',
        amount: 500,
      ),
      IncomingOffer(
        id: 'o2',
        playerId: target.id,
        playerName: target.name,
        buyerClubName: 'クラブB',
        amount: 650,
      ),
    ]);

    final ok = await gameState.acceptIncomingOffer('o2');

    expect(ok, isTrue);
    expect(gameState.save!.budget, 650);
    expect(gameState.incomingOffers, isEmpty);
  });

  test(
      'GameState.playNextMatchday never lets more than 2 clubs compete for the same player',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    for (final p in gameState.userTeam.players) {
      p.contractYearsRemaining = 99;
    }

    for (int i = 0; i < 20; i++) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
      if (gameState.save!.league.isSeasonComplete) break;
      final counts = <String, int>{};
      for (final o in gameState.incomingOffers) {
        counts[o.playerId] = (counts[o.playerId] ?? 0) + 1;
      }
      expect(counts.values.every((c) => c <= 2), isTrue);
    }
  });

  test(
      'GameState.acceptIncomingOffer backfills the starting XI when a starter is sold',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    final target =
        team.players.firstWhere((p) => team.startingXI.contains(p.id));
    gameState.save!.incomingOffers.add(IncomingOffer(
      id: 'starter-offer',
      playerId: target.id,
      playerName: target.name,
      buyerClubName: 'よそのクラブ',
      amount: 500,
    ));

    final ok = await gameState.acceptIncomingOffer('starter-offer');

    expect(ok, isTrue);
    expect(team.startingXI.contains(target.id), isFalse);
    expect(team.startingXI.length, 11);
  });

  test(
      'GameState.acceptIncomingOffer discards a stale offer without crediting budget '
      'when the player already left the team', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.userTeam.players.first;
    gameState.save!.budget = 1000;
    gameState.save!.incomingOffers.add(IncomingOffer(
      id: 'stale-offer',
      playerId: target.id,
      playerName: target.name,
      buyerClubName: 'よそのクラブ',
      amount: 500,
    ));
    gameState.userTeam.players.removeWhere((p) => p.id == target.id);

    final ok = await gameState.acceptIncomingOffer('stale-offer');

    expect(ok, isFalse);
    expect(gameState.save!.budget, 1000);
    expect(gameState.incomingOffers, isEmpty);
  });

  test(
      'GameState.acceptIncomingOffer keeps the offer pending when the squad-size guard blocks the sale',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    while (team.players.length > minSquadSize) {
      final removable =
          team.players.firstWhere((p) => !team.startingXI.contains(p.id));
      team.players.remove(removable);
    }
    final target = team.players.first;
    gameState.save!.budget = 1000;
    gameState.save!.incomingOffers.add(IncomingOffer(
      id: 'guarded-offer',
      playerId: target.id,
      playerName: target.name,
      buyerClubName: 'よそのクラブ',
      amount: 500,
    ));

    final ok = await gameState.acceptIncomingOffer('guarded-offer');

    expect(ok, isFalse);
    expect(gameState.save!.budget, 1000);
    expect(
        gameState.incomingOffers.any((o) => o.id == 'guarded-offer'), isTrue);
  });

  test('GameState.playFriendly does not accumulate fatigue or cause injuries',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final lineup = MatchEngine.lineupOf(gameState.userTeam);
    final fatigueBefore = {for (final p in lineup) p.id: p.fatigue};
    final injuredBefore =
        lineup.where((p) => p.isInjured).map((p) => p.id).toSet();

    final result = await gameState.playFriendly(0);

    expect(result, isNotNull);
    for (final p in lineup) {
      expect(p.fatigue, fatigueBefore[p.id]);
    }
    final injuredAfter =
        lineup.where((p) => p.isInjured).map((p) => p.id).toSet();
    expect(injuredAfter, injuredBefore);
  });

  test(
      'GameState.declineIncomingOffer removes the offer without affecting budget',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.userTeam.players.first;
    gameState.save!.budget = 1000;
    gameState.save!.incomingOffers.add(IncomingOffer(
      id: 'o2',
      playerId: target.id,
      playerName: target.name,
      buyerClubName: 'よそのクラブ',
      amount: 500,
    ));

    await gameState.declineIncomingOffer('o2');

    expect(gameState.save!.budget, 1000);
    expect(gameState.userTeam.players.any((p) => p.id == target.id), isTrue);
    expect(gameState.incomingOffers, isEmpty);
  });

  test('GameState.setReleaseClause sets and clears the release clause',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.userTeam.players.first;

    await gameState.setReleaseClause(target.id, 1234);
    expect(target.releaseClause, 1234);

    await gameState.setReleaseClause(target.id, null);
    expect(target.releaseClause, isNull);
  });

  test(
      'GameState.acceptJobOffer switches clubs and resets confidence/board target',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final newTeamId =
        gameState.save!.league.teams.firstWhere((t) => t.id != 'user').id;
    gameState.save!.pendingJobOfferTeamId = newTeamId;
    gameState.save!.confidence = 10;

    final ok = await gameState.acceptJobOffer();

    expect(ok, isTrue);
    expect(gameState.save!.userTeamId, newTeamId);
    expect(gameState.save!.pendingJobOfferTeamId, isNull);
    expect(gameState.save!.confidence, 60);
  });

  test(
      'GameState.declineJobOffer clears the pending offer without switching clubs',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.pendingJobOfferTeamId = 'cpu0';

    await gameState.declineJobOffer();

    expect(gameState.save!.pendingJobOfferTeamId, isNull);
    expect(gameState.save!.userTeamId, 'user');
  });

  test(
      'GameState.startNextSeason generates a batch of youth intake candidates within bounds',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    await gameState.startNextSeason();

    expect(gameState.pendingYouthIntake.length, inInclusiveRange(3, 5));
    expect(gameState.managerReputation, inInclusiveRange(0, 100));
  });

  test('GameState.keepYouthIntakePlayer moves a candidate into youth prospects',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    await gameState.startNextSeason();
    final candidate = gameState.pendingYouthIntake.first;

    final ok = await gameState.keepYouthIntakePlayer(candidate.id);

    expect(ok, isTrue);
    expect(gameState.save!.youthProspects.any((p) => p.id == candidate.id),
        isTrue);
    expect(
        gameState.pendingYouthIntake.any((p) => p.id == candidate.id), isFalse);
  });

  test(
      'LoanEngine.weeklyRepaymentFor charges more in total for the longer, higher-interest term',
      () {
    const principal = 1000;
    final shortTerm = LoanEngine.terms.firstWhere((t) => t.weeks == 12);
    final longTerm = LoanEngine.terms.firstWhere((t) => t.weeks == 26);

    final shortTotal = LoanEngine.totalRepaymentFor(principal, shortTerm);
    final longTotal = LoanEngine.totalRepaymentFor(principal, longTerm);

    expect(shortTotal, greaterThan(principal));
    expect(longTotal, greaterThan(shortTotal));
    expect(
      LoanEngine.weeklyRepaymentFor(principal, longTerm),
      lessThan(LoanEngine.weeklyRepaymentFor(principal, shortTerm)),
    );
  });

  test(
      'GameState.takeLoan adds funds to the budget and refuses amounts above the borrowing limit',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.budget = 0;
    final term = LoanEngine.terms.first;
    final maxAmount = gameState.maxLoanAmount;

    final tooMuch = await gameState.takeLoan(maxAmount + 1000, term);
    expect(tooMuch, isFalse);
    expect(gameState.bankLoans, isEmpty);

    final ok = await gameState.takeLoan(maxAmount, term);

    expect(ok, isTrue);
    expect(gameState.save!.budget, maxAmount);
    expect(gameState.bankLoans.length, 1);
    expect(gameState.bankLoans.first.weeksRemaining, term.weeks);
  });

  test(
      'GameState.maxLoanAmount shrinks by the outstanding debt of existing loans',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final term = LoanEngine.terms.first;
    final beforeMax = gameState.maxLoanAmount;

    await gameState.takeLoan((beforeMax * 0.5).round(), term);

    expect(gameState.maxLoanAmount, lessThan(beforeMax));
  });

  test(
      'GameState.playNextMatchday counts down the loan and clears it once the term ends',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final term = LoanEngine.terms.firstWhere((t) => t.weeks == 12);
    await gameState.takeLoan(500, term);

    await gameState.playNextMatchday();
    if (gameState.isHalfTime) {
      await gameState.playSecondHalf();
    }

    expect(gameState.bankLoans.first.weeksRemaining, term.weeks - 1);

    for (int i = 1; i < term.weeks; i++) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
    }

    expect(gameState.bankLoans, isEmpty);
  });

  test(
      'InvestmentEngine.maturityValueFor pays out more for the longer, higher-yield term',
      () {
    const principal = 1000;
    final shortTerm = InvestmentEngine.terms.firstWhere((t) => t.weeks == 12);
    final longTerm = InvestmentEngine.terms.firstWhere((t) => t.weeks == 26);

    final shortMaturity =
        InvestmentEngine.maturityValueFor(principal, shortTerm);
    final longMaturity = InvestmentEngine.maturityValueFor(principal, longTerm);

    expect(shortMaturity, greaterThan(principal));
    expect(longMaturity, greaterThan(shortMaturity));
    expect(InvestmentEngine.interestFor(principal, shortTerm),
        shortMaturity - principal);
  });

  test(
      'GameState.openFixedDeposit locks the deposited funds and refuses amounts above the budget',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.budget = 1000;
    final term = InvestmentEngine.terms.first;

    final tooMuch = await gameState.openFixedDeposit(2000, term);
    expect(tooMuch, isFalse);
    expect(gameState.fixedDeposits, isEmpty);

    final ok = await gameState.openFixedDeposit(500, term);

    expect(ok, isTrue);
    expect(gameState.save!.budget, 500);
    expect(gameState.fixedDeposits.length, 1);
    expect(gameState.fixedDeposits.first.weeksRemaining, term.weeks);
    expect(gameState.totalDepositedFunds, 500);
  });

  test(
      'GameState.playNextMatchday counts down a fixed deposit and pays out principal plus interest at maturity',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final term = InvestmentEngine.terms.firstWhere((t) => t.weeks == 12);
    await gameState.openFixedDeposit(500, term);
    final maturityValue = gameState.fixedDeposits.first.maturityValue;

    await gameState.playNextMatchday();
    if (gameState.isHalfTime) {
      await gameState.playSecondHalf();
    }

    expect(gameState.fixedDeposits.first.weeksRemaining, term.weeks - 1);

    for (int i = 1; i < term.weeks; i++) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
    }

    expect(gameState.fixedDeposits, isEmpty);
    expect(gameState.lastMaturedDeposits.length, 1);
    expect(gameState.lastMaturedDeposits.first.maturityValue, maturityValue);
  });

  test(
      'GameState.startNextSeason auto-signs free agents when contract '
      'expirations would drop the squad below the minimum size', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;

    // 契約(年単位)はシーズン境界でのみ消化されるため、シーズンを完走させる。
    while (!gameState.save!.league.isSeasonComplete) {
      await gameState.playNextMatchdayQuickSim();
    }

    // 最低人数ぎりぎりまで減らした上で、残り全員の契約を今シーズン限りにする。
    while (team.players.length > minSquadSize) {
      team.players.removeLast();
    }
    for (final p in team.players) {
      p.isLoan = false;
      p.contractYearsRemaining = 1;
    }

    await gameState.startNextSeason();

    expect(team.players.length, greaterThanOrEqualTo(minSquadSize));
    expect(gameState.lastEmergencySignings, isNotEmpty);
  });

  test('GameState.runWeeklyTraining only allows one training session per week',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    final first = await gameState.runWeeklyTraining();
    final second = await gameState.runWeeklyTraining();

    expect(first, isTrue);
    expect(second, isFalse);
    expect(gameState.trainingDoneThisWeek, isTrue);

    await gameState.playNextMatchday();
    if (gameState.isHalfTime) {
      await gameState.playSecondHalf();
    }

    expect(gameState.trainingDoneThisWeek, isFalse);
    final afterMatchday = await gameState.runWeeklyTraining();
    expect(afterMatchday, isTrue);
  });

  test(
      'GameState.setAutoTrainingEnabled makes playNextMatchday run training '
      'automatically for the week', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.setAutoTrainingEnabled(true);
    expect(gameState.userTeam.autoTrainingEnabled, isTrue);
    expect(gameState.trainingDoneThisWeek, isFalse);

    await gameState.playNextMatchday();
    if (gameState.isHalfTime) {
      await gameState.playSecondHalf();
    }

    expect(gameState.trainingDoneThisWeek, isTrue);
    // 自動実施が有効な間は、手動でのrunWeeklyTrainingは既に消化済みとして
    // 扱われる(二重に成長機会を得ないようにするため)。
    expect(await gameState.runWeeklyTraining(), isFalse);
  });

  test(
      'GameState.runWeeklyTraining records a growth summary only for players whose attributes actually changed',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    // 成長判定は確率的なため、複数週分試して少なくとも一度は変化を捉える。
    // 週数は統計的な余裕を持たせて20週とする(8週では稀に偽陰性になりうる)。
    var sawAnyResult = false;
    for (int i = 0; i < 20; i++) {
      await gameState.runWeeklyTraining();
      if (gameState.lastTrainingResults.isNotEmpty) sawAnyResult = true;
      for (final r in gameState.lastTrainingResults) {
        final hasAttrChange = r.attributeDeltas.values.any((d) => d != 0);
        expect(hasAttrChange || r.overallDelta != 0, isTrue);
      }
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
    }

    expect(sawAnyResult, isTrue);
  });

  test(
      'GameState.seasonStatsFor tallies appearances, goals and average rating from played fixtures only',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final scorer = gameState.userTeam.players.first;
    final fixture = gameState.save!.league.fixtures.first;
    fixture.result = MatchResult(
      matchday: fixture.matchday,
      homeTeamId: fixture.homeTeamId,
      awayTeamId: fixture.awayTeamId,
      homeGoals: 1,
      awayGoals: 0,
      events: [
        MatchEvent(
            minute: 10,
            teamId: gameState.userTeam.id,
            scorerId: scorer.id,
            scorerName: scorer.name),
        MatchEvent(
            minute: 55,
            teamId: gameState.userTeam.id,
            scorerId: scorer.id,
            scorerName: scorer.name,
            type: MatchEventType.yellowCard),
      ],
      playerRatings: {scorer.id: 8.0},
    );

    final stats = gameState.seasonStatsFor(scorer.id);

    expect(stats.appearances, 1);
    expect(stats.goals, 1);
    expect(stats.yellowCards, 1);
    expect(stats.averageRating, 8.0);

    final unplayedTeammate = gameState.userTeam.players[1];
    final noStats = gameState.seasonStatsFor(unplayedTeammate.id);
    expect(noStats.appearances, 0);
    expect(noStats.averageRating, isNull);
  });

  test(
      'AwardsEngine.computeAwards picks the top scorer by goal tally and an MVP among starters',
      () {
    final home = PlayerGenerator.generateSquad(
        id: 'h', name: 'Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'a', name: 'Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);
    final topScorer = home.players.first;
    final otherScorer = away.players[1];
    final fixture = Fixture(
      matchday: 1,
      homeTeamId: home.id,
      awayTeamId: away.id,
      result: MatchResult(
        matchday: 1,
        homeTeamId: home.id,
        awayTeamId: away.id,
        homeGoals: 2,
        awayGoals: 1,
        events: [
          MatchEvent(
              minute: 10,
              teamId: home.id,
              scorerName: topScorer.name,
              scorerId: topScorer.id),
          MatchEvent(
              minute: 30,
              teamId: home.id,
              scorerName: topScorer.name,
              scorerId: topScorer.id),
          MatchEvent(
              minute: 50,
              teamId: away.id,
              scorerName: otherScorer.name,
              scorerId: otherScorer.id),
        ],
      ),
    );
    final league = League(teams: [home, away], fixtures: [fixture], season: 1);

    final award = AwardsEngine.computeAwards(league, 1);

    expect(award.season, 1);
    expect(award.topScorerId, topScorer.id);
    expect(award.topScorerName, topScorer.name);
    expect(award.topScorerTeamName, home.name);
    expect(award.topScorerGoals, 2);
    expect(award.mvpId, isNotNull);
    expect(award.mvpName, isNotNull);
  });

  test(
      'SeasonAward.toJson/fromJson round-trips the player IDs needed to link '
      'awards back to a player detail screen', () {
    final award = SeasonAward(
      season: 3,
      topScorerId: 'p1',
      topScorerName: 'Scorer',
      topScorerTeamName: 'FC A',
      topScorerTeamId: 'a',
      topScorerGoals: 12,
      mvpId: 'p2',
      mvpName: 'MVP',
      mvpTeamName: 'FC B',
      mvpTeamId: 'b',
      goldenGloveId: 'p3',
      goldenGloveName: 'Keeper',
      goldenGloveTeamName: 'FC C',
      goldenGloveTeamId: 'c',
      goldenGloveCleanSheets: 15,
    );

    final restored = SeasonAward.fromJson(award.toJson());

    expect(restored.topScorerId, 'p1');
    expect(restored.mvpId, 'p2');
    expect(restored.goldenGloveId, 'p3');
  });

  test(
      'AwardsEngine.computeAwards picks the Golden Glove winner by clean sheet count',
      () {
    final home = PlayerGenerator.generateSquad(
        id: 'gg-h', name: 'Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'gg-a', name: 'Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);
    final homeGk = home.players.firstWhere((p) => p.position == Position.gk);
    final awayGk = away.players.firstWhere((p) => p.position == Position.gk);
    final fixtures = [
      Fixture(
        matchday: 1,
        homeTeamId: home.id,
        awayTeamId: away.id,
        result: MatchResult(
          matchday: 1,
          homeTeamId: home.id,
          awayTeamId: away.id,
          homeGoals: 1,
          awayGoals: 0,
          events: [],
          playerRatings: {homeGk.id: 7.0, awayGk.id: 6.0},
        ),
      ),
      Fixture(
        matchday: 2,
        homeTeamId: home.id,
        awayTeamId: away.id,
        result: MatchResult(
          matchday: 2,
          homeTeamId: home.id,
          awayTeamId: away.id,
          homeGoals: 3,
          awayGoals: 0,
          events: [],
          playerRatings: {homeGk.id: 7.0, awayGk.id: 6.0},
        ),
      ),
    ];
    final league = League(teams: [home, away], fixtures: fixtures, season: 1);

    final award = AwardsEngine.computeAwards(league, 1);

    expect(award.goldenGloveName, homeGk.name);
    expect(award.goldenGloveTeamId, home.id);
    expect(award.goldenGloveCleanSheets, 2);
  });

  test(
      'AwardsEngine.computeManagerOfPeriod picks the best record within the '
      'matchday range and ignores fixtures outside it', () {
    final home = PlayerGenerator.generateSquad(
        id: 'h2', name: 'Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'a2', name: 'Away FC', strengthTier: 60);
    final fixtures = [
      Fixture(
        matchday: 1,
        homeTeamId: home.id,
        awayTeamId: away.id,
        result: MatchResult(
            matchday: 1,
            homeTeamId: home.id,
            awayTeamId: away.id,
            homeGoals: 3,
            awayGoals: 0,
            events: []),
      ),
      Fixture(
        matchday: 2,
        homeTeamId: away.id,
        awayTeamId: home.id,
        result: MatchResult(
            matchday: 2,
            homeTeamId: away.id,
            awayTeamId: home.id,
            homeGoals: 0,
            awayGoals: 0,
            events: []),
      ),
      // このシーズン後半の結果は範囲外なので無視されるべき。
      Fixture(
        matchday: 10,
        homeTeamId: away.id,
        awayTeamId: home.id,
        result: MatchResult(
            matchday: 10,
            homeTeamId: away.id,
            awayTeamId: home.id,
            homeGoals: 5,
            awayGoals: 0,
            events: []),
      ),
    ];
    final league = League(teams: [home, away], fixtures: fixtures, season: 1);

    final winner = AwardsEngine.computeManagerOfPeriod(league,
        fromMatchday: 1, toMatchday: 4);

    expect(winner, home.name);
  });

  test(
      'AwardsEngine.computeManagerOfSeason rewards the club that most '
      'overachieved its expected rank', () {
    final strong = PlayerGenerator.generateSquad(
        id: 'strong', name: 'Strong FC', strengthTier: 90);
    final weak = PlayerGenerator.generateSquad(
        id: 'weak2', name: 'Weak FC', strengthTier: 20);
    // 総合力ではstrongが優位だが、最終順位はweakが上(=weakの大健闘)。
    final league = League(
      teams: [strong, weak],
      fixtures: [
        Fixture(
          matchday: 1,
          homeTeamId: weak.id,
          awayTeamId: strong.id,
          result: MatchResult(
              matchday: 1,
              homeTeamId: weak.id,
              awayTeamId: strong.id,
              homeGoals: 2,
              awayGoals: 0,
              events: []),
        ),
      ],
      season: 1,
    );

    final winner = AwardsEngine.computeManagerOfSeason(league);

    expect(winner, weak.name);
  });

  test('GameState.startNextSeason records a season award once the season ends',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    while (!gameState.save!.league.isSeasonComplete) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
    }

    await gameState.startNextSeason();

    expect(gameState.seasonAwards, isNotEmpty);
    expect(gameState.seasonAwards.first.season, 1);
  });

  test(
      'GameState.startNextSeason leaves the growth summary empty for the '
      'very first season but populates it from the second season onward',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    while (!gameState.save!.league.isSeasonComplete) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
    }

    await gameState.startNextSeason();
    expect(gameState.lastSeasonGrowthSummary, isEmpty);

    // 2シーズン目開始時点のスカッドを基準に、シーズン終了時点の成長サマリーが
    // そのスカッドの部分集合であることを確認する(最終節ちょうどに契約満了と
    // なった選手は入れ替わり得るため、完全一致ではなく部分集合で検証する)。
    final squadIdsAtSeasonStart =
        gameState.userTeam.players.map((p) => p.id).toSet();
    while (!gameState.save!.league.isSeasonComplete) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
    }
    await gameState.startNextSeason();

    final ids =
        gameState.lastSeasonGrowthSummary.map((s) => s.playerId).toSet();
    expect(ids, isNotEmpty);
    expect(squadIdsAtSeasonStart.containsAll(ids), isTrue);
  });

  test(
      'GameState maintains a live, week-by-week simulated standings table for '
      'every division the user is not currently in', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final otherLeagues = gameState.save!.otherDivisionLeagues;
    expect(otherLeagues.where((l) => l != null).length, totalDivisionTiers - 1);
    for (final league in otherLeagues) {
      if (league == null) continue;
      expect(
          league.fixturesForMatchday(1).every((f) => f.result == null), isTrue);
    }

    await gameState.playNextMatchday();
    if (gameState.isHalfTime) {
      await gameState.playSecondHalf();
    }

    // ユーザーのリーグと同じ1節分が、他の全ディビジョンでも消化されているはず。
    for (final league in gameState.save!.otherDivisionLeagues) {
      if (league == null) continue;
      expect(
          league.fixturesForMatchday(1).every((f) => f.result != null), isTrue);
      expect(
          league.fixturesForMatchday(2).every((f) => f.result == null), isTrue);
    }
  });

  test(
      'playNextMatchday skips a background fixture referencing a team no '
      'longer present, instead of throwing and blocking the user\'s own '
      'matchday from ever resolving', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    // 何らかの理由で裏ディビジョンのチーム一覧とフィクスチャの参照が
    // ずれてしまった状態を模倣する(存在しないチームIDの試合を混入させる)。
    final otherLeague =
        gameState.save!.otherDivisionLeagues.firstWhere((l) => l != null)!;
    otherLeague.fixtures.add(Fixture(
      matchday: 1,
      homeTeamId: 'ghost-team-a',
      awayTeamId: 'ghost-team-b',
    ));

    // 例外が伝播せず、ユーザー自身の第1節は正常に消化されるはず。
    final firstHalf = await gameState.playNextMatchday();
    expect(firstHalf, isNotNull);
    if (gameState.isHalfTime) {
      await gameState.playSecondHalf();
    }
    expect(gameState.save!.league.nextUnplayedFixture?.matchday, 2);
  });

  test(
      'playNextMatchday skips a same-division fixture referencing a team no '
      'longer present, instead of throwing and blocking the user\'s own '
      'matchday from ever resolving', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    // ユーザー自身のリーグ内に、存在しないチームIDを参照する不整合な
    // フィクスチャが紛れ込んだ状態を模倣する。
    gameState.save!.league.fixtures.add(Fixture(
      matchday: 1,
      homeTeamId: 'ghost-team-c',
      awayTeamId: 'ghost-team-d',
    ));

    final firstHalf = await gameState.playNextMatchday();
    expect(firstHalf, isNotNull);
    if (gameState.isHalfTime) {
      await gameState.playSecondHalf();
    }
    expect(gameState.save!.league.nextUnplayedFixture?.matchday, 2);
  });

  test('LineupUtils.autoFill excludes players on international duty', () {
    final team = PlayerGenerator.generateSquad(
        id: 't6', name: 'Test FC', strengthTier: 60);
    for (final p in team.players.where((p) => p.position == Position.st)) {
      p.internationalDutyWeeksRemaining = 2;
    }
    LineupUtils.autoFill(team);
    final byId = {for (final p in team.players) p.id: p};
    final lineup = team.startingXI.map((id) => byId[id]!).toList();
    expect(lineup.every((p) => !p.isOnInternationalDuty), isTrue);
  });

  test(
      'GameState.playNextMatchday counts down a user player\'s international duty',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    player.internationalDutyWeeksRemaining = 2;

    await gameState.playNextMatchday();

    expect(player.internationalDutyWeeksRemaining, 1);
  });

  test(
      'GameState.playSecondHalf generates a press conference question that can be answered',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    await gameState.playNextMatchday();
    expect(gameState.isHalfTime, isTrue);

    await gameState.playSecondHalf();

    expect(gameState.pendingPressConference, isNotNull);
    final confidenceBefore = gameState.save!.confidence;
    final option = gameState.pendingPressConference!.options.first;

    await gameState.answerPressConference(0);

    expect(gameState.pendingPressConference, isNull);
    expect(gameState.save!.confidence,
        (confidenceBefore + option.confidenceDelta).clamp(0, 100));
  });

  test(
      'GameState.isRivalFixture matches the user-vs-rival fixture regardless of home/away order',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final userId = gameState.userTeam.id;
    final rivalId = gameState.save!.rivalTeamId!;
    final otherId = gameState.save!.league.teams
        .firstWhere((t) => t.id != userId && t.id != rivalId)
        .id;

    expect(
        gameState.isRivalFixture(
            Fixture(matchday: 1, homeTeamId: userId, awayTeamId: rivalId)),
        isTrue);
    expect(
        gameState.isRivalFixture(
            Fixture(matchday: 1, homeTeamId: rivalId, awayTeamId: userId)),
        isTrue);
    expect(
        gameState.isRivalFixture(
            Fixture(matchday: 1, homeTeamId: userId, awayTeamId: otherId)),
        isFalse);
    expect(
        gameState.isRivalFixture(
            Fixture(matchday: 1, homeTeamId: otherId, awayTeamId: rivalId)),
        isFalse);
  });

  test(
      'PromotionEngine.resolve swaps the bottom of tier1 with the top of tier2',
      () {
    List<Team> makeTeams(String prefix, int count) => List.generate(
          count,
          (i) => PlayerGenerator.generateSquad(
              id: '$prefix$i', name: '$prefix Team $i', strengthTier: 60),
        );

    final tier1Teams = makeTeams('t1', 8);
    final tier2Teams = makeTeams('t2', 8);
    for (final t in [...tier1Teams, ...tier2Teams]) {
      LineupUtils.autoFill(t);
    }
    // tier1PlayedOrderは実際の最終順位(良い順)を模した並び。
    final tier1PlayedOrder = List<Team>.from(tier1Teams);

    final result = PromotionEngine.resolve(
      tier1Teams: tier1Teams,
      tier2Teams: tier2Teams,
      tier1PlayedOrder: tier1PlayedOrder,
    );

    expect(result.tier1.length, 8);
    expect(result.tier2.length, 8);

    final survivorsTop = tier1PlayedOrder.take(5).map((t) => t.id).toSet();
    final relegatedIds = tier1PlayedOrder.skip(5).map((t) => t.id).toSet();
    final newTier1Ids = result.tier1.map((t) => t.id).toSet();
    final newTier2Ids = result.tier2.map((t) => t.id).toSet();

    // 上位5チームは残留し、下位3チームは降格する。
    expect(newTier1Ids.containsAll(survivorsTop), isTrue);
    expect(newTier2Ids.containsAll(relegatedIds), isTrue);
    // 昇格した3チームはすべてtier2の元メンバーから来ている。
    expect(
        newTier1Ids
            .difference(survivorsTop)
            .every((id) => tier2Teams.any((t) => t.id == id)),
        isTrue);
    // チームが増減せず、全チームがどちらかのディビジョンに存在する。
    final allOriginalIds = {
      ...tier1Teams.map((t) => t.id),
      ...tier2Teams.map((t) => t.id)
    };
    expect(newTier1Ids.union(newTier2Ids), allOriginalIds);
    expect(result.relegatedTeamNames.length, 3);
    expect(result.promotedTeamNames.length, 3);
  });

  test(
      'PromotionEngine.resolve runs a promotion playoff among 3rd-6th place '
      'for the final promotion spot', () {
    List<Team> makeTeams(String prefix, int count) => List.generate(
          count,
          (i) => PlayerGenerator.generateSquad(
              id: '$prefix$i', name: '$prefix Team $i', strengthTier: 60),
        );

    final tier1Teams = makeTeams('q1', 8);
    final tier2Teams = makeTeams('q2', 8);
    for (final t in [...tier1Teams, ...tier2Teams]) {
      LineupUtils.autoFill(t);
    }
    final tier1PlayedOrder = List<Team>.from(tier1Teams);
    final tier2PlayedOrder = List<Team>.from(tier2Teams);

    final result = PromotionEngine.resolve(
      tier1Teams: tier1Teams,
      tier2Teams: tier2Teams,
      tier1PlayedOrder: tier1PlayedOrder,
      tier2PlayedOrder: tier2PlayedOrder,
    );

    expect(result.promotionPlayoff.length, 3);
    final semiA = result.promotionPlayoff[0];
    final semiB = result.promotionPlayoff[1];
    final finalMatch = result.promotionPlayoff[2];

    // 準決勝は3位対6位、4位対5位の組み合わせで行われる。
    expect({semiA.homeId, semiA.awayId},
        {tier2PlayedOrder[2].id, tier2PlayedOrder[5].id});
    expect({semiB.homeId, semiB.awayId},
        {tier2PlayedOrder[3].id, tier2PlayedOrder[4].id});
    expect({finalMatch.homeId, finalMatch.awayId},
        {semiA.winnerId, semiB.winnerId});

    final newTier1Ids = result.tier1.map((t) => t.id).toSet();
    final newTier2Ids = result.tier2.map((t) => t.id).toSet();

    // 自動昇格の上位2チームは必ず昇格する。
    expect(newTier1Ids, contains(tier2PlayedOrder[0].id));
    expect(newTier1Ids, contains(tier2PlayedOrder[1].id));
    // プレーオフ決勝の勝者も昇格する。
    expect(newTier1Ids, contains(finalMatch.winnerId));

    // プレーオフで敗れた3チーム(両準決勝の敗者+決勝の敗者)は昇格しない。
    final playoffLosers = {
      semiA.homeId == semiA.winnerId ? semiA.awayId : semiA.homeId,
      semiB.homeId == semiB.winnerId ? semiB.awayId : semiB.homeId,
      finalMatch.homeId == finalMatch.winnerId
          ? finalMatch.awayId
          : finalMatch.homeId,
    };
    expect(playoffLosers.length, 3);
    for (final loserId in playoffLosers) {
      expect(newTier2Ids, contains(loserId));
    }

    // 昇格したのはちょうど3チーム(自動2+プレーオフ勝者1)。
    final survivingTier1Ids = tier1PlayedOrder.take(5).map((t) => t.id).toSet();
    expect(newTier1Ids.difference(survivingTier1Ids).length, 3);
  });

  test(
      'GameState.startNextSeason relegates the user to the second division when they finish last',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    // ユーザーは5部制の最下層(5部)から始まるため降格が起きない。降格の
    // 挙動そのものを検証するため、1部でプレー中という前提に切り替える。
    // 5部の枠(ユーザーの現在の所属)は元々nullなので、1部の枠にあった
    // 実データを5部の枠へ移し、1部の枠をnull化して整合を取る。
    final vacatedTier1League = gameState.save!.otherDivisionLeagues[0];
    gameState.save!.otherDivisionLeagues[0] = null;
    gameState.save!.otherDivisionLeagues[4] = vacatedTier1League;
    gameState.save!.currentDivisionTier = 1;
    final userId = gameState.userTeam.id;
    for (final f in gameState.save!.league.fixtures) {
      final userIsHome = f.homeTeamId == userId;
      final userIsAway = f.awayTeamId == userId;
      if (userIsHome || userIsAway) {
        f.result = MatchResult(
          matchday: f.matchday,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: userIsHome ? 0 : 3,
          awayGoals: userIsHome ? 3 : 0,
          events: [],
        );
      } else {
        f.result = MatchResult(
          matchday: f.matchday,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: 1,
          awayGoals: 1,
          events: [],
        );
      }
    }

    await gameState.startNextSeason();

    expect(gameState.currentDivisionTier, 2);
    expect(gameState.lastDivisionChangeMessage, contains('降格'));
    expect(() => gameState.userTeam, returnsNormally);
    expect(gameState.save!.league.teams.length, teamsPerLeague);
    expect(gameState.save!.otherDivisionLeagues[1], isNull);
    expect(
        gameState.save!.otherDivisionLeagues[0]!.teams.length, teamsPerLeague);
  });

  test(
      'ScoutReportEngine.generateFor produces a report with a key player and recommendation',
      () {
    final opponent = PlayerGenerator.generateSquad(
        id: 'opp', name: '対戦相手FC', strengthTier: 70);
    final userTeam = PlayerGenerator.generateSquad(
        id: 'user', name: 'テストFC', strengthTier: 60);
    LineupUtils.autoFill(opponent);
    LineupUtils.autoFill(userTeam);

    final report =
        ScoutReportEngine.generateFor(opponent: opponent, userTeam: userTeam);

    expect(report.opponentName, '対戦相手FC');
    expect(report.keyPlayerName, isNotNull);
    expect(report.recommendation, isNotEmpty);
  });

  test(
      'GameState.loanOutPlayer sends a player out on loan, excluding them from the wage bill and lineup',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    final target =
        team.players.firstWhere((p) => team.startingXI.contains(p.id));
    final wageBefore = ContractEngine.weeklyWageBill(team);

    final ok = await gameState.loanOutPlayer(target.id, 8);

    expect(ok, isTrue);
    expect(target.isLoanedOut, isTrue);
    expect(target.loanedOutWeeksRemaining, 8);
    expect(team.startingXI.contains(target.id), isFalse);
    expect(ContractEngine.weeklyWageBill(team), wageBefore - target.wage);
  });

  test(
      'GameState.playNextMatchday returns a loaned-out player to the squad once the term ends',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.userTeam.players.first;
    await gameState.loanOutPlayer(target.id, GameState.loanOutMinWeeks);

    for (int i = 0; i < GameState.loanOutMinWeeks; i++) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
    }

    expect(target.isLoanedOut, isFalse);
    expect(gameState.lastLoanReturns, contains(target.name));
  });

  test(
      'GameState.startNewGame seeds a free-agent pool, and signFreeAgent '
      'moves a pooled player into the squad without charging a transfer fee',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    expect(gameState.freeAgents, isNotEmpty);

    final target = gameState.freeAgents.first;
    final budgetBefore = gameState.save!.budget;
    final squadSizeBefore = gameState.userTeam.players.length;

    final ok = await gameState.signFreeAgent(target.id);

    expect(ok, isTrue);
    expect(gameState.save!.budget, budgetBefore);
    expect(gameState.userTeam.players.length, squadSizeBefore + 1);
    expect(gameState.userTeam.players.any((p) => p.id == target.id), isTrue);
    expect(gameState.freeAgents.any((p) => p.id == target.id), isFalse);
  });

  test(
      'GameState.setCaptain/setViceCaptain keep the two roles mutually '
      'exclusive', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final a = gameState.userTeam.players[0].id;
    final b = gameState.userTeam.players[1].id;

    await gameState.setCaptain(a);
    expect(gameState.userTeam.captainId, a);

    // 同じ選手を副キャプテンにも指名すると、キャプテンの指名は解除される。
    await gameState.setViceCaptain(a);
    expect(gameState.userTeam.viceCaptainId, a);
    expect(gameState.userTeam.captainId, isNull);

    // 別の選手をキャプテンにしても、副キャプテンの指名はそのまま残る。
    await gameState.setCaptain(b);
    expect(gameState.userTeam.captainId, b);
    expect(gameState.userTeam.viceCaptainId, a);
  });

  test('GameState.isTransferWindowOpen closes mid-season and blocks buyPlayer',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    expect(gameState.isTransferWindowOpen, isTrue);

    for (int i = 0; i < 5; i++) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
    }
    expect(gameState.isTransferWindowOpen, isFalse);

    gameState.save!.budget = 999999;
    final target = gameState.transferMarket.first;
    final ok = await gameState.buyPlayer(target.id);
    expect(ok, isFalse);
  });

  test('GameState.isTransferWindowOpen reopens for the mid-season window',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final league = gameState.save!.league;
    for (final f in league.fixtures) {
      if (f.matchday < 19) {
        f.result ??= MatchResult(
          matchday: f.matchday,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: 0,
          awayGoals: 0,
          events: [],
        );
      }
    }

    expect(gameState.isTransferWindowOpen, isTrue);
  });

  test('GameState.setTransferListed toggles the listed flag', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.userTeam.players.first;

    await gameState.setTransferListed(target.id, true);
    expect(target.isTransferListed, isTrue);

    await gameState.setTransferListed(target.id, false);
    expect(target.isTransferListed, isFalse);
  });

  test(
      'GameState.setPlayerDuty updates the duty and MatchEngine.simulate still runs under extreme tactics',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    for (final id in team.startingXI) {
      gameState.setPlayerDuty(id, PlayerDuty.attack);
    }
    team.width = 100;
    team.tempo = 100;
    expect(team.players.firstWhere((p) => p.id == team.startingXI.first).duty,
        PlayerDuty.attack);

    final away = PlayerGenerator.generateSquad(
        id: 'awayX', name: 'Away FC', strengthTier: 60);
    LineupUtils.autoFill(away);
    final result = MatchEngine.simulate(home: team, away: away, matchday: 1);

    expect(result.homeGoals, greaterThanOrEqualTo(0));
    expect(result.awayGoals, greaterThanOrEqualTo(0));
  });

  test('ClubInfrastructure.stadiumCapacity increases with facility level', () {
    final level1 = ClubInfrastructure.stadiumCapacity(1);
    final level5 = ClubInfrastructure.stadiumCapacity(5);
    expect(level5, greaterThan(level1));
  });

  test(
      'ClubInfrastructure formulas for training growth, fatigue recovery and '
      'injury risk scale monotonically with level', () {
    expect(ClubInfrastructure.trainingGrowthMultiplier(1, 1), 1.0);
    expect(ClubInfrastructure.trainingGrowthMultiplier(5, 1),
        greaterThan(ClubInfrastructure.trainingGrowthMultiplier(1, 1)));
    expect(ClubInfrastructure.trainingGrowthMultiplier(1, 5),
        greaterThan(ClubInfrastructure.trainingGrowthMultiplier(1, 1)));

    expect(ClubInfrastructure.fatigueRecoveryBonus(1), 0);
    expect(ClubInfrastructure.fatigueRecoveryBonus(5), greaterThan(0));

    expect(ClubInfrastructure.injuryFactor(1), 1.0);
    expect(ClubInfrastructure.injuryFactor(ClubInfrastructure.maxLevel),
        lessThan(ClubInfrastructure.injuryFactor(1)));
  });

  test(
      'GameState.careerRecordSoFar reflects the in-progress season before it ends',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    expect(gameState.save!.careerWins, 0);

    for (int i = 0; i < 3; i++) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
    }

    final row = gameState.save!.league.sortedStandings
        .firstWhere((r) => r.teamId == gameState.userTeam.id);
    final record = gameState.careerRecordSoFar;

    // シーズン終了前はsave.careerWinsそのものはまだ0のまま。
    expect(gameState.save!.careerWins, 0);
    // だがcareerRecordSoFarには進行中シーズンの成績が反映されている。
    expect(record.wins, row.won);
    expect(record.draws, row.draw);
    expect(record.losses, row.lost);
    expect(row.played, greaterThan(0));
  });

  test('GameState.expectedAttendance stays within the stadium capacity',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    expect(gameState.expectedAttendance, greaterThan(0));
    expect(gameState.expectedAttendance,
        lessThanOrEqualTo(gameState.stadiumCapacity));
  });

  test(
      'GameState.setTicketPricing trades attendance for per-head revenue in '
      'the expected direction', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    // 動員率が上限(満員)に張り付いて価格差が見えなくなるのを避けるため、
    // あえて動員率を下げる要因(低い信頼度・2部リーグ)を作っておく。
    gameState.save!.confidence = 0;
    gameState.save!.currentDivisionTier = 2;

    await gameState.setTicketPricing(TicketPricing.standard);
    final standardAttendance = gameState.expectedAttendance;
    final standardIncome = gameState.weeklyIncomeFor(gameState.userTeam.id);

    await gameState.setTicketPricing(TicketPricing.premium);
    final premiumAttendance = gameState.expectedAttendance;

    await gameState.setTicketPricing(TicketPricing.budget);
    final budgetAttendance = gameState.expectedAttendance;

    expect(gameState.save!.ticketPricing, TicketPricing.budget);
    expect(premiumAttendance, lessThan(standardAttendance));
    expect(budgetAttendance, greaterThan(standardAttendance));

    await gameState.setTicketPricing(TicketPricing.standard);
    expect(gameState.weeklyIncomeFor(gameState.userTeam.id), standardIncome);
  });

  test(
      'GameState.playNextMatchday records last match attendance within capacity',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    await gameState.playNextMatchday();

    expect(gameState.lastMatchAttendance, isNotNull);
    expect(gameState.lastMatchAttendance, greaterThan(0));
    expect(gameState.lastMatchAttendance,
        lessThanOrEqualTo(gameState.stadiumCapacity));
  });

  test(
      'AiTransferEngine.maybeGenerate never touches the user team and preserves total player count',
      () {
    final rng = Random(7);
    final user = PlayerGenerator.generateSquad(
        id: 'user', name: 'ユーザーFC', strengthTier: 60);
    final cpu1 = PlayerGenerator.generateSquad(
        id: 'cpu1', name: 'CPU1', strengthTier: 60);
    final cpu2 = PlayerGenerator.generateSquad(
        id: 'cpu2', name: 'CPU2', strengthTier: 60);
    final teams = [user, cpu1, cpu2];
    final totalBefore = teams.fold<int>(0, (s, t) => s + t.players.length);
    final userCountBefore = user.players.length;

    for (int i = 0; i < 30; i++) {
      AiTransferEngine.maybeGenerate(teams, 'user', rng);
    }

    final totalAfter = teams.fold<int>(0, (s, t) => s + t.players.length);
    expect(totalAfter, totalBefore);
    expect(user.players.length, userCountBefore);
  });

  test(
      'AiTransferEngine.maybeGenerate biases the destination toward a club '
      "whose strength fits the departing player's overall", () {
    final rng = Random(11);
    var movesToStrong = 0;
    var movesToWeak = 0;
    var trials = 0;
    while (movesToStrong + movesToWeak < 20 && trials < 500) {
      trials++;
      final fromTeam = PlayerGenerator.generateSquad(
          id: 'from', name: 'From FC', strengthTier: 60);
      final strongTeam = PlayerGenerator.generateSquad(
          id: 'strong', name: 'Strong FC', strengthTier: 95);
      final weakTeam = PlayerGenerator.generateSquad(
          id: 'weak', name: 'Weak FC', strengthTier: 5);
      // strong/weakは選手層を16人ちょうどに抑え、移籍元候補から除外する
      // (fromTeamの選手だけが必ず動くようにして、行き先の偏りだけを検証する)。
      for (final t in [strongTeam, weakTeam]) {
        while (t.players.length > 16) {
          t.players.removeLast();
        }
      }
      final teams = [fromTeam, strongTeam, weakTeam];

      final news = AiTransferEngine.maybeGenerate(teams, 'user', rng);
      if (news == null) continue;
      if (strongTeam.players.length > 16) movesToStrong++;
      if (weakTeam.players.length > 16) movesToWeak++;
    }

    expect(movesToStrong, greaterThan(0));
    expect(movesToStrong, greaterThan(movesToWeak * 3));
  });

  test(
      'GameState.playNextMatchday generates CPU-to-CPU transfer news without touching the user squad',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    // 契約切れによる離脱と混同しないよう、ユーザークラブの契約を十分延長しておく。
    for (final p in gameState.userTeam.players) {
      p.contractYearsRemaining = 99;
    }
    final userCountBefore = gameState.userTeam.players.length;

    for (int i = 0; i < 20; i++) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) await gameState.playSecondHalf();
      if (gameState.save!.league.isSeasonComplete) break;
    }

    expect(gameState.userTeam.players.length, userCountBefore);
  });

  test(
      'ContractEngine.signingBonusFor and appearanceFeeFor scale with personality wage sensitivity',
      () {
    final player = PlayerGenerator.generateSquad(
            id: 't', name: 'Test FC', strengthTier: 70)
        .players
        .first;
    player.personality = PlayerPersonality.ambitious;
    final ambitiousBonus = ContractEngine.signingBonusFor(player);
    final ambitiousFee = ContractEngine.appearanceFeeFor(player);

    player.personality = PlayerPersonality.loyal;
    final loyalBonus = ContractEngine.signingBonusFor(player);
    final loyalFee = ContractEngine.appearanceFeeFor(player);

    expect(ambitiousBonus, greaterThan(loyalBonus));
    expect(ambitiousFee, greaterThan(loyalFee));
  });

  test(
      'GameState.renewContract charges a signing bonus and sets a new appearance fee',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    player.contractYearsRemaining = 1;
    final baseCost = gameState.renewalCostFor(player.id);
    final bonus = gameState.signingBonusFor(player.id);
    expect(bonus, greaterThan(0));
    gameState.save!.budget = baseCost + bonus;

    final ok = await gameState.renewContract(player.id);

    expect(ok, isTrue);
    expect(gameState.save!.budget, 0);
    expect(player.appearanceFee, greaterThan(0));
  });

  test(
      'GameState.playNextMatchday pays appearance fees for the starting lineup',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    for (final id in team.startingXI) {
      team.players.firstWhere((p) => p.id == id).appearanceFee = 10;
    }
    final expectedFee = team.startingXI.length * 10;

    await gameState.playNextMatchday();

    expect(gameState.lastAppearanceFeesPaid, expectedFee);
  });

  test(
      'GameState.startNextSeason records career stats and a league trophy when the user finishes first',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final userId = gameState.userTeam.id;
    for (final f in gameState.save!.league.fixtures) {
      final userIsHome = f.homeTeamId == userId;
      final userIsAway = f.awayTeamId == userId;
      if (userIsHome || userIsAway) {
        f.result = MatchResult(
          matchday: f.matchday,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: userIsHome ? 3 : 0,
          awayGoals: userIsHome ? 0 : 3,
          events: [],
        );
      } else {
        f.result = MatchResult(
          matchday: f.matchday,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: 1,
          awayGoals: 1,
          events: [],
        );
      }
    }

    await gameState.startNextSeason();

    expect(gameState.save!.careerSeasons, 1);
    final totalMatches = gameState.save!.careerWins +
        gameState.save!.careerDraws +
        gameState.save!.careerLosses;
    expect(totalMatches, greaterThan(0));
    expect(gameState.save!.careerWins, totalMatches);
    expect(gameState.save!.trophyHistory, isNotEmpty);
    // 年間最優秀監督賞など、優勝トロフィーの後に別の表彰が追加される
    // こともあるため、最後の要素固定ではなく「優勝」を含む記録の
    // 存在で判定する。
    expect(gameState.save!.trophyHistory.any((t) => t.contains('優勝')), isTrue);
  });

  test(
      'GameState.startNextSeason records the background promotion playoff '
      "results even when they don't involve the user's tier-1 club", () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final userId = gameState.userTeam.id;
    for (final f in gameState.save!.league.fixtures) {
      final userIsHome = f.homeTeamId == userId;
      final userIsAway = f.awayTeamId == userId;
      f.result = MatchResult(
        matchday: f.matchday,
        homeTeamId: f.homeTeamId,
        awayTeamId: f.awayTeamId,
        homeGoals: userIsHome ? 3 : (userIsAway ? 0 : 1),
        awayGoals: userIsHome ? 0 : (userIsAway ? 3 : 1),
        events: [],
      );
    }

    await gameState.startNextSeason();

    // 2部の昇格プレーオフ(準決勝2試合+決勝)は毎シーズン必ず行われる。
    expect(gameState.lastPromotionPlayoffResults.length, 3);
    // ユーザーは1部で優勝しているため、2部のプレーオフには関与していない。
    expect(gameState.userInvolvedInLastPromotionPlayoff, isFalse);
  });

  test(
      'SuperCupEngine.pairing pits the league champion against the domestic '
      'cup champion', () {
    final cup = Cup(type: CupType.domestic, name: '国内カップ', rounds: [
      [
        CupMatch(
          round: 1,
          homeTeamId: 'cupWinner',
          awayTeamId: 'cupRunnerUp',
          result: MatchResult(
              matchday: 0,
              homeTeamId: 'cupWinner',
              awayTeamId: 'cupRunnerUp',
              homeGoals: 2,
              awayGoals: 1,
              events: []),
        ),
      ],
    ]);

    final pairing = SuperCupEngine.pairing(
        leagueChampionId: 'leagueChamp', domesticCup: cup);

    expect(pairing, ('leagueChamp', 'cupWinner'));
  });

  test(
      'SuperCupEngine.pairing falls back to the cup runner-up when one club '
      'won both titles', () {
    final cup = Cup(type: CupType.domestic, name: '国内カップ', rounds: [
      [
        CupMatch(
          round: 1,
          homeTeamId: 'doubleWinner',
          awayTeamId: 'cupRunnerUp',
          result: MatchResult(
              matchday: 0,
              homeTeamId: 'doubleWinner',
              awayTeamId: 'cupRunnerUp',
              homeGoals: 3,
              awayGoals: 0,
              events: []),
        ),
      ],
    ]);

    final pairing = SuperCupEngine.pairing(
        leagueChampionId: 'doubleWinner', domesticCup: cup);

    expect(pairing, ('doubleWinner', 'cupRunnerUp'));
  });

  test(
      'SuperCupEngine.pairing returns null when the domestic cup has not '
      'finished', () {
    final cup = Cup(type: CupType.domestic, name: '国内カップ', rounds: [
      [CupMatch(round: 1, homeTeamId: 'a', awayTeamId: 'b')],
    ]);

    final pairing = SuperCupEngine.pairing(
        leagueChampionId: 'leagueChamp', domesticCup: cup);

    expect(pairing, isNull);
  });

  test(
      'GameState.startNextSeason schedules a pending Super Cup for the '
      'league champion once the domestic cup has finished', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final userId = gameState.userTeam.id;
    for (final f in gameState.save!.league.fixtures) {
      final userIsHome = f.homeTeamId == userId;
      final userIsAway = f.awayTeamId == userId;
      f.result = MatchResult(
        matchday: f.matchday,
        homeTeamId: f.homeTeamId,
        awayTeamId: f.awayTeamId,
        homeGoals: userIsHome ? 3 : (userIsAway ? 0 : 1),
        awayGoals: userIsHome ? 0 : (userIsAway ? 3 : 1),
        events: [],
      );
    }
    // 国内カップを最後まで消化しておく(誰が優勝してもよい)。
    while (gameState.domesticCup?.nextUnplayedMatch != null) {
      await gameState.playNextCupMatch();
    }

    await gameState.startNextSeason();

    expect(gameState.pendingSuperCup, isNotNull);
    final match = gameState.pendingSuperCup!;
    expect(match.homeTeamId == userId || match.awayTeamId == userId, isTrue);
  });

  test(
      'GameState.startNextSeason archives a SeasonRecord with the final standing',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final userId = gameState.userTeam.id;
    for (final f in gameState.save!.league.fixtures) {
      final userIsHome = f.homeTeamId == userId;
      f.result = MatchResult(
        matchday: f.matchday,
        homeTeamId: f.homeTeamId,
        awayTeamId: f.awayTeamId,
        homeGoals: userIsHome ? 3 : 0,
        awayGoals: userIsHome ? 0 : 3,
        events: [],
      );
    }

    expect(gameState.seasonHistory, isEmpty);
    await gameState.startNextSeason();

    expect(gameState.seasonHistory.length, 1);
    final record = gameState.seasonHistory.first;
    expect(record.season, 1);
    expect(record.finalRank, 1);
    expect(record.wonLeague, isTrue);
    expect(record.won, greaterThan(0));
    expect(record.points, record.won * 3 + record.draw);
  });

  test(
      'BestElevenEngine.compute selects the highest average-rated player per position group',
      () {
    final teamA =
        PlayerGenerator.generateSquad(id: 'a', name: 'AFC', strengthTier: 60);
    final teamB =
        PlayerGenerator.generateSquad(id: 'b', name: 'BFC', strengthTier: 60);
    LineupUtils.autoFill(teamA);
    LineupUtils.autoFill(teamB);

    final gkA = teamA.players.firstWhere((p) => p.position == Position.gk);
    final gkB = teamB.players.firstWhere((p) => p.position == Position.gk);

    final fixtures = <Fixture>[
      for (int md = 1; md <= 3; md++)
        Fixture(
          matchday: md,
          homeTeamId: 'a',
          awayTeamId: 'b',
          result: MatchResult(
            matchday: md,
            homeTeamId: 'a',
            awayTeamId: 'b',
            homeGoals: 1,
            awayGoals: 0,
            events: [],
            playerRatings: {gkA.id: 8.0, gkB.id: 5.0},
          ),
        ),
    ];
    final league = League(teams: [teamA, teamB], fixtures: fixtures, season: 1);

    final best = BestElevenEngine.compute(league, 1);

    final gkEntries =
        best.entries.where((e) => e.group == PositionGroup.gk).toList();
    expect(gkEntries.length, 1);
    expect(gkEntries.first.playerId, gkA.id);
    expect(gkEntries.first.avgRating, 8.0);
  });

  test(
      'BestElevenEngine.compute excludes players below the minimum appearance count',
      () {
    final teamA =
        PlayerGenerator.generateSquad(id: 'a', name: 'AFC', strengthTier: 60);
    LineupUtils.autoFill(teamA);
    final gk = teamA.players.firstWhere((p) => p.position == Position.gk);

    final fixtures = <Fixture>[
      Fixture(
        matchday: 1,
        homeTeamId: 'a',
        awayTeamId: 'a',
        result: MatchResult(
          matchday: 1,
          homeTeamId: 'a',
          awayTeamId: 'a',
          homeGoals: 1,
          awayGoals: 0,
          events: [],
          playerRatings: {gk.id: 9.0},
        ),
      ),
    ];
    final league = League(teams: [teamA], fixtures: fixtures, season: 1);

    final best = BestElevenEngine.compute(league, 1);

    expect(best.entries, isEmpty);
  });

  test(
      'GameState.acceptJobOffer appends the new club to the manager\'s club history',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.pendingJobOfferTeamId = gameState.save!.league.teams
        .firstWhere((t) => t.id != gameState.save!.userTeamId)
        .id;
    final newTeamName = gameState.save!.league.teams
        .firstWhere((t) => t.id == gameState.save!.pendingJobOfferTeamId)
        .name;

    final ok = await gameState.acceptJobOffer();

    expect(ok, isTrue);
    expect(gameState.save!.clubHistory.length, 2);
    expect(gameState.save!.clubHistory.last, newTeamName);
  });

  test('GameState.exportSaveJson/importSaveJson round-trips the save data',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.budget = 12345;

    final json = gameState.exportSaveJson();
    expect(json, isNotNull);

    final fresh = GameState();
    final ok = await fresh.importSaveJson(json!);

    expect(ok, isTrue);
    expect(fresh.save!.clubName, 'テストFC');
    expect(fresh.save!.budget, 12345);
  });

  test('GameState.importSaveJson rejects malformed JSON without crashing',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    final ok = await gameState.importSaveJson('not valid json');

    expect(ok, isFalse);
    expect(gameState.save!.clubName, 'テストFC');
  });

  test('GameState save slots keep independent clubs and support delete',
      () async {
    final gameState = GameState();
    await gameState.init();

    await gameState.loadSlot(0);
    await gameState.startNewGame('スロット0FC');
    await gameState.loadSlot(1);
    await gameState.startNewGame('スロット1FC');

    final slots = await gameState.listSaveSlots();
    expect(slots.length, GameState.maxSaveSlots);
    expect(slots[0].clubName, 'スロット0FC');
    expect(slots[1].clubName, 'スロット1FC');
    expect(slots[2].hasSave, isFalse);

    await gameState.loadSlot(0);
    expect(gameState.save!.clubName, 'スロット0FC');

    await gameState.deleteSlot(1);
    final afterDelete = await gameState.listSaveSlots();
    expect(afterDelete[1].hasSave, isFalse);
    // Deleting a non-current slot must not touch the currently loaded save.
    expect(gameState.save!.clubName, 'スロット0FC');
  });

  test('GameState.init migrates a legacy single-slot save into slot 0',
      () async {
    final legacy = GameState();
    await legacy.startNewGame('レガシーFC');
    final json = legacy.exportSaveJson()!;

    SharedPreferences.setMockInitialValues({'soccer_manager_save_v1': json});
    final migrated = GameState();
    await migrated.init();

    expect(migrated.save!.clubName, 'レガシーFC');
    expect(migrated.currentSlot, 0);
  });

  test(
      'GameState.isBusy toggles off after startNewGame and startNextSeason complete',
      () async {
    final gameState = GameState();
    expect(gameState.isBusy, isFalse);

    await gameState.startNewGame('テストFC');
    expect(gameState.isBusy, isFalse);

    await gameState.startNextSeason();
    expect(gameState.isBusy, isFalse);
  });

  test('GameState.toggleWatched adds and removes a player from the watchlist',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final anyPlayerId = gameState.userTeam.players.first.id;

    expect(gameState.isWatched(anyPlayerId), isFalse);

    await gameState.toggleWatched(anyPlayerId);
    expect(gameState.isWatched(anyPlayerId), isTrue);
    expect(gameState.save!.watchlistPlayerIds, contains(anyPlayerId));

    await gameState.toggleWatched(anyPlayerId);
    expect(gameState.isWatched(anyPlayerId), isFalse);
    expect(gameState.save!.watchlistPlayerIds, isNot(contains(anyPlayerId)));
  });

  test('SquadScreen.filterAndSort filters by position group and search query',
      () {
    Player make(String id, String name, Position pos) => Player(
          id: id,
          name: name,
          age: 20,
          position: pos,
          potential: 70,
        );

    final gk = make('gk', 'GKプレイヤー', Position.gk);
    final df = make('df', 'ディフェンダー', Position.dc);
    final mf = make('mf', 'サントス', Position.mc);
    final all = [gk, df, mf];

    final defOnly = SquadScreen.filterAndSort(all, group: PositionGroup.def);
    expect(defOnly.map((p) => p.id), ['df']);

    final searched = SquadScreen.filterAndSort(all, query: 'サントス');
    expect(searched.map((p) => p.id), ['mf']);

    final none = SquadScreen.filterAndSort(all, query: '存在しない名前');
    expect(none, isEmpty);
  });

  test('SquadScreen.filterAndSort sorts by the requested criterion', () {
    Player make(String id,
        {required int overall,
        required int age,
        required int potential,
        required int wage}) {
      final p = Player(
          id: id,
          name: id,
          age: age,
          position: Position.mc,
          potential: potential,
          wage: wage);
      for (final key in AttributeKeys.all) {
        p.setAttributeValue(key, overall);
      }
      return p;
    }

    final a = make('a', overall: 80, age: 30, potential: 60, wage: 100);
    final b = make('b', overall: 60, age: 20, potential: 90, wage: 200);
    final all = [a, b];

    expect(
        SquadScreen.filterAndSort(all, sort: SquadSortOption.overall).first.id,
        'a');
    expect(SquadScreen.filterAndSort(all, sort: SquadSortOption.age).first.id,
        'b');
    expect(
        SquadScreen.filterAndSort(all, sort: SquadSortOption.potential)
            .first
            .id,
        'b');
    expect(SquadScreen.filterAndSort(all, sort: SquadSortOption.wage).first.id,
        'b');
  });

  test(
      'TransferScreen.filterAndSort filters by position group and search query',
      () {
    Player make(String id, String name, Position pos) => Player(
          id: id,
          name: name,
          age: 20,
          position: pos,
          potential: 70,
        );

    final gk = make('gk', 'GKプレイヤー', Position.gk);
    final st = make('st', 'ストライカー', Position.st);
    final all = [gk, st];

    final attOnly = TransferScreen.filterAndSort(all, group: PositionGroup.att);
    expect(attOnly.map((p) => p.id), ['st']);

    final searched = TransferScreen.filterAndSort(all, query: 'ストライカー');
    expect(searched.map((p) => p.id), ['st']);
  });

  test('TransferScreen.filterAndSort sorts by the requested criterion', () {
    Player make(String id,
        {required int overall, required int potential, required int age}) {
      final p = Player(
          id: id,
          name: id,
          age: age,
          position: Position.mc,
          potential: potential);
      for (final key in AttributeKeys.all) {
        p.setAttributeValue(key, overall);
      }
      return p;
    }

    final expensive = make('expensive', overall: 80, potential: 60, age: 25);
    final cheap = make('cheap', overall: 40, potential: 90, age: 18);
    final all = [expensive, cheap];

    expect(
        TransferScreen.filterAndSort(all, sort: TransferSortOption.overall)
            .first
            .id,
        'expensive');
    expect(
        TransferScreen.filterAndSort(all, sort: TransferSortOption.potential)
            .first
            .id,
        'cheap');
    expect(
        TransferScreen.filterAndSort(all, sort: TransferSortOption.age)
            .first
            .id,
        'cheap');
    expect(
      TransferScreen.filterAndSort(all, sort: TransferSortOption.marketValue)
          .first
          .id,
      cheap.marketValue <= expensive.marketValue ? 'cheap' : 'expensive',
    );
  });

  test(
      'ContractEngine.yearsLabel/yearsShortLabel show the remaining contract '
      'years directly, selecting the pending-expiry wording at zero or below',
      () {
    expect(ContractEngine.yearsLabel(0), '契約満了間近');
    expect(ContractEngine.yearsLabel(-3), '契約満了間近');
    expect(ContractEngine.yearsLabel(1), '契約残り1年');
    expect(ContractEngine.yearsShortLabel(0), '契約満了間近');
    expect(ContractEngine.yearsShortLabel(2), '残り2年');
  });

  test(
      'ContractEngine.negotiatedYears grants longer contracts to younger '
      'players and shorter ones to veterans', () {
    final young = PlayerGenerator.generate(
        position: Position.st, strengthTier: 60, ageOverride: 20);
    final prime = PlayerGenerator.generate(
        position: Position.st, strengthTier: 60, ageOverride: 25);
    final veteran = PlayerGenerator.generate(
        position: Position.st, strengthTier: 60, ageOverride: 33);

    expect(ContractEngine.negotiatedYears(young),
        greaterThan(ContractEngine.negotiatedYears(prime)));
    expect(ContractEngine.negotiatedYears(prime),
        greaterThan(ContractEngine.negotiatedYears(veteran)));
  });

  test(
      'ContractEngine.minimumAcceptableWage scales with personality wage sensitivity',
      () {
    final player = PlayerGenerator.generateSquad(
            id: 't', name: 'Test FC', strengthTier: 70)
        .players
        .first;
    player.wage = 100;
    player.personality = PlayerPersonality.ambitious;
    final ambitious = ContractEngine.minimumAcceptableWage(player);

    player.personality = PlayerPersonality.loyal;
    final loyal = ContractEngine.minimumAcceptableWage(player);

    expect(ambitious, greaterThan(loyal));
    expect(ambitious, greaterThan(player.wage));
  });

  test(
      'ContractEngine.counterOffer never falls below the minimum acceptable wage',
      () {
    final player = PlayerGenerator.generateSquad(
            id: 't', name: 'Test FC', strengthTier: 70)
        .players
        .first;
    player.wage = 100;
    player.personality = PlayerPersonality.balanced;
    final minAcceptable = ContractEngine.minimumAcceptableWage(player);

    final counterFromLowOffer = ContractEngine.counterOffer(player, 0);
    final counterFromHighOffer =
        ContractEngine.counterOffer(player, minAcceptable * 2);

    expect(counterFromLowOffer, greaterThanOrEqualTo(minAcceptable));
    expect(counterFromHighOffer, greaterThanOrEqualTo(minAcceptable));
    expect(counterFromHighOffer, greaterThan(counterFromLowOffer));
  });

  test(
      'GameState.startContractNegotiation opens with a bluffed demand above '
      'the true minimum acceptable wage instead of revealing it immediately',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    player.personality = PlayerPersonality.balanced;

    gameState.startContractNegotiation(player.id);

    final negotiation = gameState.pendingContractNegotiation;
    expect(negotiation, isNotNull);
    expect(negotiation!.playerId, player.id);
    expect(negotiation.initialWage, player.wage);
    expect(negotiation.counterWage, ContractEngine.initialDemand(player));
    expect(negotiation.counterWage,
        greaterThan(ContractEngine.minimumAcceptableWage(player)));
    expect(negotiation.roundsUsed, 0);
  });

  test(
      'GameState.offerContractWage accepts an offer at or above the minimum acceptable wage',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    player.personality = PlayerPersonality.balanced;
    player.contractYearsRemaining = 1;
    gameState.startContractNegotiation(player.id);
    final minAcceptable = ContractEngine.minimumAcceptableWage(player);
    final cost = gameState.renewalCostFor(player.id) +
        gameState.signingBonusFor(player.id);
    gameState.save!.budget = cost;

    final result = await gameState.offerContractWage(minAcceptable);

    expect(result, ContractOfferResult.accepted);
    expect(player.wage, minAcceptable);
    expect(
        player.contractYearsRemaining, ContractEngine.negotiatedYears(player));
    expect(gameState.save!.budget, 0);
    expect(gameState.pendingContractNegotiation, isNull);
  });

  test(
      'GameState.offerContractWage returns insufficientFunds when the club cannot afford an accepted offer',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    player.personality = PlayerPersonality.balanced;
    gameState.startContractNegotiation(player.id);
    final minAcceptable = ContractEngine.minimumAcceptableWage(player);
    gameState.save!.budget = 0;

    final result = await gameState.offerContractWage(minAcceptable);

    expect(result, ContractOfferResult.insufficientFunds);
    expect(gameState.pendingContractNegotiation, isNotNull);
  });

  test(
      'GameState.offerContractWage counters a low offer and walks away after too many rejected rounds',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    player.personality = PlayerPersonality.balanced;
    gameState.startContractNegotiation(player.id);

    ContractOfferResult result = ContractOfferResult.countered;
    for (int i = 0; i < ContractEngine.maxNegotiationRounds; i++) {
      result = await gameState.offerContractWage(1);
      if (result != ContractOfferResult.countered) break;
      expect(gameState.pendingContractNegotiation!.roundsUsed, i + 1);
    }

    expect(result, ContractOfferResult.walkedAway);
    expect(gameState.pendingContractNegotiation, isNull);
  });

  test(
      'League.sortedStandings breaks a points tie by head-to-head record '
      'before falling back to overall goal difference', () {
    final a =
        PlayerGenerator.generateSquad(id: 'ha', name: 'A FC', strengthTier: 60);
    final b =
        PlayerGenerator.generateSquad(id: 'hb', name: 'B FC', strengthTier: 60);
    final c =
        PlayerGenerator.generateSquad(id: 'hc', name: 'C FC', strengthTier: 60);
    final d =
        PlayerGenerator.generateSquad(id: 'hd', name: 'D FC', strengthTier: 60);

    MatchResult result(String home, String away, int hg, int ag) => MatchResult(
        matchday: 1,
        homeTeamId: home,
        awayTeamId: away,
        homeGoals: hg,
        awayGoals: ag,
        events: []);
    Fixture fixture(String home, String away, int hg, int ag) => Fixture(
        matchday: 1,
        homeTeamId: home,
        awayTeamId: away,
        result: result(home, away, hg, ag));

    // Aとbは総勝点6で並ぶが、AはBより総得失点差で上回る(+3 対 0)。
    // ただし直接対決ではBがAに勝っているため、直接対決を優先すればBが上位になる。
    final fixtures = [
      fixture(a.id, b.id, 0, 1),
      fixture(a.id, c.id, 2, 0),
      fixture(a.id, d.id, 2, 0),
      fixture(b.id, c.id, 1, 0),
      fixture(b.id, d.id, 0, 2),
      fixture(c.id, d.id, 1, 1),
    ];
    final league = League(teams: [a, b, c, d], fixtures: fixtures, season: 1);

    final order = league.sortedStandings.map((r) => r.teamId).toList();

    expect(order, [b.id, a.id, d.id, c.id]);
  });

  test(
      'League.recentFormFor returns the last 5 results in chronological '
      'order', () {
    final a = PlayerGenerator.generateSquad(
        id: 'fa', name: 'Form FC', strengthTier: 60);
    final b = PlayerGenerator.generateSquad(
        id: 'fb', name: 'Opponent FC', strengthTier: 60);

    Fixture fixture(int md, int hg, int ag) => Fixture(
        matchday: md,
        homeTeamId: a.id,
        awayTeamId: b.id,
        result: MatchResult(
            matchday: md,
            homeTeamId: a.id,
            awayTeamId: b.id,
            homeGoals: hg,
            awayGoals: ag,
            events: []));

    final fixtures = [
      fixture(1, 3, 0), // W (falls outside the last 5)
      fixture(2, 0, 1), // L
      fixture(3, 1, 1), // D
      fixture(4, 2, 0), // W
      fixture(5, 0, 2), // L
      fixture(6, 1, 0), // W
    ];
    final league = League(teams: [a, b], fixtures: fixtures, season: 1);

    final form = league.recentFormFor(a.id);

    expect(form, ['L', 'D', 'W', 'L', 'W']);
  });

  test('GameState.cancelContractNegotiation clears the pending negotiation',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    gameState.startContractNegotiation(player.id);
    expect(gameState.pendingContractNegotiation, isNotNull);

    gameState.cancelContractNegotiation();

    expect(gameState.pendingContractNegotiation, isNull);
  });

  test(
      'SeasonProjectionEngine.project favors the stronger team over many remaining fixtures',
      () {
    final strong = PlayerGenerator.generateSquad(
        id: 's', name: 'Strong FC', strengthTier: 90);
    final weak = PlayerGenerator.generateSquad(
        id: 'w', name: 'Weak FC', strengthTier: 30);
    final league = League(teams: [
      strong,
      weak
    ], fixtures: [
      Fixture(matchday: 1, homeTeamId: strong.id, awayTeamId: weak.id),
      Fixture(matchday: 2, homeTeamId: weak.id, awayTeamId: strong.id),
    ]);

    final projections = SeasonProjectionEngine.project(league,
        iterations: 300, random: Random(7));
    final strongProjection =
        projections.firstWhere((p) => p.teamId == strong.id);
    final weakProjection = projections.firstWhere((p) => p.teamId == weak.id);

    expect(strongProjection.avgFinalPoints,
        greaterThan(weakProjection.avgFinalPoints));
    expect(strongProjection.titleProbability,
        greaterThan(weakProjection.titleProbability));
  });

  test(
      'SeasonProjectionEngine.project reflects current standings exactly once the season is complete',
      () {
    final teamA =
        PlayerGenerator.generateSquad(id: 'a', name: 'A FC', strengthTier: 60);
    final teamB =
        PlayerGenerator.generateSquad(id: 'b', name: 'B FC', strengthTier: 60);
    final league = League(teams: [
      teamA,
      teamB
    ], fixtures: [
      Fixture(
        matchday: 1,
        homeTeamId: teamA.id,
        awayTeamId: teamB.id,
        result: MatchResult(
          matchday: 1,
          homeTeamId: teamA.id,
          awayTeamId: teamB.id,
          homeGoals: 3,
          awayGoals: 0,
          events: [],
        ),
      ),
    ]);

    final projections = SeasonProjectionEngine.project(league, iterations: 50);
    final aProjection = projections.firstWhere((p) => p.teamId == teamA.id);
    final bProjection = projections.firstWhere((p) => p.teamId == teamB.id);

    expect(aProjection.avgFinalPoints, 3);
    expect(bProjection.avgFinalPoints, 0);
    expect(aProjection.titleProbability, 1.0);
    expect(bProjection.titleProbability, 0.0);
  });

  test(
      'GameState.playNextMatchdayQuickSim resolves the whole matchday without leaving a half-time state',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    final result = await gameState.playNextMatchdayQuickSim();

    expect(result, isNotNull);
    expect(result!.matchday, 1);
    expect(gameState.isHalfTime, isFalse);
    expect(
        gameState.save!.league.fixturesForMatchday(1).any((f) =>
            (f.homeTeamId == gameState.userTeam.id ||
                f.awayTeamId == gameState.userTeam.id) &&
            f.result != null),
        isTrue);
  });

  test(
      'GameState.simulateAheadMatchdays advances several matchdays in order and clears isBusy',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    final results = await gameState.simulateAheadMatchdays(3);

    expect(results.length, 3);
    expect(results.map((r) => r.matchday).toList(), [1, 2, 3]);
    expect(gameState.isBusy, isFalse);
  });

  test(
      'GameState.seasonProjection ranks every league team with valid probabilities',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    final projections = gameState.seasonProjection;

    expect(projections.length, gameState.save!.league.teams.length);
    for (final p in projections) {
      expect(p.titleProbability, inInclusiveRange(0.0, 1.0));
      expect(p.continentalProbability, inInclusiveRange(0.0, 1.0));
      expect(p.relegationProbability, inInclusiveRange(0.0, 1.0));
    }
    for (int i = 1; i < projections.length; i++) {
      expect(projections[i].avgFinalRank,
          greaterThanOrEqualTo(projections[i - 1].avgFinalRank));
    }
  });

  test(
      'MatchEngine.dutyAttackMultiplier/dutyDefenseMultiplier reward the '
      'matching duty and penalize the opposite one', () {
    expect(MatchEngine.dutyAttackMultiplier(PlayerDuty.attack),
        greaterThan(MatchEngine.dutyAttackMultiplier(PlayerDuty.support)));
    expect(MatchEngine.dutyAttackMultiplier(PlayerDuty.defend),
        lessThan(MatchEngine.dutyAttackMultiplier(PlayerDuty.support)));
    expect(MatchEngine.dutyDefenseMultiplier(PlayerDuty.defend),
        greaterThan(MatchEngine.dutyDefenseMultiplier(PlayerDuty.support)));
    expect(MatchEngine.dutyDefenseMultiplier(PlayerDuty.attack),
        lessThan(MatchEngine.dutyDefenseMultiplier(PlayerDuty.support)));
  });

  test(
      'PlayerGenerator assigns duty in correlation with the already-assigned '
      "role's attacking/defensive character, so a defensive-minded "
      'midfield role (anchorMan) ends up with defend duty far more often '
      'than an attacking-minded one (wideMidfielder)', () {
    final anchorDefendCounts = <bool>[];
    final wideDefendCounts = <bool>[];
    for (int i = 0; i < 2000; i++) {
      // Position.dmはtackling/marking/positioningが優遇されるため
      // アンカーマン(tackling+positioning)に、Position.mrはcrossing/pace
      // が優遇されるためワイドMF(crossing+pace)に、それぞれ高確率で
      // ロールが決まる(いずれもMID大分類でデューティ確率式は共通)。
      final dmPlayer =
          PlayerGenerator.generate(position: Position.dm, strengthTier: 60);
      if (dmPlayer.role == PlayerRole.anchorMan) {
        anchorDefendCounts.add(dmPlayer.duty == PlayerDuty.defend);
      }
      final mrPlayer =
          PlayerGenerator.generate(position: Position.mr, strengthTier: 60);
      if (mrPlayer.role == PlayerRole.wideMidfielder) {
        wideDefendCounts.add(mrPlayer.duty == PlayerDuty.defend);
      }
    }
    expect(anchorDefendCounts.length, greaterThan(10));
    expect(wideDefendCounts.length, greaterThan(10));
    final anchorDefendRate =
        anchorDefendCounts.where((b) => b).length / anchorDefendCounts.length;
    final wideDefendRate =
        wideDefendCounts.where((b) => b).length / wideDefendCounts.length;
    expect(anchorDefendRate, greaterThan(wideDefendRate));
  });

  test(
      'MatchEngine.tacticalImpact reflects raising each slider in the '
      'expected direction', () {
    final team = Team(id: 't', name: 'T', players: []);
    final baseline = MatchEngine.tacticalImpact(team);
    expect(baseline.attackMultiplier, 1.0);
    expect(baseline.defenseMultiplier, 1.0);
    expect(baseline.fatigueMultiplier, 1.0);

    team.lineHeight = 90;
    final higherLine = MatchEngine.tacticalImpact(team);
    expect(higherLine.attackMultiplier, greaterThan(baseline.attackMultiplier));
    expect(higherLine.defenseMultiplier, lessThan(baseline.defenseMultiplier));
    team.lineHeight = 50;

    team.width = 90;
    final widerAttack = MatchEngine.tacticalImpact(team);
    expect(
        widerAttack.attackMultiplier, greaterThan(baseline.attackMultiplier));
    expect(widerAttack.defenseMultiplier, lessThan(baseline.defenseMultiplier));
    team.width = 50;

    team.pressing = 90;
    final morePressing = MatchEngine.tacticalImpact(team);
    expect(morePressing.defenseMultiplier,
        greaterThan(baseline.defenseMultiplier));
    expect(morePressing.fatigueMultiplier,
        greaterThan(baseline.fatigueMultiplier));
    team.pressing = 50;

    team.tempo = 90;
    final higherTempo = MatchEngine.tacticalImpact(team);
    expect(
        higherTempo.attackMultiplier, greaterThan(baseline.attackMultiplier));
    expect(
        higherTempo.fatigueMultiplier, greaterThan(baseline.fatigueMultiplier));
  });

  test(
      'MatchEngine.tacticalFitFactor rewards higher attribute averages, and '
      'a high-workRate/high-stamina squad benefits more from aggressive '
      'pressing/tempo than a low one, all else being equal', () {
    expect(MatchEngine.tacticalFitFactor(90),
        greaterThan(MatchEngine.tacticalFitFactor(30)));

    Team buildTeam(int workRate, int stamina) {
      final players = <Player>[];
      for (int i = 0; i < 11; i++) {
        final p = Player(
            id: 'p$i',
            name: 'p$i',
            age: 25,
            position: i == 0 ? Position.gk : Position.mc,
            potential: 80);
        for (final k in AttributeKeys.all) {
          p.setAttributeValue(k, 70);
        }
        p.setAttributeValue(AttributeKeys.workRate, workRate);
        p.setAttributeValue(AttributeKeys.stamina, stamina);
        players.add(p);
      }
      final team = Team(
          id: 't',
          name: 'T',
          players: players,
          startingXI: players.map((p) => p.id).toList());
      team.pressing = 90;
      team.tempo = 90;
      return team;
    }

    final highFitTeam = buildTeam(90, 90);
    final lowFitTeam = buildTeam(20, 20);

    final highImpact = MatchEngine.tacticalImpact(highFitTeam);
    final lowImpact = MatchEngine.tacticalImpact(lowFitTeam);

    expect(
        highImpact.defenseMultiplier, greaterThan(lowImpact.defenseMultiplier));
    expect(
        highImpact.attackMultiplier, greaterThan(lowImpact.attackMultiplier));
  });

  test(
      'MatchEngine.roleMultiplier rewards attributes matching the role and '
      'penalizes a mismatch, while standard is always neutral', () {
    Player make(String id, {required int uniform}) {
      final p = Player(
          id: id, name: id, age: 24, position: Position.st, potential: 70);
      for (final key in AttributeKeys.all) {
        p.setAttributeValue(key, uniform);
      }
      return p;
    }

    final fitted = make('fit', uniform: 50)
      ..role = PlayerRole.poacher
      ..setAttributeValue(AttributeKeys.finishing, 90)
      ..setAttributeValue(AttributeKeys.offTheBall, 90);
    final mismatched = make('mismatch', uniform: 50)
      ..role = PlayerRole.poacher
      ..setAttributeValue(AttributeKeys.finishing, 10)
      ..setAttributeValue(AttributeKeys.offTheBall, 10);
    final standard = make('standard', uniform: 50)..role = PlayerRole.standard;

    expect(
        MatchEngine.roleMultiplier(fitted, forAttack: true), greaterThan(1.0));
    expect(
        MatchEngine.roleMultiplier(mismatched, forAttack: true), lessThan(1.0));
    expect(MatchEngine.roleMultiplier(standard, forAttack: true), 1.0);
  });

  test(
      'MatchEngine.roleMultiplier judges role fit against overall ability, '
      'not just the attack/defense composite for that phase (matching the '
      'threshold PlayerGenerator._pickRole itself uses for assignment)', () {
    final p = Player(
        id: 'role-overall',
        name: 'role-overall',
        age: 24,
        position: Position.mc,
        potential: 90);
    for (final key in AttributeKeys.all) {
      p.setAttributeValue(key, 30);
    }
    // アンカーマンの重視属性(tackling/positioning)は70とほどほどだが、
    // それ以外の守備・技術・フィジカル系の能力値を高くしておくことで、
    // 攻撃力(finishing等が低いまま=低い)より総合力の方が高い選手を作る。
    p.role = PlayerRole.anchorMan;
    p.setAttributeValue(AttributeKeys.tackling, 70);
    p.setAttributeValue(AttributeKeys.positioning, 70);
    for (final key in [
      AttributeKeys.marking,
      AttributeKeys.anticipation,
      AttributeKeys.strength,
      AttributeKeys.aggression,
      AttributeKeys.concentration,
      AttributeKeys.bravery,
      AttributeKeys.passing,
      AttributeKeys.firstTouch,
      AttributeKeys.vision,
      AttributeKeys.technique,
      AttributeKeys.crossing,
      AttributeKeys.decisions,
      AttributeKeys.teamwork,
      AttributeKeys.stamina,
      AttributeKeys.naturalFitness,
      AttributeKeys.workRate,
      AttributeKeys.acceleration,
    ]) {
      p.setAttributeValue(key, 95);
    }

    // 攻撃複合値(finishing等)は30のままなので、基準をp.attackにしていた
    // 旧実装ならroleRating(70)がそれを上回りボーナスになってしまっていた。
    // 総合力(守備・技術・フィジカルが高いため70を上回る)を基準にすることで
    // 正しくペナルティになる。
    expect(p.overall, greaterThan(70));
    expect(MatchEngine.roleMultiplier(p, forAttack: true), lessThan(1.0));
  });

  test(
      'MatchEngine.positionFitMultiplier penalizes off-position starters, '
      'less so for a listed secondary position, and eases with familiarity',
      () {
    final p = Player(
        id: 'p',
        name: 'p',
        age: 24,
        position: Position.mc,
        potential: 70,
        secondaryPositions: [Position.dm]);

    expect(MatchEngine.positionFitMultiplier(p, Position.mc), 1.0);
    expect(MatchEngine.positionFitMultiplier(p, Position.dm), 0.90);
    expect(MatchEngine.positionFitMultiplier(p, Position.st), 0.75);

    p.growFamiliarity(Position.dm, amount: 100);
    p.growFamiliarity(Position.st, amount: 100);
    expect(MatchEngine.positionFitMultiplier(p, Position.dm), 1.0);
    expect(MatchEngine.positionFitMultiplier(p, Position.st), 0.90);
  });

  test(
      'LineupUtils.assignedSlotByPlayerId maps starters to their own position '
      'when possible and to a same-group fallback slot otherwise', () {
    Player make(String id, Position pos) =>
        Player(id: id, name: id, age: 24, position: pos, potential: 70);

    final gk = make('gk', Position.gk);
    final dc1 = make('dc1', Position.dc);
    final dc2 = make('dc2', Position.dc);
    final dr = make('dr', Position.dr);
    final dl = make('dl', Position.dl);
    final mc1 = make('mc1', Position.mc);
    final mc2 = make('mc2', Position.mc);
    final mr = make('mr', Position.mr);
    final ml = make('ml', Position.ml);
    final st = make('st', Position.st);
    // 4-4-2の2枚目のSTが不在で、代わりにMCで代役を務める想定。
    final fallbackSt = make('fallback', Position.mc);

    final team = Team(
      id: 't',
      name: 'T',
      players: [gk, dc1, dc2, dr, dl, mc1, mc2, mr, ml, st, fallbackSt],
      formation: Formation.f442,
      startingXI: [
        gk.id,
        dr.id,
        dc1.id,
        dc2.id,
        dl.id,
        mr.id,
        mc1.id,
        mc2.id,
        ml.id,
        st.id,
        fallbackSt.id,
      ],
    );

    final slotById = LineupUtils.assignedSlotByPlayerId(team);

    expect(slotById[st.id], Position.st);
    expect(slotById[fallbackSt.id], Position.st);
    expect(slotById[mc1.id], Position.mc);
  });

  test(
      'MatchEngine.applyPostMatchEffects grows familiarity only for the '
      'starter filling an unfamiliar slot', () {
    Player make(String id, Position pos) =>
        Player(id: id, name: id, age: 24, position: pos, potential: 70);

    final gk = make('gk', Position.gk);
    final dc1 = make('dc1', Position.dc);
    final dc2 = make('dc2', Position.dc);
    final dr = make('dr', Position.dr);
    final dl = make('dl', Position.dl);
    final mc1 = make('mc1', Position.mc);
    final mc2 = make('mc2', Position.mc);
    final mr = make('mr', Position.mr);
    final ml = make('ml', Position.ml);
    final st = make('st', Position.st);
    final fallbackSt = make('fallback', Position.mc);
    final home = Team(
      id: 'home',
      name: 'Home',
      players: [gk, dc1, dc2, dr, dl, mc1, mc2, mr, ml, st, fallbackSt],
      formation: Formation.f442,
      startingXI: [
        gk.id,
        dr.id,
        dc1.id,
        dc2.id,
        dl.id,
        mr.id,
        mc1.id,
        mc2.id,
        ml.id,
        st.id,
        fallbackSt.id,
      ],
    );
    final away = PlayerGenerator.generateSquad(
        id: 'away', name: 'Away FC', strengthTier: 60);
    LineupUtils.autoFill(away);

    expect(fallbackSt.familiarityFor(Position.st), 0);
    expect(st.familiarityFor(Position.st), 100);

    MatchEngine.applyPostMatchEffects(home: home, away: away);

    expect(fallbackSt.familiarityFor(Position.st), greaterThan(0));
    expect(mc1.familiarityFor(Position.mc), 100);
  });

  test(
      'MatchEngine.applyPostMatchEffects raises sharpness for starters and '
      'lowers it (with a floor) for the rest of the squad', () {
    final home = PlayerGenerator.generateSquad(
        id: 'home', name: 'Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'away', name: 'Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);
    for (final p in home.players) {
      p.matchSharpness = 50;
    }
    final starterIds = home.startingXI.toSet();

    MatchEngine.applyPostMatchEffects(home: home, away: away);

    for (final p in home.players) {
      if (starterIds.contains(p.id)) {
        expect(p.matchSharpness, 56);
      } else {
        expect(p.matchSharpness, 47);
      }
    }
  });

  test('GameState.setPlayerRole updates the player\'s role', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;

    gameState.setPlayerRole(player.id, PlayerRole.playmaker);

    expect(player.role, PlayerRole.playmaker);
  });

  test(
      'GameState tactic presets can be saved, applied, and deleted, and are '
      'capped at maxTacticPresets by evicting the oldest', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    team.formation = Formation.f442;
    team.pressing = 30;
    team.lineHeight = 30;
    team.width = 30;
    team.tempo = 30;

    gameState.saveTacticPreset('守備的');
    team.formation = Formation.f433;
    team.pressing = 80;
    team.lineHeight = 80;
    team.width = 80;
    team.tempo = 80;

    gameState.applyTacticPreset('守備的');
    expect(team.formation, Formation.f442);
    expect(team.pressing, 30);
    expect(team.width, 30);

    gameState.deleteTacticPreset('守備的');
    expect(team.tacticPresets, isEmpty);

    for (int i = 0; i < maxTacticPresets + 1; i++) {
      gameState.saveTacticPreset('preset$i');
    }
    expect(team.tacticPresets.length, maxTacticPresets);
    expect(team.tacticPresets.map((p) => p.name), isNot(contains('preset0')));
  });

  test(
      'GameState.playNextMatchday resets match sharpness for players who '
      'just recovered from injury', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final injured = gameState.userTeam.players.first;
    injured.injuryWeeks = 1;
    injured.matchSharpness = 90;

    await gameState.playNextMatchday();

    expect(injured.injuryWeeks, 0);
    expect(injured.matchSharpness, lessThanOrEqualTo(40));
  });

  test(
      'Team.depthChartFor sorts by overall by default and honors a manual '
      'override, self-healing when players leave or join', () {
    Player make(String id, int overall) {
      final p = Player(
          id: id, name: id, age: 20, position: Position.mc, potential: 70);
      for (final key in AttributeKeys.all) {
        p.setAttributeValue(key, overall);
      }
      return p;
    }

    final a = make('a', 60);
    final b = make('b', 80);
    final c = make('c', 70);
    final team = Team(id: 't', name: 'T', players: [a, b, c]);

    expect(team.depthChartFor(Position.mc).map((p) => p.id), ['b', 'c', 'a']);

    team.depthChartOrder[Position.mc.name] = ['a', 'b', 'c'];
    expect(team.depthChartFor(Position.mc).map((p) => p.id), ['a', 'b', 'c']);

    team.players = [a, c];
    expect(team.depthChartFor(Position.mc).map((p) => p.id), ['a', 'c']);

    final d = make('d', 90);
    team.players = [a, c, d];
    expect(team.depthChartFor(Position.mc).map((p) => p.id), ['a', 'c', 'd']);
  });

  test('GameState.reorderDepthChart moves a player to the given index',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    final gks = team.depthChartFor(Position.gk).map((p) => p.id).toList();
    if (gks.length < 2) return;

    gameState.reorderDepthChart(Position.gk, 0, 1);

    final reordered = team.depthChartFor(Position.gk).map((p) => p.id);
    expect(reordered.first, gks[1]);
    expect(reordered.elementAt(1), gks[0]);
  });

  test('YouthScreen.filterAndSort filters by search query and sorts', () {
    Player make(String id, {required int age, required int potential}) {
      final p = Player(
          id: id,
          name: id,
          age: age,
          position: Position.mc,
          potential: potential);
      for (final key in AttributeKeys.all) {
        p.setAttributeValue(key, 50);
      }
      return p;
    }

    final young = make('young', age: 17, potential: 90);
    final old = make('old', age: 25, potential: 55);
    final all = [old, young];

    expect(YouthScreen.filterAndSort(all, sort: YouthSortOption.age).first.id,
        'young');
    expect(
        YouthScreen.filterAndSort(all, sort: YouthSortOption.potential)
            .first
            .id,
        'young');
    expect(
        YouthScreen.filterAndSort(all, sort: YouthSortOption.wonderkidGap)
            .first
            .id,
        'young');

    final searched = YouthScreen.filterAndSort(all, query: 'young');
    expect(searched.map((p) => p.id), ['young']);
  });

  test(
      'glossaryEntries has a non-empty, unique explanation for every '
      'attribute key and no blank descriptions anywhere', () {
    final byTerm = <String, List<GlossaryEntry>>{};
    for (final e in glossaryEntries) {
      expect(e.description, isNotEmpty, reason: '${e.term} has no description');
      byTerm.putIfAbsent(e.term, () => []).add(e);
    }
    for (final key in AttributeKeys.all) {
      final label = AttributeKeys.labelOf(key);
      expect(byTerm.containsKey(label), isTrue,
          reason: 'missing glossary entry for $label ($key)');
    }
    expect(byTerm.values.every((v) => v.length == 1), isTrue,
        reason: 'duplicate glossary terms found');
  });

  test('GlossaryScreen.filter filters by category and search query', () {
    final attributeCount = glossaryEntries
        .where((e) => e.category == GlossaryCategory.attribute)
        .length;
    expect(attributeCount, AttributeKeys.all.length);

    final byCategory = GlossaryScreen.filter(glossaryEntries,
        category: GlossaryCategory.tactics);
    expect(byCategory, isNotEmpty);
    expect(byCategory.every((e) => e.category == GlossaryCategory.tactics),
        isTrue);

    final searched = GlossaryScreen.filter(glossaryEntries, query: 'マッチシャープネス');
    expect(searched.map((e) => e.term), contains('マッチシャープネス'));

    final none = GlossaryScreen.filter(glossaryEntries, query: '存在しない用語123');
    expect(none, isEmpty);
  });

  test(
      'guideSections has a non-empty overview and at least one non-empty '
      'topic for every screen, and includes every player personality type', () {
    expect(guideSections, isNotEmpty);
    for (final section in guideSections) {
      expect(section.title, isNotEmpty);
      expect(section.overview, isNotEmpty);
      expect(section.topics, isNotEmpty,
          reason: '${section.title} has no topics');
      for (final topic in section.topics) {
        expect(topic.title, isNotEmpty,
            reason: '${section.title} has a topic with no title');
        expect(topic.description, isNotEmpty,
            reason: '${section.title}/${topic.title} has no description');
      }
    }

    final squadSection =
        guideSections.firstWhere((s) => s.title == 'スカッド・選手詳細画面');
    final topicTitles = squadSection.topics.map((t) => t.title).toSet();
    for (final p in PlayerPersonality.values) {
      expect(topicTitles, contains(p.label),
          reason: 'missing guide topic for personality ${p.label}');
    }
  });

  Player makeFreshPlayer({
    int age = 24,
    int potential = 99,
    int determination = 50,
    int matchSharpness = 80,
    Position position = Position.st,
  }) {
    final p = Player(
        id: 'p-${identityHashCode(Object())}',
        name: 'p',
        age: age,
        position: position,
        potential: potential,
        matchSharpness: matchSharpness);
    for (final k in AttributeKeys.all) {
      p.setAttributeValue(k, 50);
    }
    p.setAttributeValue(AttributeKeys.determination, determination);
    return p;
  }

  /// 全選手の全属性を[level]で揃えた11人の先発チームを作る。
  /// overall(総合力)が確実に[level]前後になるため、対戦相手の実力に応じた
  /// 選手特性(例: bigGameHunter/bullyBall)のテストで、生成のランダム性に
  /// 左右されない決定的なチーム総合力を用意するために使う。
  Team makeUniformTeam(String id, int level) {
    const positions = [
      Position.gk,
      Position.dl,
      Position.dc,
      Position.dc,
      Position.dr,
      Position.ml,
      Position.mc,
      Position.mc,
      Position.mr,
      Position.st,
      Position.st,
    ];
    final players = [
      for (final pos in positions) makeFreshPlayer(position: pos, potential: 99)
    ];
    for (final p in players) {
      for (final k in AttributeKeys.all) {
        p.setAttributeValue(k, level);
      }
    }
    final team = Team(id: id, name: '$id FC', players: players);
    team.formation = Formation.f442;
    team.startingXI = players.map((p) => p.id).toList();
    return team;
  }

  int countStaminaGrowths(int trials, Player Function() makePlayer) {
    var growths = 0;
    for (int i = 0; i < trials; i++) {
      final p = makePlayer();
      final team = Team(
          id: 't',
          name: 'T',
          players: [p],
          defaultTrainingFocus: TrainingFocus.fitness);
      TrainingEngine.applyWeeklyTraining(team);
      if (p.attributeValue(AttributeKeys.stamina) > 50) growths++;
    }
    return growths;
  }

  test(
      'TrainingEngine growth chance scales with determination: high '
      'determination players grow noticeably faster than low ones', () {
    final high =
        countStaminaGrowths(400, () => makeFreshPlayer(determination: 99));
    final low =
        countStaminaGrowths(400, () => makeFreshPlayer(determination: 1));
    expect(high, greaterThan(low));
  });

  test(
      'TrainingEngine growth chance is dampened for players with low match '
      'sharpness (little playing time)', () {
    final sharp =
        countStaminaGrowths(400, () => makeFreshPlayer(matchSharpness: 90));
    final stale =
        countStaminaGrowths(400, () => makeFreshPlayer(matchSharpness: 20));
    expect(sharp, greaterThan(stale));
  });

  test(
      'GameState.setMentor rejects self-mentoring and under-age mentors, '
      'and a valid mentor boosts the mentee\'s growth chance', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    final mentee = team.players.first;
    final tooYoung = team.players.firstWhere(
        (p) => p.id != mentee.id && p.age < TrainingEngine.minMentorAge,
        orElse: () => team.players[1]);
    tooYoung.age = 20;

    expect(gameState.setMentor(mentee.id, mentee.id), isFalse);
    expect(gameState.setMentor(mentee.id, tooYoung.id), isFalse);
    expect(mentee.mentorId, isNull);

    final veteran = team.players.firstWhere((p) => p.id != mentee.id);
    veteran.age = 30;
    expect(gameState.setMentor(mentee.id, veteran.id), isTrue);
    expect(mentee.mentorId, veteran.id);

    expect(gameState.setMentor(mentee.id, null), isTrue);
    expect(mentee.mentorId, isNull);
  });

  test('a valid mentor increases the mentee\'s training growth chance', () {
    int countWithMentor(bool withMentor) {
      var growths = 0;
      for (int i = 0; i < 400; i++) {
        final mentee = makeFreshPlayer();
        final mentor = makeFreshPlayer(age: 32);
        if (withMentor) mentee.mentorId = mentor.id;
        final team = Team(
            id: 't',
            name: 'T',
            players: [mentee, mentor],
            defaultTrainingFocus: TrainingFocus.fitness);
        TrainingEngine.applyWeeklyTraining(team);
        if (mentee.attributeValue(AttributeKeys.stamina) > 50) growths++;
      }
      return growths;
    }

    final withMentor = countWithMentor(true);
    final withoutMentor = countWithMentor(false);
    expect(withMentor, greaterThan(withoutMentor));
  });

  test(
      'a mentor gains a small happiness boost after a week of valid '
      'mentoring', () {
    final mentee = makeFreshPlayer();
    final mentor = makeFreshPlayer(age: 32);
    mentee.mentorId = mentor.id;
    mentor.happiness = 70;
    final team = Team(id: 't', name: 'T', players: [mentee, mentor]);
    TrainingEngine.applyWeeklyTraining(team);
    expect(mentor.happiness, 71);
  });

  test(
      'TrainingFocus.positionSwitch grows familiarity for secondary '
      'positions without requiring a match appearance', () {
    final p = makeFreshPlayer(position: Position.mc);
    p.secondaryPositions = [Position.amc];
    final team = Team(
        id: 't',
        name: 'T',
        players: [p],
        defaultTrainingFocus: TrainingFocus.positionSwitch);
    for (int i = 0; i < 30 && p.familiarityFor(Position.amc) == 0; i++) {
      TrainingEngine.applyWeeklyTraining(team);
    }
    expect(p.familiarityFor(Position.amc), greaterThan(0));
  });

  test(
      'TrainingIntensity changes fatigue gain deterministically: intense > '
      'normal > light', () {
    int fatigueAfter(TrainingIntensity intensity) {
      final p = makeFreshPlayer();
      final team = Team(
          id: 't',
          name: 'T',
          players: [p],
          defaultTrainingFocus: TrainingFocus.attack,
          trainingIntensity: intensity);
      TrainingEngine.applyWeeklyTraining(team);
      return p.fatigue;
    }

    final light = fatigueAfter(TrainingIntensity.light);
    final normal = fatigueAfter(TrainingIntensity.normal);
    final intense = fatigueAfter(TrainingIntensity.intense);
    expect(intense, greaterThan(normal));
    expect(normal, greaterThan(light));
  });

  test(
      'high-intensity training with poor natural fitness produces at least '
      'some minor training injuries over many weeks', () {
    var injuries = 0;
    for (int i = 0; i < 500; i++) {
      final p = makeFreshPlayer();
      p.setAttributeValue(AttributeKeys.naturalFitness, 1);
      p.fatigue = 90;
      final team = Team(
          id: 't',
          name: 'T',
          players: [p],
          defaultTrainingFocus: TrainingFocus.attack,
          trainingIntensity: TrainingIntensity.intense);
      TrainingEngine.applyWeeklyTraining(team);
      if (p.injuryWeeks > 0) injuries++;
    }
    expect(injuries, greaterThan(0));
  });

  test(
      'TrainingEngine._decline is biased toward goalkeeping attributes for '
      'goalkeepers versus outfield players', () {
    int goalkeepingDeclines(Position position) {
      var count = 0;
      for (int i = 0; i < 2500; i++) {
        final p = makeFreshPlayer(position: position, age: 33);
        final before = {
          for (final k in AttributeKeys.all) k: p.attributeValue(k)
        };
        final team = Team(id: 't', name: 'T', players: [p]);
        TrainingEngine.applyWeeklyTraining(team);
        for (final k in AttributeKeys.goalkeeping) {
          if (p.attributeValue(k) < before[k]!) {
            count++;
            break;
          }
        }
      }
      return count;
    }

    final gkDeclines = goalkeepingDeclines(Position.gk);
    final outfieldDeclines = goalkeepingDeclines(Position.st);
    expect(gkDeclines, greaterThan(outfieldDeclines));
  });

  test(
      'MatchEngine.applyPostMatchEffects grows mental attributes for '
      'players through match experience over many matches', () {
    var growths = 0;
    for (int i = 0; i < 500; i++) {
      final home = PlayerGenerator.generateSquad(
          id: 'home', name: 'Home FC', strengthTier: 60);
      final away = PlayerGenerator.generateSquad(
          id: 'away', name: 'Away FC', strengthTier: 60);
      LineupUtils.autoFill(home);
      LineupUtils.autoFill(away);
      final p =
          home.players.firstWhere((pl) => home.startingXI.contains(pl.id));
      final before = {
        for (final k in TrainingEngine.matchExperienceGrowthKeys)
          k: p.attributeValue(k)
      };
      MatchEngine.applyPostMatchEffects(home: home, away: away);
      if (TrainingEngine.matchExperienceGrowthKeys
          .any((k) => p.attributeValue(k) > before[k]!)) {
        growths++;
      }
    }
    expect(growths, greaterThan(0));
  });

  test('GameState.setDrillAttribute sets and clears the drill attribute',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;

    gameState.setDrillAttribute(player.id, AttributeKeys.finishing);
    expect(player.drillAttributeKey, AttributeKeys.finishing);

    gameState.setDrillAttribute(player.id, null);
    expect(player.drillAttributeKey, isNull);
  });

  test(
      'GameState.setPlayerTrainingConvertTarget lets a player convert to a '
      "brand-new position not among their generated secondaryPositions",
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player =
        gameState.userTeam.players.firstWhere((p) => p.position == Position.mc);
    player.secondaryPositions = [];
    player.individualFocus = TrainingFocus.positionSwitch;

    gameState.setPlayerTrainingConvertTarget(player.id, Position.dm);
    expect(player.trainingConvertTargetPosition, Position.dm.name);
    expect(player.canPlay(Position.dm), isFalse);

    // 慣れ度が上限に達すると、実際に起用可能な副ポジションへ昇格するはず。
    player.positionFamiliarity[Position.dm.name] = 100;
    await gameState.runWeeklyTraining();

    expect(player.secondaryPositions, contains(Position.dm));
    expect(player.canPlay(Position.dm), isTrue);
    expect(player.trainingConvertTargetPosition, isNull);
  });

  test('GameState.addDebugFunds increases or decreases the club budget',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final before = gameState.save!.budget;

    gameState.addDebugFunds(50000);
    expect(gameState.save!.budget, before + 50000);

    gameState.addDebugFunds(-20000);
    expect(gameState.save!.budget, before + 30000);
  });

  test('a drill attribute grows noticeably more often than an undrilled one',
      () {
    int countFinishingGrowths(bool withDrill) {
      var growths = 0;
      for (int i = 0; i < 400; i++) {
        final p = makeFreshPlayer();
        if (withDrill) p.drillAttributeKey = AttributeKeys.finishing;
        final team = Team(
            id: 't',
            name: 'T',
            players: [p],
            defaultTrainingFocus: TrainingFocus.rest);
        TrainingEngine.applyWeeklyTraining(team);
        if (p.attributeValue(AttributeKeys.finishing) > 50) growths++;
      }
      return growths;
    }

    final withDrill = countFinishingGrowths(true);
    final withoutDrill = countFinishingGrowths(false);
    expect(withDrill, greaterThan(withoutDrill));
  });

  test(
      'a second drill slot (drillAttributeKey2) grows its attribute more '
      'often than an undrilled one, at a reduced rate vs the first slot', () {
    int countPassingGrowths(bool withDrill) {
      var growths = 0;
      for (int i = 0; i < 400; i++) {
        final p = makeFreshPlayer();
        if (withDrill) p.drillAttributeKey2 = AttributeKeys.passing;
        final team = Team(
            id: 't',
            name: 'T',
            players: [p],
            defaultTrainingFocus: TrainingFocus.rest);
        TrainingEngine.applyWeeklyTraining(team);
        if (p.attributeValue(AttributeKeys.passing) > 50) growths++;
      }
      return growths;
    }

    final withDrill = countPassingGrowths(true);
    final withoutDrill = countPassingGrowths(false);
    expect(withDrill, greaterThan(withoutDrill));
  });

  test(
      'drillAttributeKey and drillAttributeKey2 grow independently on the '
      'same player', () {
    var bothGrowths = 0;
    for (int i = 0; i < 400; i++) {
      final p = makeFreshPlayer();
      p.drillAttributeKey = AttributeKeys.finishing;
      p.drillAttributeKey2 = AttributeKeys.passing;
      final team = Team(
          id: 't',
          name: 'T',
          players: [p],
          defaultTrainingFocus: TrainingFocus.rest);
      TrainingEngine.applyWeeklyTraining(team);
      if (p.attributeValue(AttributeKeys.finishing) > 50 &&
          p.attributeValue(AttributeKeys.passing) > 50) {
        bothGrowths++;
      }
    }
    expect(bothGrowths, greaterThan(0));
  });

  test(
      'GameState.setDrillAttribute2 respects maxDrillSlots independently '
      'from setDrillAttribute', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final players = gameState.userTeam.players;
    expect(gameState.maxDrillSlots, 1);

    final p0 = players[0];
    final p1 = players[1];

    expect(gameState.setDrillAttribute(p0.id, AttributeKeys.finishing), isTrue);
    expect(
        gameState.setDrillAttribute(p1.id, AttributeKeys.finishing), isFalse);

    // 1つ目のドリル枠が埋まっていても、2つ目のドリル枠は独立してp0に設定できる。
    expect(gameState.setDrillAttribute2(p0.id, AttributeKeys.passing), isTrue);
    // 2つ目のドリル枠も上限に達したら、別の選手への新規指定は失敗する。
    expect(gameState.setDrillAttribute2(p1.id, AttributeKeys.passing), isFalse);

    gameState.setDrillAttribute2(p0.id, null);
    expect(p0.drillAttributeKey2, isNull);
  });

  test(
      'TrainingEngine._rollTraitAcquisition grants exactly the targeted '
      'trait only when traitTrainingTarget is set and the player has no '
      'trait yet', () {
    int countAcquisitions(bool enabled, {bool alreadyHasTrait = false}) {
      var count = 0;
      for (int i = 0; i < 1500; i++) {
        final p = makeFreshPlayer(determination: 99);
        p.traitTrainingTarget = enabled ? PlayerTrait.clinicalFinisher : null;
        if (alreadyHasTrait) p.trait = PlayerTrait.giantKiller;
        final team = Team(
            id: 't',
            name: 'T',
            players: [p],
            defaultTrainingFocus: TrainingFocus.rest);
        TrainingEngine.applyWeeklyTraining(team);
        if (p.trait != null && !alreadyHasTrait) {
          expect(p.trait, PlayerTrait.clinicalFinisher);
          count++;
        }
      }
      return count;
    }

    final enabledCount = countAcquisitions(true);
    final disabledCount = countAcquisitions(false);
    final alreadyHasTraitCount = countAcquisitions(true, alreadyHasTrait: true);

    expect(enabledCount, greaterThan(0));
    expect(disabledCount, 0);
    expect(alreadyHasTraitCount, 0);
  });

  test(
      'TrainingEngine.traitSuitability scales attribute-based trait chances '
      'so a well-suited player acquires the targeted trait faster than a '
      'poorly-suited one', () {
    int countAcquisitions(int finishingValue) {
      var count = 0;
      for (int i = 0; i < 800; i++) {
        final p = makeFreshPlayer(determination: 99);
        p.setAttributeValue(AttributeKeys.finishing, finishingValue);
        p.traitTrainingTarget = PlayerTrait.clinicalFinisher;
        final team = Team(
            id: 't',
            name: 'T',
            players: [p],
            defaultTrainingFocus: TrainingFocus.rest);
        TrainingEngine.applyWeeklyTraining(team);
        if (p.trait != null) count++;
      }
      return count;
    }

    final wellSuited = countAcquisitions(95);
    final poorlySuited = countAcquisitions(10);
    expect(wellSuited, greaterThan(poorlySuited));
  });

  test(
      'a player who acquires a trait via training has acquiredTraitThisWeek '
      'set to match the targeted trait, and it resets the following week', () {
    Player? acquirer;
    for (int i = 0; i < 1500; i++) {
      final p = makeFreshPlayer(determination: 99);
      p.traitTrainingTarget = PlayerTrait.clinicalFinisher;
      final team = Team(
          id: 't',
          name: 'T',
          players: [p],
          defaultTrainingFocus: TrainingFocus.rest);
      TrainingEngine.applyWeeklyTraining(team);
      if (p.trait != null) {
        acquirer = p;
        break;
      }
    }
    expect(acquirer, isNotNull);
    expect(acquirer!.trait, PlayerTrait.clinicalFinisher);
    expect(acquirer.acquiredTraitThisWeek, acquirer.trait);

    // 翌週は特性を既に保有しているため一時フラグはリセットされ、再度は付与されない。
    final team = Team(
        id: 't',
        name: 'T',
        players: [acquirer],
        defaultTrainingFocus: TrainingFocus.rest);
    TrainingEngine.applyWeeklyTraining(team);
    expect(acquirer.acquiredTraitThisWeek, isNull);
  });

  test(
      'GameState.setTraitTrainingTarget sets and clears the targeted trait '
      'on the target player', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    expect(player.traitTrainingTarget, isNull);

    gameState.setTraitTrainingTarget(player.id, PlayerTrait.clinicalFinisher);
    expect(player.traitTrainingTarget, PlayerTrait.clinicalFinisher);

    gameState.setTraitTrainingTarget(player.id, null);
    expect(player.traitTrainingTarget, isNull);
  });

  test(
      'PlayerTrait.category classifies all 54 traits into exactly 19 '
      'technical, 20 personality and 15 talent traits', () {
    final byCategory = <PlayerTraitCategory, int>{};
    for (final t in PlayerTrait.values) {
      byCategory[t.category] = (byCategory[t.category] ?? 0) + 1;
    }
    expect(byCategory[PlayerTraitCategory.technical], 19);
    expect(byCategory[PlayerTraitCategory.personality], 20);
    expect(byCategory[PlayerTraitCategory.talent], 15);
  });

  test(
      'GameState.setTraitTrainingTarget ignores non-technical traits '
      '(personality/talent traits cannot be trained via drills)', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;

    gameState.setTraitTrainingTarget(player.id, PlayerTrait.giantKiller);
    expect(player.traitTrainingTarget, isNull);

    gameState.setTraitTrainingTarget(player.id, PlayerTrait.wonderkid);
    expect(player.traitTrainingTarget, isNull);
  });

  test(
      'GameState.setPersonalityTraitTrainingTarget sets/clears a personality '
      'trait target and ignores non-personality traits', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    expect(player.personalityTraitTrainingTarget, isNull);

    gameState.setPersonalityTraitTrainingTarget(
      player.id,
      PlayerTrait.warriorSpirit,
    );
    expect(player.personalityTraitTrainingTarget, PlayerTrait.warriorSpirit);

    gameState.setPersonalityTraitTrainingTarget(player.id, null);
    expect(player.personalityTraitTrainingTarget, isNull);

    gameState.setPersonalityTraitTrainingTarget(
      player.id,
      PlayerTrait.clinicalFinisher,
    );
    expect(player.personalityTraitTrainingTarget, isNull);
    gameState.setPersonalityTraitTrainingTarget(
      player.id,
      PlayerTrait.wonderkid,
    );
    expect(player.personalityTraitTrainingTarget, isNull);
  });

  test(
      'personality trait acquisition never happens without a mentor or a '
      "manager's talk this week, even when a personality target is set", () {
    var count = 0;
    for (int i = 0; i < 500; i++) {
      final p = makeFreshPlayer(determination: 99);
      p.personalityTraitTrainingTarget = PlayerTrait.warriorSpirit;
      final team = Team(
          id: 't',
          name: 'T',
          players: [p],
          defaultTrainingFocus: TrainingFocus.rest);
      TrainingEngine.applyWeeklyTraining(team);
      if (p.trait != null) count++;
    }
    expect(count, 0);
  });

  test(
      'a mentor grants personality trait acquisition a nonzero chance, and '
      'the acquired trait exactly matches the targeted personality trait', () {
    Player? acquirer;
    for (int i = 0; i < 2000; i++) {
      final p = makeFreshPlayer(determination: 99);
      p.setAttributeValue(AttributeKeys.determination, 99);
      p.personalityTraitTrainingTarget = PlayerTrait.warriorSpirit;
      final mentor = makeFreshPlayer(age: 32);
      p.mentorId = mentor.id;
      final team = Team(
          id: 't',
          name: 'T',
          players: [p, mentor],
          defaultTrainingFocus: TrainingFocus.rest);
      TrainingEngine.applyWeeklyTraining(team);
      if (p.trait != null) {
        acquirer = p;
        break;
      }
    }
    expect(acquirer, isNotNull);
    expect(acquirer!.trait, PlayerTrait.warriorSpirit);
    expect(acquirer.acquiredTraitThisWeek, PlayerTrait.warriorSpirit);
  });

  test(
      "a manager's talk this week (fresh talkCooldownWeeks) also grants "
      'personality trait acquisition a nonzero chance without any mentor', () {
    Player? acquirer;
    for (int i = 0; i < 2000; i++) {
      final p = makeFreshPlayer(determination: 99);
      p.personalityTraitTrainingTarget = PlayerTrait.warriorSpirit;
      p.talkCooldownWeeks = TrainingEngine.talkCooldownWeeks;
      final team = Team(
          id: 't',
          name: 'T',
          players: [p],
          defaultTrainingFocus: TrainingFocus.rest);
      TrainingEngine.applyWeeklyTraining(team);
      if (p.trait != null) {
        acquirer = p;
        break;
      }
    }
    expect(acquirer, isNotNull);
    expect(acquirer!.trait, PlayerTrait.warriorSpirit);
  });

  test(
      'Player.fromJson drops a stale traitTrainingTarget/'
      'personalityTraitTrainingTarget whose category no longer matches the '
      'field (e.g. from a save predating trait categories)', () {
    final player = makeFreshPlayer();
    final json = player.toJson();
    json['traitTrainingTarget'] = PlayerTrait.giantKiller.name;
    json['personalityTraitTrainingTarget'] = PlayerTrait.clinicalFinisher.name;
    final restored = Player.fromJson(json);
    expect(restored.traitTrainingTarget, isNull);
    expect(restored.personalityTraitTrainingTarget, isNull);
  });

  test(
      'Player/Team round-trip through JSON preserves '
      'personalityTraitTrainingTarget', () {
    final player = makeFreshPlayer()
      ..personalityTraitTrainingTarget = PlayerTrait.calmHead;
    final restored = Player.fromJson(player.toJson());
    expect(restored.personalityTraitTrainingTarget, PlayerTrait.calmHead);
  });

  test(
      'a player with a focusRotation cycles through the listed foci weekly, '
      'taking priority over individualFocus', () {
    final p = makeFreshPlayer();
    p.individualFocus = TrainingFocus.fitness;
    p.focusRotation = [TrainingFocus.attack, TrainingFocus.rest];
    final team = Team(id: 't', name: 'T', players: [p]);

    final fatigueBefore1 = p.fatigue;
    TrainingEngine.applyWeeklyTraining(team);
    // 1週目はローテーションの1番目(attack)が適用され、疲労は増加するはず。
    expect(p.fatigue, greaterThan(fatigueBefore1));
    expect(p.rotationWeekIndex, 1);

    p.fatigue = 80;
    TrainingEngine.applyWeeklyTraining(team);
    // 2週目はローテーションの2番目(rest)が適用され、疲労は大きく減少するはず。
    expect(p.fatigue, lessThan(80));
    expect(p.rotationWeekIndex, 0);
  });

  test(
      'GameState.setPlayerFocusRotation sets and clears the rotation, '
      'resetting the week index', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;

    gameState.setPlayerFocusRotation(
        player.id, [TrainingFocus.attack, TrainingFocus.defense]);
    expect(player.focusRotation, [TrainingFocus.attack, TrainingFocus.defense]);
    player.rotationWeekIndex = 1;

    gameState.setPlayerFocusRotation(player.id, null);
    expect(player.focusRotation, isNull);
    expect(player.rotationWeekIndex, 0);
  });

  test(
      'a loaned-out player does not receive the parent club\'s facility '
      'growth bonus', () {
    int countStaminaGrowthsWithHeadCoach(bool isLoanedOut) {
      var growths = 0;
      for (int i = 0; i < 400; i++) {
        final p = makeFreshPlayer();
        if (isLoanedOut) p.loanedOutWeeksRemaining = 4;
        final team = Team(
            id: 't',
            name: 'T',
            players: [p],
            defaultTrainingFocus: TrainingFocus.fitness);
        TrainingEngine.applyWeeklyTraining(team,
            headCoachLevel: 5, trainingGroundLevel: 5);
        if (p.attributeValue(AttributeKeys.stamina) > 50) growths++;
      }
      return growths;
    }

    final loanedOut = countStaminaGrowthsWithHeadCoach(true);
    final notLoanedOut = countStaminaGrowthsWithHeadCoach(false);
    expect(notLoanedOut, greaterThan(loanedOut));
  });

  test(
      'TrainingEngine.applyYouthAcademyGrowth grows youth prospects faster '
      'at a higher youth facility level', () {
    int countFinishingGrowths(int facilityLevel) {
      var growths = 0;
      for (int i = 0; i < 400; i++) {
        final p = makeFreshPlayer();
        TrainingEngine.applyYouthAcademyGrowth([p], facilityLevel);
        if (p.attributeValue(AttributeKeys.finishing) > 50) growths++;
      }
      return growths;
    }

    final atLevel1 = countFinishingGrowths(1);
    final atLevel5 = countFinishingGrowths(5);
    expect(atLevel5, greaterThan(atLevel1));
    expect(
      TrainingEngine.youthAcademyGrowthFactor(5),
      greaterThan(TrainingEngine.youthAcademyGrowthFactor(1)),
    );
  });

  test(
      'GameState.playNextMatchday grows a youth prospect while it waits in '
      'the academy', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.budget = ScoutingEngine.scoutCost;
    final candidateId = gameState.scoutCandidates.first.id;
    await gameState.scoutProspect(candidateId);
    final prospect = gameState.save!.youthProspects.first;
    for (final k in AttributeKeys.all) {
      prospect.setAttributeValue(k, 50);
    }
    prospect.potential = 99;
    final overallBefore = prospect.overall;

    for (int i = 0; i < 20; i++) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
    }

    expect(gameState.save!.youthProspects.first.overall,
        greaterThan(overallBefore));
  });

  test(
      'ManagerCareerEngine.levelFor rises with accumulated career XP and '
      'growthBonusFor scales accordingly', () {
    final lowXp = ManagerCareerEngine.xpFor(
        careerWins: 5,
        careerDraws: 2,
        trophyCount: 0,
        unlockedAchievementCount: 0);
    final highXp = ManagerCareerEngine.xpFor(
        careerWins: 500,
        careerDraws: 100,
        trophyCount: 10,
        unlockedAchievementCount: 20);

    final lowLevel = ManagerCareerEngine.levelFor(lowXp);
    final highLevel = ManagerCareerEngine.levelFor(highXp);

    expect(lowLevel, 1);
    expect(highLevel, greaterThan(lowLevel));
    expect(highLevel, lessThanOrEqualTo(ManagerCareerEngine.maxLevel));
    expect(ManagerCareerEngine.growthBonusFor(highLevel),
        greaterThan(ManagerCareerEngine.growthBonusFor(lowLevel)));
    // 最大レベルに達すると経験値の残りは0になる。
    final maxXp = ManagerCareerEngine.xpFor(
        careerWins: 100000,
        careerDraws: 0,
        trophyCount: 0,
        unlockedAchievementCount: 0);
    expect(ManagerCareerEngine.levelFor(maxXp), ManagerCareerEngine.maxLevel);
    expect(ManagerCareerEngine.xpToNextLevel(maxXp), 0);
  });

  test(
      'GameState.managerCareerGrowthBonus rises with career wins and speeds '
      'up weekly training growth', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final bonusAtStart = gameState.managerCareerGrowthBonus;

    gameState.save!.careerWins = 1000;

    expect(gameState.managerCareerGrowthBonus, greaterThan(bonusAtStart));
    expect(gameState.managerCareerLevel, greaterThan(1));
  });

  test(
      'Player.marketValue rewards professional/ambitious personalities and '
      'discounts temperamental ones, all else being equal', () {
    Player makePlayerWithPersonality(PlayerPersonality personality) {
      final p = Player(
          id: 'p-$personality',
          name: 'p',
          age: 25,
          position: Position.st,
          potential: 80);
      for (final k in AttributeKeys.all) {
        p.setAttributeValue(k, 70);
      }
      p.personality = personality;
      return p;
    }

    final professional =
        makePlayerWithPersonality(PlayerPersonality.professional);
    final balanced = makePlayerWithPersonality(PlayerPersonality.balanced);
    final temperamental =
        makePlayerWithPersonality(PlayerPersonality.temperamental);

    expect(professional.marketValue, greaterThan(balanced.marketValue));
    expect(balanced.marketValue, greaterThan(temperamental.marketValue));
  });

  test('Player.marketValue rises with leadership, all else being equal', () {
    final lowLeadership = Player(
        id: 'p1', name: 'p', age: 25, position: Position.st, potential: 80);
    final highLeadership = Player(
        id: 'p2', name: 'p', age: 25, position: Position.st, potential: 80);
    for (final k in AttributeKeys.all) {
      lowLeadership.setAttributeValue(k, 70);
      highLeadership.setAttributeValue(k, 70);
    }
    lowLeadership.setAttributeValue(AttributeKeys.leadership, 20);
    highLeadership.setAttributeValue(AttributeKeys.leadership, 90);

    expect(highLeadership.marketValue, greaterThan(lowLeadership.marketValue));
  });

  test(
      'a professional personality grows an attribute more often than a '
      'temperamental one, all else being equal', () {
    int countFinishingGrowths(PlayerPersonality personality) {
      var growths = 0;
      for (int i = 0; i < 400; i++) {
        final p = makeFreshPlayer();
        p.personality = personality;
        TrainingEngine.applyYouthAcademyGrowth([p], 1);
        if (p.attributeValue(AttributeKeys.finishing) > 50) growths++;
      }
      return growths;
    }

    final professional = countFinishingGrowths(PlayerPersonality.professional);
    final temperamental =
        countFinishingGrowths(PlayerPersonality.temperamental);
    expect(professional, greaterThan(temperamental));
  });

  test(
      'GameState.giveTeamTalk moves starters\' morale by an amount scaled by '
      'their personality\'s result sensitivity', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    for (final p in team.players) {
      p.morale = 50;
      p.personality = PlayerPersonality.professional;
    }
    final ambitious =
        team.players.firstWhere((p) => team.startingXI.contains(p.id));
    ambitious.personality = PlayerPersonality.ambitious;

    gameState.giveTeamTalk(TeamTalkTone.encouraging);

    final professionalStarter = team.players.firstWhere(
        (p) => team.startingXI.contains(p.id) && p.id != ambitious.id);
    // 野心家(結果感応度1.4)はプロフェッショナル(0.7)より変動幅が大きい。
    expect(ambitious.morale - 50, greaterThan(professionalStarter.morale - 50));
    // ベンチ外の選手には影響しない。
    final benched =
        team.players.firstWhere((p) => !team.startingXI.contains(p.id));
    expect(benched.morale, 50);
  });

  test('GameState tactical assignment setters store the chosen player IDs',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    final a = team.players[0];
    final b = team.players[1];

    gameState.setManMarker(a.id);
    expect(team.manMarkerId, a.id);
    gameState.setManMarker(null);
    expect(team.manMarkerId, isNull);

    gameState.setSetPieceDefender(b.id);
    expect(team.setPieceDefenderId, b.id);

    expect(team.timeWastingMode, isFalse);
    gameState.setTimeWastingMode(true);
    expect(team.timeWastingMode, isTrue);
  });

  test(
      'MatchEngine.markedTargetId returns the target team\'s key player only '
      'when the marking team\'s marker is actually in the lineup', () {
    final marker = Player(
        id: 'marker',
        name: 'Marker',
        age: 25,
        position: Position.dc,
        potential: 70);
    final markingTeam =
        Team(id: 'a', name: 'A', players: [marker], manMarkerId: marker.id);
    final weakKey = Player(
        id: 'weak',
        name: 'Weak',
        age: 25,
        position: Position.st,
        potential: 60);
    final strongKey = Player(
        id: 'strong',
        name: 'Strong',
        age: 25,
        position: Position.st,
        potential: 90);
    for (final k in AttributeKeys.all) {
      strongKey.setAttributeValue(k, 90);
    }
    final targetLineup = [weakKey, strongKey];

    expect(MatchEngine.markedTargetId(markingTeam, [marker], targetLineup),
        strongKey.id);
    // マーカーが出場していない(負傷などで先発に含まれない)場合はnull。
    expect(MatchEngine.markedTargetId(markingTeam, [], targetLineup), isNull);
    // マンマークを指名していないチームはnull。
    final noMarkerTeam = Team(id: 'b', name: 'B', players: [marker]);
    expect(MatchEngine.markedTargetId(noMarkerTeam, [marker], targetLineup),
        isNull);
  });

  test(
      'MatchEngine.applySetPieceDefense reduces the score probability when '
      'the defending team fields a skilled set-piece defender', () {
    final defender = Player(
        id: 'defender',
        name: 'Defender',
        age: 25,
        position: Position.dc,
        potential: 70);
    defender.setAttributeValue(AttributeKeys.heading, 95);
    defender.setAttributeValue(AttributeKeys.jumpingReach, 95);
    final defendingTeam = Team(
        id: 'a',
        name: 'A',
        players: [defender],
        setPieceDefenderId: defender.id);
    final reduced =
        MatchEngine.applySetPieceDefense(0.4, defendingTeam, [defender]);
    expect(reduced, lessThan(0.4));

    final noDefenderTeam = Team(id: 'b', name: 'B', players: [defender]);
    final unchanged =
        MatchEngine.applySetPieceDefense(0.4, noDefenderTeam, [defender]);
    expect(unchanged, 0.4);
  });

  test('MatchEngine.applyHalfTimeFatigue raises fatigue for both lineups', () {
    final home = PlayerGenerator.generateSquad(
        id: 'home', name: 'Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'away', name: 'Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);
    for (final p in [...home.players, ...away.players]) {
      p.fatigue = 0;
    }

    MatchEngine.applyHalfTimeFatigue(home: home, away: away);

    for (final p in MatchEngine.lineupOf(home) + MatchEngine.lineupOf(away)) {
      expect(p.fatigue, greaterThan(0));
    }
  });

  test(
      'timeWastingMode reduces average fatigue gain from a match compared to '
      'normal play', () {
    double averageFatigueGain(bool timeWasting) {
      var total = 0;
      const trials = 150;
      for (int i = 0; i < trials; i++) {
        final home = PlayerGenerator.generateSquad(
            id: 'home', name: 'Home FC', strengthTier: 60);
        final away = PlayerGenerator.generateSquad(
            id: 'away', name: 'Away FC', strengthTier: 60);
        LineupUtils.autoFill(home);
        LineupUtils.autoFill(away);
        home.timeWastingMode = timeWasting;
        for (final p in home.players) {
          p.fatigue = 0;
        }
        MatchEngine.applyPostMatchEffects(home: home, away: away);
        for (final p in MatchEngine.lineupOf(home)) {
          total += p.fatigue;
        }
      }
      return total / trials;
    }

    final withTimeWasting = averageFatigueGain(true);
    final normal = averageFatigueGain(false);
    expect(withTimeWasting, lessThan(normal));
  });

  test(
      'timeWastingMode increases the average number of yellow cards a team '
      'picks up over many matches, offsetting its fatigue benefit', () {
    double averageYellowCards(bool timeWasting) {
      var total = 0;
      // 時間稼ぎモードによる追加警告は1試合あたり数%〜十数%程度の確率でしか
      // 発生しないため、試行回数が少ないとRNGの偏りだけで平均が逆転しうる。
      // 十分な統計的検出力を持たせるため試行回数を増やしている。
      const trials = 500;
      for (int i = 0; i < trials; i++) {
        final home = PlayerGenerator.generateSquad(
            id: 'home', name: 'Home FC', strengthTier: 60);
        final away = PlayerGenerator.generateSquad(
            id: 'away', name: 'Away FC', strengthTier: 60);
        LineupUtils.autoFill(home);
        LineupUtils.autoFill(away);
        home.timeWastingMode = timeWasting;
        final result =
            MatchEngine.simulate(home: home, away: away, matchday: 1);
        total += result.events
            .where((e) =>
                e.teamId == home.id && e.type == MatchEventType.yellowCard)
            .length;
      }
      return total / trials;
    }

    final withTimeWasting = averageYellowCards(true);
    final normal = averageYellowCards(false);
    expect(withTimeWasting, greaterThan(normal));
  });

  test(
      'CupEngine.decidePenaltyWinner favors the team with sharper penalty '
      'takers, even at equal overall rating and equal goalkeeper ability', () {
    Team buildTeam(String id, {required bool strongKickers}) {
      final players = List.generate(
        11,
        (i) => Player(
            id: '$id$i',
            name: '$id$i',
            age: 25,
            position: i == 0 ? Position.gk : Position.st,
            potential: 70),
      );
      for (final p in players) {
        for (final k in AttributeKeys.all) {
          p.setAttributeValue(k, 60);
        }
      }
      // 自チームのGK能力は両チームで揃え、キッカーの精度差のみが
      // 結果を左右するようにする(片方のGKだけ強くすると相殺されて
      // 効果量が小さくなり、統計テストがフレーキーになるため)。
      players.first.setAttributeValue(AttributeKeys.oneOnOnes, 60);
      if (strongKickers) {
        for (final p in players.skip(1)) {
          p.setAttributeValue(AttributeKeys.penalties, 95);
          p.setAttributeValue(AttributeKeys.composure, 95);
        }
      } else {
        for (final p in players.skip(1)) {
          p.setAttributeValue(AttributeKeys.penalties, 20);
          p.setAttributeValue(AttributeKeys.composure, 20);
        }
      }
      final team = Team(id: id, name: id, players: players);
      LineupUtils.autoFill(team);
      return team;
    }

    final sharp = buildTeam('sharp', strongKickers: true);
    final dull = buildTeam('dull', strongKickers: false);

    var sharpWins = 0;
    const trials = 300;
    for (int i = 0; i < trials; i++) {
      if (CupEngine.decidePenaltyWinner(sharp, dull) == sharp.id) sharpWins++;
    }
    expect(sharpWins, greaterThan(trials ~/ 2));
  });

  test(
      'MatchEngine._rollInjuries (via applyPostMatchEffects) assigns an '
      'injury type and records injury history, and low natural fitness '
      'leads to more injuries than high natural fitness', () {
    int countInjured(int naturalFitness) {
      var injured = 0;
      const trials = 300;
      for (int i = 0; i < trials; i++) {
        final home = PlayerGenerator.generateSquad(
            id: 'home', name: 'Home FC', strengthTier: 60);
        final away = PlayerGenerator.generateSquad(
            id: 'away', name: 'Away FC', strengthTier: 60);
        LineupUtils.autoFill(home);
        LineupUtils.autoFill(away);
        for (final p in home.players) {
          p.fatigue = 90;
          p.setAttributeValue(AttributeKeys.naturalFitness, naturalFitness);
        }
        // lineupOf()は負傷者を除外するため、判定対象は適用前に確定させる
        // (適用後に取り直すと今負傷した選手自身が除外されてしまう)。
        final matchLineup = MatchEngine.lineupOf(home);
        MatchEngine.applyPostMatchEffects(home: home, away: away);
        for (final p in matchLineup) {
          if (p.injuryWeeks > 0) injured++;
        }
      }
      return injured;
    }

    final lowFitnessInjuries = countInjured(1);
    final highFitnessInjuries = countInjured(99);
    expect(lowFitnessInjuries, greaterThan(highFitnessInjuries));

    // 実際に負傷した選手には種類が記録され、履歴にも積み上がる。
    final home = PlayerGenerator.generateSquad(
        id: 'home', name: 'Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'away', name: 'Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);
    for (final p in home.players) {
      p.fatigue = 95;
      p.setAttributeValue(AttributeKeys.naturalFitness, 1);
    }
    Player? injuredPlayer;
    for (int i = 0; i < 50 && injuredPlayer == null; i++) {
      MatchEngine.applyPostMatchEffects(home: home, away: away);
      for (final p in home.players) {
        if (p.injuryWeeks > 0) {
          injuredPlayer = p;
          break;
        }
      }
    }
    expect(injuredPlayer, isNotNull);
    expect(injuredPlayer!.injuryType, isNotNull);
    expect(injuredPlayer.injuryHistoryCounts[injuredPlayer.injuryType!.name],
        greaterThan(0));
  });

  test(
      'higher homeAdvantageFactor leads to more home goals over many '
      'simulated halves, all else being equal', () {
    // 対戦カードを固定した上で同一カードをfactor違いで繰り返し試行し、
    // スカッド生成自体のばらつきが効果検証のノイズにならないようにする。
    // homeAdvantageFactorの効果自体が僅かなため(1試合平均で数%程度)、
    // 有意な差を安定して検出するには十分な試行回数が必要
    // (事前計測でn=8000程度ならz値5〜8と十分な余裕がある)。
    const cardCount = 50;
    const trialsPerCard = 160;
    final cards = List.generate(cardCount, (i) {
      final home = PlayerGenerator.generateSquad(
          id: 'home$i', name: 'Home FC $i', strengthTier: 60);
      final away = PlayerGenerator.generateSquad(
          id: 'away$i', name: 'Away FC $i', strengthTier: 60);
      LineupUtils.autoFill(home);
      LineupUtils.autoFill(away);
      return (home: home, away: away);
    });

    int totalHomeGoals(double factor) {
      var total = 0;
      for (final card in cards) {
        for (int i = 0; i < trialsPerCard; i++) {
          final result = MatchEngine.simulateMinutes(
              home: card.home,
              away: card.away,
              startMinute: 1,
              endMinute: 90,
              homeAdvantageFactor: factor);
          total += result.homeGoals;
        }
      }
      return total;
    }

    final highAdvantage = totalHomeGoals(1.09);
    final lowAdvantage = totalHomeGoals(1.03);
    expect(highAdvantage, greaterThan(lowAdvantage));
  });

  test(
      'MatchEngine.simulate produces realistic league-level aggregates: '
      'average total goals in a real-football range, a meaningful share of '
      'draws, a visible home advantage, and favorites beating clear '
      'underdogs most of the time', () {
    Team buildTeam(String id, int tier) {
      final t = PlayerGenerator.generateSquad(
          id: id, name: 'T$id', strengthTier: tier);
      LineupUtils.autoFill(t);
      return t;
    }

    const n = 500;
    int homeWins = 0, draws = 0, awayWins = 0, totalGoals = 0;
    for (int i = 0; i < n; i++) {
      final r = MatchEngine.simulate(
          home: buildTeam('bal-h$i', 60),
          away: buildTeam('bal-a$i', 60),
          matchday: 1);
      totalGoals += r.homeGoals + r.awayGoals;
      if (r.homeGoals > r.awayGoals) {
        homeWins++;
      } else if (r.homeGoals < r.awayGoals) {
        awayWins++;
      } else {
        draws++;
      }
    }
    // 実測の中心値: 平均総ゴール約2.6、引き分け約24%、勝率はホーム44%対
    // アウェイ32%。乱数ノイズに対して十分な余裕を持った境界で検証する。
    expect(totalGoals / n, inInclusiveRange(2.0, 3.3));
    expect(draws, greaterThanOrEqualTo((n * 0.12).round()));
    expect(homeWins, greaterThan(awayWins));

    const gapTrials = 120;
    int favoriteWins = 0;
    for (int i = 0; i < gapTrials; i++) {
      final r = MatchEngine.simulate(
          home: buildTeam('fav$i', 75),
          away: buildTeam('dog$i', 55),
          matchday: 1);
      if (r.homeGoals > r.awayGoals) favoriteWins++;
    }
    expect(favoriteWins, greaterThan((gapTrials * 0.6).round()));
  });

  test(
      'watching a match live (interactive engine with neutral choices) '
      'yields the same average goals for and against as the automatic '
      'simulate path, so live play is neither systematically rewarded nor '
      'punished', () {
    Team buildTeam(String id) {
      final t =
          PlayerGenerator.generateSquad(id: id, name: 'T$id', strengthTier: 60);
      LineupUtils.autoFill(t);
      return t;
    }

    const n = 400;
    int simFor = 0, simAgainst = 0, intFor = 0, intAgainst = 0;
    for (int i = 0; i < n; i++) {
      final r = MatchEngine.simulate(
          home: buildTeam('par-sh$i'),
          away: buildTeam('par-sa$i'),
          matchday: 1);
      simFor += r.homeGoals;
      simAgainst += r.awayGoals;

      final home = buildTeam('par-ih$i');
      final away = buildTeam('par-ia$i');
      for (final half in [
        (start: 1, end: 45),
        (start: 46, end: 90),
      ]) {
        final state = MatchEngine.beginInteractiveHalf(
          home: home,
          away: away,
          startMinute: half.start,
          endMinute: half.end,
          interactiveTeamId: home.id,
        );
        while (!state.isFinished) {
          final pending = state.pending!;
          MatchEngine.resolvePendingChance(
              state,
              pending.context == ChanceContext.attack
                  ? ChanceDecision.shoot
                  : ChanceDecision.coverSpace);
        }
        intFor += state.homeGoals;
        intAgainst += state.awayGoals;
      }
    }
    // 事前計測(n=1500)では自動1.44/1.19に対しライブ1.42/1.18とほぼ一致。
    // 平均の差が±0.4ゴール以内(実測ノイズの4倍以上のマージン)に
    // 収まることを検証し、ライブ観戦だけで系統的に有利/不利になる
    // 回帰(例: 中立守備選択への割引の復活)を検出する。
    expect((intFor - simFor).abs() / n, lessThan(0.4));
    expect((intAgainst - simAgainst).abs() / n, lessThan(0.4));
  });

  test('ScoutReportEngine.generateFor exposes the key player\'s ID', () {
    final home = PlayerGenerator.generateSquad(
        id: 'home', name: 'Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'away', name: 'Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);
    final report =
        ScoutReportEngine.generateFor(opponent: away, userTeam: home);
    expect(report.keyPlayerId, isNotNull);
    expect(MatchEngine.lineupOf(away).map((p) => p.id),
        contains(report.keyPlayerId));
  });

  test(
      'PlayerGenerator.ensureIdCounterAbove prevents newly generated players '
      'from reusing an existing player ID', () {
    PlayerGenerator.ensureIdCounterAbove(['pl500000']);
    final p = PlayerGenerator.generate(position: Position.st, strengthTier: 60);
    final match = RegExp(r'^pl(\d+)$').firstMatch(p.id);
    expect(match, isNotNull);
    expect(int.parse(match!.group(1)!), greaterThan(500000));
  });

  test(
      'RetirementEngine.resolveAndReplaceForCpu keeps CPU squad size stable '
      'by replacing retirees with fresh young players', () {
    final team = Team(
      id: 'cpu',
      name: 'CPU FC',
      players: List.generate(
        20,
        (i) => Player(
            id: 'old$i',
            name: 'old$i',
            age: 40,
            position: Position.st,
            potential: 60),
      ),
    );
    final originalSize = team.players.length;
    final retirees = RetirementEngine.resolveAndReplaceForCpu(team);
    expect(retirees, isNotEmpty);
    expect(team.players.length, originalSize);
    for (final r in retirees) {
      expect(team.players.any((p) => p.id == r.id), isFalse);
    }
    final newYoungsters = team.players.where((p) => p.age < 25);
    expect(newYoungsters.length, retirees.length);
  });

  test(
      'weekly matchday tick keeps CPU fatigue from permanently pinning at '
      'the cap, unlike before passive recovery existed', () async {
    SharedPreferences.setMockInitialValues({});
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    for (int i = 0; i < 10; i++) {
      await gameState.playNextMatchdayQuickSim();
    }
    final cpuTeams = gameState.save!.league.teams
        .where((t) => t.id != gameState.save!.userTeamId);
    final allFatigue = cpuTeams.expand((t) => t.players.map((p) => p.fatigue));
    final avgFatigue = allFatigue.reduce((a, b) => a + b) / allFatigue.length;
    expect(avgFatigue, lessThan(90));
  });

  test('captain discipline bonus only applies if the captain is in the lineup',
      () {
    Team buildTeam(bool captainStarts) {
      final players = List.generate(
        11,
        (i) => Player(
            id: 'p$i',
            name: 'p$i',
            age: 25,
            position: i == 0 ? Position.gk : Position.mc,
            potential: 60),
      );
      final bench = Player(
          id: 'benched-captain',
          name: 'benched-captain',
          age: 25,
          position: Position.mc,
          potential: 60);
      final team = Team(
          id: captainStarts ? 'starts' : 'benched',
          name: 'T',
          players: [...players, bench]);
      LineupUtils.autoFill(team);
      team.captainId = captainStarts ? players.first.id : bench.id;
      return team;
    }

    int totalCards(Team home) {
      var total = 0;
      const trials = 200;
      final away = PlayerGenerator.generateSquad(
          id: 'away', name: 'Away FC', strengthTier: 60);
      LineupUtils.autoFill(away);
      for (int i = 0; i < trials; i++) {
        final result = MatchEngine.simulateMinutes(
            home: home, away: away, startMinute: 1, endMinute: 90);
        total += result.events
            .where((e) =>
                e.teamId == home.id &&
                (e.type == MatchEventType.yellowCard ||
                    e.type == MatchEventType.redCard))
            .length;
      }
      return total;
    }

    final withCaptainOnBench = totalCards(buildTeam(false));
    final withCaptainStarting = totalCards(buildTeam(true));
    expect(withCaptainOnBench, greaterThan(withCaptainStarting));
  });

  test(
      'AwardsEngine.computeAwards can still pick a player as MVP even if '
      'they are not currently listed in startingXI', () {
    final players = List.generate(
      15,
      (i) => Player(
          id: 'p$i',
          name: 'p$i',
          age: 25,
          position: Position.st,
          potential: 60),
    );
    final star = players.first;
    star.setAttributeValue(AttributeKeys.finishing, 99);
    for (final k in AttributeKeys.all) {
      star.setAttributeValue(k, 90);
    }
    final team = Team(id: 't', name: 'T', players: players);
    // スタメンから外れていても(直前のローテーション等を想定)、シーズンの
    // 実績で選出されるべき。
    team.startingXI = players.skip(1).take(10).map((p) => p.id).toList();
    final league = League(
      teams: [team],
      fixtures: [
        Fixture(
          matchday: 1,
          homeTeamId: 't',
          awayTeamId: 't',
          result: MatchResult(
            matchday: 1,
            homeTeamId: 't',
            awayTeamId: 't',
            homeGoals: 3,
            awayGoals: 0,
            events: [
              MatchEvent(
                  minute: 10,
                  teamId: 't',
                  scorerName: star.name,
                  scorerId: star.id,
                  type: MatchEventType.goal),
            ],
          ),
        ),
      ],
      season: 1,
    );
    final award = AwardsEngine.computeAwards(league, 1);
    expect(award.mvpName, star.name);
  });

  test(
      'NamePool.themedClubNames always returns exactly the requested count, '
      'even beyond the base word x suffix combination pool', () {
    final names = NamePool.themedClubNames(LeagueTheme.spain, 60);
    expect(names.length, 60);
    expect(names.toSet().length, 60);
  });

  test(
      'enumFromName falls back instead of crashing when a legacy save names '
      'an enum value that no longer exists', () {
    expect(enumFromName(Position.values, 'st', Position.gk), Position.st);
    expect(enumFromName(Position.values, 'deleted_old_value', Position.gk),
        Position.gk);
    expect(enumFromName(Position.values, null, Position.gk), Position.gk);
  });

  test(
      'Player.overall weighs goalkeeping attributes for a GK but not for '
      'an outfield player', () {
    final gk = PlayerGenerator.generateSquad(
            id: 'gkteam', name: 'GK FC', strengthTier: 60)
        .players
        .firstWhere((p) => p.position == Position.gk);
    gk.setAttributeValue(AttributeKeys.finishing, 1);
    final beforeRaisingFinishing = gk.overall;
    // フィニッシュのようなフィールドプレーヤー攻撃属性を上げても、
    // GKのoverallはgoalkeeping系属性ベースなので変化しないはず。
    gk.setAttributeValue(AttributeKeys.finishing, 99);
    expect(gk.overall, beforeRaisingFinishing);

    gk.setAttributeValue(AttributeKeys.reflexes, 1);
    gk.setAttributeValue(AttributeKeys.handling, 1);
    final beforeRaisingReflexes = gk.overall;
    gk.setAttributeValue(AttributeKeys.reflexes, 99);
    gk.setAttributeValue(AttributeKeys.handling, 99);
    expect(gk.overall, greaterThan(beforeRaisingReflexes));
  });

  test(
      'GameState.sellPlayer clears the departing player\'s captain/set-piece '
      'role references instead of leaving dangling IDs', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    final captain = team.players.first;
    await gameState.setCaptain(captain.id);
    team.penaltyTakerId = captain.id;
    team.freeKickTakerId = captain.id;

    final ok = await gameState.sellPlayer(captain.id);

    expect(ok, isTrue);
    expect(team.captainId, isNull);
    expect(team.penaltyTakerId, isNull);
    expect(team.freeKickTakerId, isNull);
  });

  test(
      'CupEngine.createKnockout rejects fewer than 2 teams instead of '
      'crashing with a RangeError deep inside bracket generation', () {
    expect(
      () => CupEngine.createKnockout(
          type: CupType.domestic, name: 'テストカップ', teamIds: ['only-one']),
      throwsArgumentError,
    );
  });

  test(
      'ContinentalCupEngine.create pads an odd-sized group with a bye and '
      'excludes the bye from every generated match', () {
    final cup =
        ContinentalCupEngine.create(name: 'テスト大陸カップ', teamIds: ['a', 'b', 'c']);

    expect(cup.groups.single.toSet(), {'a', 'b', 'c'});
    expect(cup.groupMatches.length, 3); // 3チーム総当たり = 3試合
    for (final m in cup.groupMatches) {
      expect(m.homeTeamId, isNot(byeTeamId));
      expect(m.awayTeamId, isNot(byeTeamId));
    }
  });

  test(
      'GameState.seasonProjection reports zero continental-qualify slots '
      'outside the top division', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    // ユーザーは5部制の最下層(5部)から始まるため、大陸カップ出場枠は0のはず。
    expect(gameState.save!.currentDivisionTier, totalDivisionTiers);
    for (final p in gameState.seasonProjection) {
      expect(p.continentalProbability, 0.0);
    }

    gameState.save!.currentDivisionTier = 1;
    for (final p in gameState.seasonProjection) {
      expect(p.continentalProbability, greaterThanOrEqualTo(0.0));
    }

    gameState.save!.currentDivisionTier = 2;
    for (final p in gameState.seasonProjection) {
      expect(p.continentalProbability, 0.0);
    }
  });

  test(
      'GameState.startNextSeason clears a retiring captain\'s role '
      'references instead of leaving a dangling ID', () async {
    bool observed = false;
    for (int attempt = 0; attempt < 30 && !observed; attempt++) {
      SharedPreferences.setMockInitialValues({});
      final gameState = GameState();
      await gameState.startNewGame('テストFC');
      final captain = gameState.userTeam.players.first;
      // 引退確率は年齢とともに上がり32歳以降0.9で頭打ちになるため、
      // 高齢に設定して30回試行のうちほぼ確実に引退させる。
      captain.age = 45;
      await gameState.setCaptain(captain.id);
      gameState.userTeam.penaltyTakerId = captain.id;

      await gameState.startNextSeason();

      final team = gameState.userTeam;
      if (!team.players.any((p) => p.id == captain.id)) {
        observed = true;
        expect(team.captainId, isNull);
        expect(team.penaltyTakerId, isNull);
      }
    }
    expect(observed, isTrue, reason: '45歳のキャプテンが30回の試行内で一度も引退しなかった');
  });

  test(
      'GameState.sellPlayer cancels that player\'s pending installment plan '
      'instead of continuing to charge the club for a player it no longer '
      'owns', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.transferMarket.first;
    gameState.save!.budget = target.marketValue;

    final bought = await gameState.buyPlayerOnInstallments(target.id);
    expect(bought, isTrue);
    expect(gameState.save!.pendingInstallments, isNotEmpty);
    gameState.save!.budget = 999999;

    final sold = await gameState.sellPlayer(target.id);

    expect(sold, isTrue);
    expect(
        gameState.save!.pendingInstallments.any((i) => i.playerId == target.id),
        isFalse);
  });

  test(
      'AwardsEngine.computeAwards still names the season top scorer even '
      'after they left every current roster before the season ended', () {
    final star = Player(
        id: 'star', name: 'エース', age: 25, position: Position.st, potential: 60);
    final other = Player(
        id: 'other',
        name: 'その他',
        age: 25,
        position: Position.st,
        potential: 60);
    // starは移籍・退団済みでどのチームのロースターにも存在しない。
    final team = Team(id: 't', name: 'T', players: [other]);
    final league = League(
      teams: [team],
      fixtures: [
        Fixture(
          matchday: 1,
          homeTeamId: 't',
          awayTeamId: 't',
          result: MatchResult(
            matchday: 1,
            homeTeamId: 't',
            awayTeamId: 't',
            homeGoals: 2,
            awayGoals: 0,
            events: [
              MatchEvent(
                  minute: 10,
                  teamId: 't',
                  scorerName: star.name,
                  scorerId: star.id,
                  type: MatchEventType.goal),
              MatchEvent(
                  minute: 20,
                  teamId: 't',
                  scorerName: star.name,
                  scorerId: star.id,
                  type: MatchEventType.goal),
            ],
          ),
        ),
      ],
      season: 1,
    );

    final award = AwardsEngine.computeAwards(league, 1);

    expect(award.topScorerName, star.name);
    expect(award.topScorerGoals, 2);
    expect(award.topScorerTeamId, 't');
    expect(award.topScorerTeamName, 'T');
  });

  test(
      'GameState.exerciseLoanBuyOption restores the pre-loan wage instead '
      'of permanently keeping the loan-period discount', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.transferMarket.first;
    final wageBeforeLoan = target.wage;
    final expectedFee =
        (target.marketValue * GameState.loanBuyOptionRatio).round();
    gameState.save!.budget = target.marketValue + expectedFee;

    await gameState.signLoanPlayer(target.id, withBuyOption: true);
    final player =
        gameState.userTeam.players.firstWhere((p) => p.id == target.id);
    expect(player.wage, lessThan(wageBeforeLoan));

    await gameState.exerciseLoanBuyOption(target.id);

    expect(player.wage, closeTo(wageBeforeLoan.toDouble(), 2));
  });

  test(
      'GameState.applyTacticPreset drops a set-piece taker who has since '
      'left the roster instead of reinstating a stale player ID', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    while (team.players.length > minSquadSize + 1) {
      team.players.removeLast();
    }
    final taker = team.players.first;
    team.penaltyTakerId = taker.id;
    gameState.saveTacticPreset('セット専用');

    final sold = await gameState.sellPlayer(taker.id);
    expect(sold, isTrue);
    expect(team.penaltyTakerId, isNull);

    gameState.applyTacticPreset('セット専用');

    expect(team.penaltyTakerId, isNull);
  });

  test(
      'AchievementEngine.evaluate unlocks first_title only after a season '
      'record shows a league win, and never re-returns an already-unlocked '
      'achievement', () {
    final team = Team(id: 'a', name: 'A', players: []);
    final league = League(teams: [team], fixtures: [], season: 2);
    final save = SaveGame(clubName: 'テストFC', userTeamId: 'a', league: league);

    expect(AchievementEngine.evaluate(save, team), isEmpty);

    save.seasonHistory.add(SeasonRecord(
      season: 1,
      clubName: 'テストFC',
      leagueName: 'リーグ',
      divisionTier: 1,
      finalRank: 1,
      teamCount: 10,
      played: 10,
      won: 10,
      draw: 0,
      lost: 0,
      goalsFor: 20,
      goalsAgainst: 2,
      wonLeague: true,
    ));

    final unlocked = AchievementEngine.evaluate(save, team);
    expect(unlocked.any((a) => a.id == 'first_title'), isTrue);
    expect(unlocked.any((a) => a.id == 'unbeaten_champion'), isTrue);

    save.unlockedAchievements['first_title'] = 1;
    save.unlockedAchievements['unbeaten_champion'] = 1;
    expect(AchievementEngine.evaluate(save, team), isEmpty);
  });

  test(
      'AchievementEngine back_to_back and bounce_back only fire for '
      'consecutive seasons, not merely any two seasons in history', () {
    final team = Team(id: 'a', name: 'A', players: []);
    final league = League(teams: [team], fixtures: [], season: 3);
    final save = SaveGame(clubName: 'テストFC', userTeamId: 'a', league: league);

    SeasonRecord record(int season,
            {bool wonLeague = false,
            bool promoted = false,
            bool relegated = false}) =>
        SeasonRecord(
          season: season,
          clubName: 'テストFC',
          leagueName: 'リーグ',
          divisionTier: 1,
          finalRank: wonLeague ? 1 : 5,
          teamCount: 10,
          played: 10,
          won: 5,
          draw: 0,
          lost: 5,
          goalsFor: 10,
          goalsAgainst: 10,
          wonLeague: wonLeague,
          promoted: promoted,
          relegated: relegated,
        );

    // 優勝したシーズンの間に無冠のシーズンを挟むと連覇にはならない。
    save.seasonHistory.addAll([
      record(1, wonLeague: true),
      record(2),
      record(3, wonLeague: true),
    ]);
    var unlocked = AchievementEngine.evaluate(save, team);
    expect(unlocked.any((a) => a.id == 'back_to_back'), isFalse);

    save.seasonHistory.add(record(4, wonLeague: true));
    unlocked = AchievementEngine.evaluate(save, team);
    expect(unlocked.any((a) => a.id == 'back_to_back'), isTrue);

    // 降格後、1シーズン間を置いてから昇格した場合はbounce_backにならない。
    final save2 = SaveGame(clubName: 'テストFC2', userTeamId: 'a', league: league);
    save2.seasonHistory.addAll([
      record(1, relegated: true),
      record(2),
      record(3, promoted: true),
    ]);
    expect(
        AchievementEngine.evaluate(save2, team)
            .any((a) => a.id == 'bounce_back'),
        isFalse);

    // relegated(1)の直後にpromoted(2)が来る場合のみtrueになる。
    save2.seasonHistory[1] = record(2, promoted: true);
    expect(
        AchievementEngine.evaluate(save2, team)
            .any((a) => a.id == 'bounce_back'),
        isTrue);
  });

  test(
      'AchievementEngine facilities_maxed and superstar_player read from '
      'club infrastructure and the live squad, not season history', () {
    final infra = ClubInfrastructure();
    for (final f in FacilityType.values) {
      while (infra.facilityLevel(f) < ClubInfrastructure.maxLevel) {
        infra.upgradeFacility(f);
      }
    }
    final star = Player(
      id: 'star',
      name: 'スター',
      age: 25,
      position: Position.st,
      potential: 99,
      attributes: {for (final k in AttributeKeys.all) k: 99},
    );
    final team = Team(id: 'a', name: 'A', players: [star]);
    final league = League(teams: [team], fixtures: [], season: 1);
    final save = SaveGame(
      clubName: 'テストFC',
      userTeamId: 'a',
      league: league,
      infrastructure: infra,
    );

    final unlocked = AchievementEngine.evaluate(save, team);
    expect(unlocked.any((a) => a.id == 'facilities_maxed'), isTrue);
    expect(unlocked.any((a) => a.id == 'superstar_player'), isTrue);
    expect(unlocked.any((a) => a.id == 'staff_maxed'), isFalse);
  });

  test(
      'GameState records a newly unlocked achievement into unlockedAchievements '
      'and surfaces it via lastUnlockedAchievements after startNextSeason',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.careerWins = 50;

    await gameState.startNextSeason();

    expect(gameState.isAchievementUnlocked('wins_50'), isTrue);
    expect(gameState.achievementUnlockedSeason('wins_50'), isNotNull);
    expect(gameState.lastUnlockedAchievements.any((a) => a.id == 'wins_50'),
        isTrue);
  });

  test(
      'CalendarEngine.seasonAnchor and dateForMatchday always land on a '
      'Saturday, exactly 7 days apart per matchday', () {
    for (final season in [1, 2, 3, 10]) {
      final anchor = CalendarEngine.seasonAnchor(season);
      expect(anchor.weekday, DateTime.saturday);

      final md1 = CalendarEngine.dateForMatchday(season, 1);
      final md2 = CalendarEngine.dateForMatchday(season, 2);
      expect(md1, anchor);
      expect(md2.weekday, DateTime.saturday);
      expect(md2.difference(md1).inDays, 7);
    }
  });

  test(
      'CalendarEngine.buildRange marks the user\'s league fixture date as a '
      'match day (with opponent/home-away) and every other day by the '
      'configured training weekday, without double-marking a match day', () {
    final home = Team(id: 'user', name: 'ユーザー', players: []);
    final away = Team(id: 'rival', name: 'ライバル', players: []);
    final league = League(
      teams: [home, away],
      fixtures: [
        Fixture(matchday: 1, homeTeamId: 'user', awayTeamId: 'rival'),
      ],
      season: 1,
    );

    final matchDate = CalendarEngine.dateForMatchday(1, 1);
    // トレーニング曜日をあえて試合日と同じ曜日に設定し、試合日が優先され
    // 二重にマークされないことを確認する。
    final days = CalendarEngine.buildRange(
      from: matchDate.subtract(const Duration(days: 3)),
      to: matchDate.add(const Duration(days: 10)),
      league: league,
      userTeamId: 'user',
      trainingDayOfWeek: matchDate.weekday,
      today: matchDate,
    );

    final matchDay = days.firstWhere((d) => d.date == matchDate);
    expect(matchDay.isLeagueMatchDay, isTrue);
    expect(matchDay.isHomeMatch, isTrue);
    expect(matchDay.opponentName, 'ライバル');
    expect(matchDay.matchday, 1);
    expect(matchDay.isTrainingFocusDay, isFalse);
    expect(matchDay.isToday, isTrue);

    final otherTrainingDays = days.where(
        (d) => !d.isLeagueMatchDay && d.date.weekday == matchDate.weekday);
    expect(otherTrainingDays, isNotEmpty);
    expect(otherTrainingDays.every((d) => d.isTrainingFocusDay), isTrue);

    final nonMatchNonTrainingDay = days.firstWhere(
        (d) => !d.isLeagueMatchDay && d.date.weekday != matchDate.weekday);
    expect(nonMatchNonTrainingDay.isTrainingFocusDay, isFalse);
  });

  test(
      'CalendarEngine.buildRange labels the date the domestic cup becomes '
      'playable again, showing the opponent when it is the user\'s match', () {
    final user = Team(id: 'user', name: 'ユーザー', players: []);
    final rival = Team(id: 'rival', name: 'ライバル', players: []);
    final league = League(teams: [user, rival], fixtures: [], season: 1);
    final cup = Cup(
      type: CupType.domestic,
      name: '国内カップ',
      rounds: [
        [
          CupMatch(round: 1, homeTeamId: 'user', awayTeamId: 'rival'),
        ],
      ],
      lastPlayedAtMatchday: 2,
    );
    final eligibleDate = CalendarEngine.dateForMatchday(1, 3);

    final days = CalendarEngine.buildRange(
      from: eligibleDate.subtract(const Duration(days: 3)),
      to: eligibleDate.add(const Duration(days: 3)),
      league: league,
      userTeamId: 'user',
      trainingDayOfWeek: DateTime.tuesday,
      today: eligibleDate,
      domesticCup: cup,
    );

    final day = days.firstWhere((d) => d.date == eligibleDate);
    expect(day.isCupMatchDay, isTrue);
    expect(day.cupLabels.single, contains('ライバル'));
    final otherDays = days.where((d) => d.date != eligibleDate).toList();
    expect(otherDays.every((d) => !d.isCupMatchDay), isTrue);
  });

  test(
      'GameState blocks a second domestic cup match until the league '
      'advances at least one matchday, then allows it', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    expect(gameState.canPlayNextDomesticCupMatch, isTrue);
    final firstMatchBefore = gameState.domesticCup!.nextUnplayedMatch;
    final firstResult = await gameState.playNextCupMatch();
    expect(firstResult, isNotNull);
    expect(gameState.domesticCup!.nextUnplayedMatch, isNot(firstMatchBefore));

    // リーグ戦を1節も進めていないので、次のカップ戦は消化できない。
    expect(gameState.canPlayNextDomesticCupMatch, isFalse);
    final blockedMatch = gameState.domesticCup!.nextUnplayedMatch;
    final blockedResult = await gameState.playNextCupMatch();
    expect(blockedResult, isNull);
    expect(gameState.domesticCup!.nextUnplayedMatch, blockedMatch);

    // リーグを1節進めると、次のカップ戦を消化できるようになる。
    await gameState.playNextMatchdayQuickSim();
    expect(gameState.canPlayNextDomesticCupMatch, isTrue);
    final secondResult = await gameState.playNextCupMatch();
    expect(secondResult, isNotNull);
  });

  test(
      'GameState allows unrestricted cup progress once the league season is '
      'fully complete, so a pending cup never gets stuck forever', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final userId = gameState.userTeam.id;
    for (final f in gameState.save!.league.fixtures) {
      final userIsHome = f.homeTeamId == userId;
      f.result = MatchResult(
        matchday: f.matchday,
        homeTeamId: f.homeTeamId,
        awayTeamId: f.awayTeamId,
        homeGoals: userIsHome ? 2 : 1,
        awayGoals: userIsHome ? 1 : 2,
        events: [],
      );
    }
    expect(gameState.save!.league.nextUnplayedFixture, isNull);

    int guard = 0;
    while (gameState.domesticCup?.nextUnplayedMatch != null && guard < 100) {
      expect(gameState.canPlayNextDomesticCupMatch, isTrue);
      await gameState.playNextCupMatch();
      guard++;
    }

    expect(gameState.domesticCup!.isComplete, isTrue);
  });

  test(
      'ContractEngine.releaseSeverance grows with wage and remaining contract '
      'years, and GameState.sellPlayer can cost the club money for an '
      'expensive long-contract player nobody would actually want to buy',
      () async {
    final cheapShortContract = Player(
        id: 'cheap',
        name: 'Cheap',
        age: 30,
        position: Position.mc,
        potential: 40);
    cheapShortContract.wage = 5;
    cheapShortContract.contractYearsRemaining = 1;
    final expensiveLongContract = Player(
        id: 'p_release_target',
        name: 'Expensive',
        age: 30,
        position: Position.mc,
        potential: 40);
    expensiveLongContract.wage = 200;
    expensiveLongContract.contractYearsRemaining = 4;

    expect(ContractEngine.releaseSeverance(expensiveLongContract),
        greaterThan(ContractEngine.releaseSeverance(cheapShortContract)));

    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    // marketValueは最低50万円のためsellPriceは常に正だが、週俸200万円・
    // 残り4年の契約を放出すると違約金がそれを上回り、持ち出しになるはず。
    team.players.add(expensiveLongContract);
    final net = gameState.netReleaseValueFor('p_release_target');
    expect(net, lessThan(0));

    final budgetBefore = gameState.save!.budget;
    final ok = await gameState.sellPlayer('p_release_target');
    expect(ok, isTrue);
    expect(gameState.save!.budget, budgetBefore + net);
    expect(gameState.save!.budget, lessThan(budgetBefore));
  });

  test(
      'ClubInfrastructure supports 8 levels and the new fitnessCoach/'
      'medicalCenter roles stack extra recovery/injury-reduction on top of '
      'the existing trainingGround/physio effects', () {
    expect(ClubInfrastructure.maxLevel, 8);

    final low = ClubInfrastructure.fitnessCoachRecoveryBonus(1);
    final high = ClubInfrastructure.fitnessCoachRecoveryBonus(8);
    expect(high, greaterThan(low));

    final physioOnly = ClubInfrastructure.injuryFactor(8);
    final withMedicalCenter =
        physioOnly * ClubInfrastructure.medicalCenterInjuryFactor(8);
    expect(withMedicalCenter, lessThan(physioOnly));
  });

  test(
      'MatchEngine applies a giantKiller/frontRunner performance boost only '
      "when a player's trait matches their team's underdog/favorite status, "
      'via a per-match matchFormMultiplier rolled at kickoff', () {
    final weak = PlayerGenerator.generateSquad(
        id: 'weak', name: 'Weak FC', strengthTier: 25);
    weak.formation = Formation.f442;
    LineupUtils.autoFill(weak);
    final strong = PlayerGenerator.generateSquad(
        id: 'strong', name: 'Strong FC', strengthTier: 95);
    strong.formation = Formation.f442;
    LineupUtils.autoFill(strong);

    final underdog =
        weak.players.firstWhere((p) => weak.startingXI.contains(p.id));
    underdog.trait = PlayerTrait.giantKiller;
    final favorite =
        strong.players.firstWhere((p) => strong.startingXI.contains(p.id));
    favorite.trait = PlayerTrait.frontRunner;

    MatchEngine.simulate(home: weak, away: strong, matchday: 1);

    expect(underdog.matchFormMultiplier, 1.08);
    expect(favorite.matchFormMultiplier, 1.08);
  });

  test(
      'MatchEngine rolls a streaky player\'s matchFormMultiplier within the '
      'documented 0.85-1.25 variance band', () {
    final team = PlayerGenerator.generateSquad(
        id: 'streaky-team', name: 'Streaky FC', strengthTier: 60);
    team.formation = Formation.f442;
    LineupUtils.autoFill(team);
    final opponent = PlayerGenerator.generateSquad(
        id: 'opp', name: 'Opponent FC', strengthTier: 60);
    opponent.formation = Formation.f442;
    LineupUtils.autoFill(opponent);

    final streakyPlayer =
        team.players.firstWhere((p) => team.startingXI.contains(p.id));
    streakyPlayer.trait = PlayerTrait.streaky;

    MatchEngine.simulate(home: team, away: opponent, matchday: 1);

    expect(streakyPlayer.matchFormMultiplier, inInclusiveRange(0.85, 1.25));
  });

  test(
      'PlayerTrait has 54 distinct patterns, each with a non-empty label/description',
      () {
    expect(PlayerTrait.values.length, 54);
    expect(PlayerTrait.values.map((t) => t.label).toSet().length, 54,
        reason: 'trait labels should all be distinct');
    for (final t in PlayerTrait.values) {
      expect(t.label, isNotEmpty);
      expect(t.description, isNotEmpty);
    }
  });

  test(
      'MatchEngine applies bigGameHunter/bullyBall boosts based on the '
      "opponent's absolute overall strength, not just relative difference", () {
    // 特性の判定はキックオフ時に一度だけ行われ、以後は同じ選手・チームの
    // オブジェクトを別の試合に使い回すと(負傷等で先発から外れた場合)
    // 前回の値が残ってしまう恐れがあるため、シナリオごとに新しいチームを
    // 用意し、各選手につき試合を1回だけシミュレートする。
    final hunterVsStrong = makeUniformTeam('hunter-vs-strong', 60);
    final hunter1 = hunterVsStrong.players
        .firstWhere((p) => hunterVsStrong.startingXI.contains(p.id));
    hunter1.trait = PlayerTrait.bigGameHunter;
    MatchEngine.simulate(
        home: hunterVsStrong,
        away: makeUniformTeam('strong-opp-1', 90),
        matchday: 1);
    expect(hunter1.matchFormMultiplier, 1.10);

    final hunterVsWeak = makeUniformTeam('hunter-vs-weak', 60);
    final hunter2 = hunterVsWeak.players
        .firstWhere((p) => hunterVsWeak.startingXI.contains(p.id));
    hunter2.trait = PlayerTrait.bigGameHunter;
    MatchEngine.simulate(
        home: hunterVsWeak,
        away: makeUniformTeam('weak-opp-1', 30),
        matchday: 1);
    expect(hunter2.matchFormMultiplier, 1.0);

    final bullyVsWeak = makeUniformTeam('bully-vs-weak', 60);
    final bully1 = bullyVsWeak.players
        .firstWhere((p) => bullyVsWeak.startingXI.contains(p.id));
    bully1.trait = PlayerTrait.bullyBall;
    MatchEngine.simulate(
        home: bullyVsWeak,
        away: makeUniformTeam('weak-opp-2', 30),
        matchday: 1);
    expect(bully1.matchFormMultiplier, 1.06);

    final bullyVsStrong = makeUniformTeam('bully-vs-strong', 60);
    final bully2 = bullyVsStrong.players
        .firstWhere((p) => bullyVsStrong.startingXI.contains(p.id));
    bully2.trait = PlayerTrait.bullyBall;
    MatchEngine.simulate(
        home: bullyVsStrong,
        away: makeUniformTeam('strong-opp-2', 90),
        matchday: 1);
    expect(bully2.matchFormMultiplier, 1.0);
  });

  test(
      'MatchEngine applies divineReflexes based on the goalkeeping reflexes '
      'attribute, the first trait to make use of it', () {
    final sharp = makeUniformTeam('reflex-sharp', 60);
    final sharpGk = sharp.players.firstWhere((p) => p.position == Position.gk);
    sharpGk.trait = PlayerTrait.divineReflexes;
    sharpGk.setAttributeValue(AttributeKeys.reflexes, 85);
    MatchEngine.simulate(
        home: sharp,
        away: makeUniformTeam('reflex-sharp-opp', 60),
        matchday: 1);
    expect(sharpGk.matchFormMultiplier, 1.07);

    final dull = makeUniformTeam('reflex-dull', 60);
    final dullGk = dull.players.firstWhere((p) => p.position == Position.gk);
    dullGk.trait = PlayerTrait.divineReflexes;
    MatchEngine.simulate(
        home: dull, away: makeUniformTeam('reflex-dull-opp', 60), matchday: 1);
    expect(dullGk.matchFormMultiplier, 1.0);
  });

  test(
      'MatchEngine applies awayDayHero only when playing away as a clear '
      'underdog, not when at home in the same situation', () {
    final smallAway = makeUniformTeam('away-hero-small', 45);
    final hero = smallAway.players
        .firstWhere((p) => smallAway.startingXI.contains(p.id));
    hero.trait = PlayerTrait.awayDayHero;
    MatchEngine.simulate(
        home: makeUniformTeam('away-hero-big-home', 60),
        away: smallAway,
        matchday: 1);
    expect(hero.matchFormMultiplier, 1.12);

    final smallHome = makeUniformTeam('away-hero-small-home', 45);
    final notHero = smallHome.players
        .firstWhere((p) => smallHome.startingXI.contains(p.id));
    notHero.trait = PlayerTrait.awayDayHero;
    MatchEngine.simulate(
        home: smallHome,
        away: makeUniformTeam('away-hero-big-away', 60),
        matchday: 1);
    expect(notHero.matchFormMultiplier, 1.0);
  });

  test(
      'MatchEngine applies risingPhoenix only when morale is low AND '
      'determination is high, not for either condition alone', () {
    final team = makeUniformTeam('phoenix', 60);
    final phoenix =
        team.players.firstWhere((p) => team.startingXI.contains(p.id));
    phoenix.trait = PlayerTrait.risingPhoenix;
    phoenix.morale = 20;
    phoenix.setAttributeValue(AttributeKeys.determination, 80);
    MatchEngine.simulate(
        home: team, away: makeUniformTeam('phoenix-opp', 60), matchday: 1);
    expect(phoenix.matchFormMultiplier, 1.14);

    final team2 = makeUniformTeam('phoenix2', 60);
    final notPhoenix =
        team2.players.firstWhere((p) => team2.startingXI.contains(p.id));
    notPhoenix.trait = PlayerTrait.risingPhoenix;
    notPhoenix.morale = 80;
    notPhoenix.setAttributeValue(AttributeKeys.determination, 80);
    MatchEngine.simulate(
        home: team2, away: makeUniformTeam('phoenix2-opp', 60), matchday: 1);
    expect(notPhoenix.matchFormMultiplier, 1.0);
  });

  test(
      'MatchEngine applies veteranAce only for an older player in a tough '
      "(high opponent overall) match, not for a young player in the same "
      'match', () {
    final veteranTeam = makeUniformTeam('veteran-ace', 60);
    final veteran = veteranTeam.players
        .firstWhere((p) => veteranTeam.startingXI.contains(p.id));
    veteran.trait = PlayerTrait.veteranAce;
    veteran.age = 33;
    MatchEngine.simulate(
        home: veteranTeam,
        away: makeUniformTeam('veteran-ace-opp', 75),
        matchday: 1);
    expect(veteran.matchFormMultiplier, 1.11);

    final youngTeam = makeUniformTeam('young-ace', 60);
    final young = youngTeam.players
        .firstWhere((p) => youngTeam.startingXI.contains(p.id));
    young.trait = PlayerTrait.veteranAce;
    young.age = 22;
    MatchEngine.simulate(
        home: youngTeam,
        away: makeUniformTeam('young-ace-opp', 75),
        matchday: 1);
    expect(young.matchFormMultiplier, 1.0);
  });

  test(
      'MatchEngine applies underdogSpirit/dominantForce boosts only for a '
      'large (>=10) relative overall gap, unlike the smaller giantKiller/'
      'frontRunner gap', () {
    final weak = makeUniformTeam('weak', 50);
    final strong = makeUniformTeam('strong', 65);

    final underdog =
        weak.players.firstWhere((p) => weak.startingXI.contains(p.id));
    underdog.trait = PlayerTrait.underdogSpirit;
    final favorite =
        strong.players.firstWhere((p) => strong.startingXI.contains(p.id));
    favorite.trait = PlayerTrait.dominantForce;

    MatchEngine.simulate(home: weak, away: strong, matchday: 1);

    expect(underdog.matchFormMultiplier, 1.13);
    expect(favorite.matchFormMultiplier, 1.13);
  });

  test(
      'MatchEngine applies homeBoy/roadWarrior boosts only for the matching '
      'home/away side', () {
    final home = makeUniformTeam('home', 60);
    final away = makeUniformTeam('away', 60);

    final homeBoyOnHome =
        home.players.firstWhere((p) => home.startingXI.contains(p.id));
    homeBoyOnHome.trait = PlayerTrait.homeBoy;
    final homeBoyOnAway =
        away.players.firstWhere((p) => away.startingXI.contains(p.id));
    homeBoyOnAway.trait = PlayerTrait.homeBoy;
    final roadWarriorOnAway = away.players.firstWhere(
        (p) => away.startingXI.contains(p.id) && p.id != homeBoyOnAway.id);
    roadWarriorOnAway.trait = PlayerTrait.roadWarrior;

    MatchEngine.simulate(home: home, away: away, matchday: 1);

    expect(homeBoyOnHome.matchFormMultiplier, 1.05);
    expect(homeBoyOnAway.matchFormMultiplier, 1.0);
    expect(roadWarriorOnAway.matchFormMultiplier, 1.05);
  });

  test(
      'MatchEngine applies weather-specific trait boosts (rainMaster/'
      'snowMaster) only when the matching weather occurs', () {
    final rainTeam = makeUniformTeam('rain-team', 60);
    final rainPlayer =
        rainTeam.players.firstWhere((p) => rainTeam.startingXI.contains(p.id));
    rainPlayer.trait = PlayerTrait.rainMaster;
    MatchEngine.simulate(
        home: rainTeam,
        away: makeUniformTeam('rain-opp', 60),
        matchday: 1,
        weather: Weather.rain);
    expect(rainPlayer.matchFormMultiplier, 1.08);

    final clearTeam = makeUniformTeam('clear-team', 60);
    final clearPlayer = clearTeam.players
        .firstWhere((p) => clearTeam.startingXI.contains(p.id));
    clearPlayer.trait = PlayerTrait.rainMaster;
    MatchEngine.simulate(
        home: clearTeam,
        away: makeUniformTeam('clear-opp', 60),
        matchday: 1,
        weather: Weather.clear);
    expect(clearPlayer.matchFormMultiplier, 1.0);

    final snowTeam = makeUniformTeam('snow-team', 60);
    final snowPlayer =
        snowTeam.players.firstWhere((p) => snowTeam.startingXI.contains(p.id));
    snowPlayer.trait = PlayerTrait.snowMaster;
    MatchEngine.simulate(
        home: snowTeam,
        away: makeUniformTeam('snow-opp', 60),
        matchday: 1,
        weather: Weather.snow);
    expect(snowPlayer.matchFormMultiplier, 1.14);
  });

  test(
      'MatchEngine applies condition-based traits (ironLungs/confidentMind) '
      "based on the player's own fatigue/morale at kickoff", () {
    final tiredTeam = makeUniformTeam('tired-team', 60);
    final tiredPlayer = tiredTeam.players
        .firstWhere((p) => tiredTeam.startingXI.contains(p.id));
    tiredPlayer.trait = PlayerTrait.ironLungs;
    tiredPlayer.fatigue = 90;
    MatchEngine.simulate(
        home: tiredTeam, away: makeUniformTeam('tired-opp', 60), matchday: 1);
    expect(tiredPlayer.matchFormMultiplier, 1.07);

    final freshTeam = makeUniformTeam('fresh-team', 60);
    final freshPlayer = freshTeam.players
        .firstWhere((p) => freshTeam.startingXI.contains(p.id));
    freshPlayer.trait = PlayerTrait.ironLungs;
    freshPlayer.fatigue = 10;
    MatchEngine.simulate(
        home: freshTeam, away: makeUniformTeam('fresh-opp', 60), matchday: 1);
    expect(freshPlayer.matchFormMultiplier, 1.0);

    final confidentTeam = makeUniformTeam('confident-team', 60);
    final confidentPlayer = confidentTeam.players
        .firstWhere((p) => confidentTeam.startingXI.contains(p.id));
    confidentPlayer.trait = PlayerTrait.confidentMind;
    confidentPlayer.morale = 90;
    MatchEngine.simulate(
        home: confidentTeam,
        away: makeUniformTeam('confident-opp', 60),
        matchday: 1);
    expect(confidentPlayer.matchFormMultiplier, 1.06);

    final lowMoraleTeam = makeUniformTeam('low-morale-team', 60);
    final lowMoralePlayer = lowMoraleTeam.players
        .firstWhere((p) => lowMoraleTeam.startingXI.contains(p.id));
    lowMoralePlayer.trait = PlayerTrait.confidentMind;
    lowMoralePlayer.morale = 20;
    MatchEngine.simulate(
        home: lowMoraleTeam,
        away: makeUniformTeam('low-morale-opp', 60),
        matchday: 1);
    expect(lowMoralePlayer.matchFormMultiplier, 1.0);
  });

  test(
      'MatchEngine applies age-based traits (wonderkid/oldHead) based on the '
      "player's own age", () {
    final youngTeam = makeUniformTeam('young-team', 60);
    final young = youngTeam.players
        .firstWhere((p) => youngTeam.startingXI.contains(p.id));
    young.trait = PlayerTrait.wonderkid;
    young.age = 19;
    MatchEngine.simulate(
        home: youngTeam, away: makeUniformTeam('young-opp', 60), matchday: 1);
    expect(young.matchFormMultiplier, 1.08);

    final primeTeam = makeUniformTeam('prime-team', 60);
    final prime = primeTeam.players
        .firstWhere((p) => primeTeam.startingXI.contains(p.id));
    prime.trait = PlayerTrait.wonderkid;
    prime.age = 27;
    MatchEngine.simulate(
        home: primeTeam, away: makeUniformTeam('prime-opp', 60), matchday: 1);
    expect(prime.matchFormMultiplier, 1.0);

    final oldTeam = makeUniformTeam('old-team', 60);
    final old =
        oldTeam.players.firstWhere((p) => oldTeam.startingXI.contains(p.id));
    old.trait = PlayerTrait.oldHead;
    old.age = 35;
    MatchEngine.simulate(
        home: oldTeam, away: makeUniformTeam('old-opp', 60), matchday: 1);
    expect(old.matchFormMultiplier, 1.08);
  });

  test(
      'MatchEngine applies attribute-threshold traits (clinicalFinisher) '
      "based on the player's own attribute value", () {
    final giftedTeam = makeUniformTeam('gifted-team', 60);
    final gifted = giftedTeam.players
        .firstWhere((p) => giftedTeam.startingXI.contains(p.id));
    gifted.trait = PlayerTrait.clinicalFinisher;
    gifted.setAttributeValue(AttributeKeys.finishing, 90);
    MatchEngine.simulate(
        home: giftedTeam, away: makeUniformTeam('gifted-opp', 60), matchday: 1);
    expect(gifted.matchFormMultiplier, 1.07);

    final averageTeam = makeUniformTeam('average-team', 60);
    final average = averageTeam.players
        .firstWhere((p) => averageTeam.startingXI.contains(p.id));
    average.trait = PlayerTrait.clinicalFinisher;
    average.setAttributeValue(AttributeKeys.finishing, 50);
    MatchEngine.simulate(
        home: averageTeam,
        away: makeUniformTeam('average-opp', 60),
        matchday: 1);
    expect(average.matchFormMultiplier, 1.0);
  });

  test(
      'MatchEngine rolls volatileTalent within a wider 0.75-1.40 band and '
      'metronome within a tighter 0.95-1.05 band', () {
    final home = makeUniformTeam('home', 60);
    final away = makeUniformTeam('away', 60);
    final volatile =
        home.players.firstWhere((p) => home.startingXI.contains(p.id));
    volatile.trait = PlayerTrait.volatileTalent;
    final steady =
        away.players.firstWhere((p) => away.startingXI.contains(p.id));
    steady.trait = PlayerTrait.metronome;

    MatchEngine.simulate(home: home, away: away, matchday: 1);

    expect(volatile.matchFormMultiplier, inInclusiveRange(0.75, 1.40));
    expect(steady.matchFormMultiplier, inInclusiveRange(0.95, 1.05));
  });

  test(
      'streaky/volatileTalent have an expected matchFormMultiplier slightly '
      'above 1.0 over many rolls, unlike a plain 50-50 gamble, so taking the '
      'boom-or-bust risk is worthwhile on average like every other trait', () {
    double averageMultiplier(PlayerTrait trait) {
      var sum = 0.0;
      const trials = 500;
      for (int i = 0; i < trials; i++) {
        final home = makeUniformTeam('avg-home-$trait-$i', 60);
        final away = makeUniformTeam('avg-away-$trait-$i', 60);
        final p =
            home.players.firstWhere((p) => home.startingXI.contains(p.id));
        p.trait = trait;
        MatchEngine.simulate(home: home, away: away, matchday: 1);
        sum += p.matchFormMultiplier;
      }
      return sum / trials;
    }

    expect(averageMultiplier(PlayerTrait.streaky), greaterThan(1.0));
    expect(averageMultiplier(PlayerTrait.volatileTalent), greaterThan(1.0));
  });

  test(
      'ScoutingEngine.generateScoutedProspect finds clearly better prospects '
      'on average at a maxed-out scout level than at level 1', () {
    const sampleSize = 200;
    final level1Potentials = [
      for (int i = 0; i < sampleSize; i++)
        ScoutingEngine.generateScoutedProspect(scoutLevel: 1).potential
    ];
    final maxLevelPotentials = [
      for (int i = 0; i < sampleSize; i++)
        ScoutingEngine.generateScoutedProspect(
                scoutLevel: ClubInfrastructure.maxLevel)
            .potential
    ];
    final avgLevel1 = level1Potentials.reduce((a, b) => a + b) / sampleSize;
    final avgMaxLevel = maxLevelPotentials.reduce((a, b) => a + b) / sampleSize;
    expect(avgMaxLevel, greaterThan(avgLevel1 + 10));
  });

  test(
      'GameState.weeklyIncomeFor includes a baseline merchandising income even '
      'without a sponsor deal, so income does not depend solely on ticket '
      'sales and sponsorship', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.sponsorDeal = null;
    expect(gameState.weeklyIncomeFor(gameState.userTeam.id), greaterThan(0));
  });

  test(
      'PlayerPersonality has around 20 distinct patterns, each with a '
      'non-empty label/description and plausible sensitivity/growth values',
      () {
    expect(PlayerPersonality.values.length, greaterThanOrEqualTo(20));
    final seenLabels = <String>{};
    for (final p in PlayerPersonality.values) {
      expect(p.label, isNotEmpty, reason: '$p has no label');
      expect(p.description, isNotEmpty, reason: '$p has no description');
      expect(seenLabels.add(p.label), isTrue,
          reason: 'duplicate personality label: ${p.label}');
      expect(p.benchSensitivity, greaterThan(0));
      expect(p.wageSensitivity, greaterThan(0));
      expect(p.resultSensitivity, greaterThan(0));
      expect(p.transferRequestThreshold, inInclusiveRange(0, 100));
      expect(p.growthFactor, greaterThan(0));
      expect(p.marketValueFactor, greaterThan(0));
    }
  });

  test(
      'PlayerRole has around 20 distinct patterns spread across every '
      'position group, each with exactly 2 key attributes (standard aside)',
      () {
    expect(PlayerRole.values.length, greaterThanOrEqualTo(20));
    final seenLabels = <String>{};
    for (final r in PlayerRole.values) {
      expect(r.label, isNotEmpty, reason: '$r has no label');
      expect(r.description, isNotEmpty, reason: '$r has no description');
      expect(seenLabels.add(r.label), isTrue,
          reason: 'duplicate role label: ${r.label}');
      if (r == PlayerRole.standard) {
        expect(r.allowedGroups, PositionGroup.values);
        expect(r.keyAttributes, isEmpty);
      } else {
        expect(r.allowedGroups, isNotEmpty);
        expect(r.keyAttributes.length, 2);
      }
    }
    for (final group in PositionGroup.values) {
      final rolesForGroup = PlayerRole.values.where(
          (r) => r != PlayerRole.standard && r.allowedGroups.contains(group));
      expect(rolesForGroup, isNotEmpty,
          reason: '$group has no assignable role');
    }
  });

  test(
      'MatchEngine reflects the individual ability of whichever player '
      'actually takes an open-play chance: swapping just the starting '
      'striker for a much better or much worse one measurably changes '
      'average goals scored, not just a diluted team-wide average', () {
    double averageGoalsWithStriker(int strikerTier) {
      var totalGoals = 0;
      const trials = 400;
      for (int i = 0; i < trials; i++) {
        final team = PlayerGenerator.generateSquad(
            id: 'team', name: 'Team FC', strengthTier: 60);
        team.formation = Formation.f442;
        LineupUtils.autoFill(team);
        final striker =
            team.players.firstWhere((p) => p.position == Position.st);
        final replacement = PlayerGenerator.generate(
            position: Position.st, strengthTier: strikerTier, ageOverride: 25);
        final idx = team.players.indexOf(striker);
        team.players[idx] = replacement;
        final slotIdx = team.startingXI.indexOf(striker.id);
        if (slotIdx >= 0) team.startingXI[slotIdx] = replacement.id;

        final opponent = PlayerGenerator.generateSquad(
            id: 'opp', name: 'Opponent FC', strengthTier: 60);
        opponent.formation = Formation.f442;
        LineupUtils.autoFill(opponent);

        final result =
            MatchEngine.simulate(home: team, away: opponent, matchday: 1);
        totalGoals += result.homeGoals;
      }
      return totalGoals / trials;
    }

    final withEliteStriker = averageGoalsWithStriker(90);
    final withPoorStriker = averageGoalsWithStriker(25);
    expect(withEliteStriker, greaterThan(withPoorStriker + 0.15),
        reason:
            'an elite vs. a poor striker should produce a clearly different '
            'average goal output, not get diluted away by the rest of the '
            'lineup');
  });

  test(
      "PlayerGrowthType shifts each type's growth-friendly age window: an "
      "early-maturing player grows faster than a late-maturing player at "
      'age 20, and the relationship flips by age 29', () {
    final earlyAt20 = countStaminaGrowths(400,
        () => makeFreshPlayer(age: 20)..growthType = PlayerGrowthType.early);
    final lateAt20 = countStaminaGrowths(400,
        () => makeFreshPlayer(age: 20)..growthType = PlayerGrowthType.late);
    expect(earlyAt20, greaterThan(lateAt20));

    final earlyAt29 = countStaminaGrowths(400,
        () => makeFreshPlayer(age: 29)..growthType = PlayerGrowthType.early);
    final lateAt29 = countStaminaGrowths(400,
        () => makeFreshPlayer(age: 29)..growthType = PlayerGrowthType.late);
    expect(lateAt29, greaterThan(earlyAt29));
  });

  test(
      'PlayerGrowthType also shifts the age at which decline can start: an '
      'early-maturing player already risks decline at 29 while a balanced '
      'player of the same age does not decline at all', () {
    int declineCount(PlayerGrowthType type) {
      var count = 0;
      const trials = 300;
      for (int i = 0; i < trials; i++) {
        final p = makeFreshPlayer(age: 29, potential: 50);
        p.growthType = type;
        final before = {
          for (final k in AttributeKeys.all) k: p.attributeValue(k)
        };
        final team = Team(
            id: 't',
            name: 'T',
            players: [p],
            defaultTrainingFocus: TrainingFocus.rest);
        TrainingEngine.applyWeeklyTraining(team);
        if (AttributeKeys.all.any((k) => p.attributeValue(k) < before[k]!)) {
          count++;
        }
      }
      return count;
    }

    expect(declineCount(PlayerGrowthType.early), greaterThan(0));
    expect(declineCount(PlayerGrowthType.balanced), 0);
  });

  test(
      'TrainingEngine occasionally triggers a breakthrough (才能開花) that '
      'jumps an attribute by 2 or more in a single week (impossible via the '
      'normal +1-per-week growth path) and flags hadBreakthroughThisWeek', () {
    var breakthroughs = 0;
    var confirmedBigJumps = 0;
    const trials = 1500;
    for (int i = 0; i < trials; i++) {
      final p = makeFreshPlayer(age: 21, determination: 99, potential: 99);
      p.growthType = PlayerGrowthType.early;
      final before = {
        for (final k in AttributeKeys.all) k: p.attributeValue(k)
      };
      final team = Team(
          id: 't',
          name: 'T',
          players: [p],
          defaultTrainingFocus: TrainingFocus.attack);
      TrainingEngine.applyWeeklyTraining(team);
      if (p.hadBreakthroughThisWeek) {
        breakthroughs++;
        if (AttributeKeys.all
            .any((k) => p.attributeValue(k) - before[k]! >= 2)) {
          confirmedBigJumps++;
        }
      }
    }

    expect(breakthroughs, greaterThan(0));
    expect(confirmedBigJumps, breakthroughs,
        reason: 'every breakthrough week should include at least one '
            'attribute jumping by 2+ in a single week');
  });

  test(
      'GameState.runWeeklyTraining propagates hadBreakthroughThisWeek into '
      'PlayerGrowthSummary.isBreakthrough', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final p = gameState.userTeam.players.first;
    p.age = 21;
    // ポテンシャル上限に張り付くと、内部でロールが成功しても属性が変化せず
    // _diffTrainingResultsに一切現れなくなる(=いつまで待ってもフラグが
    // 観測できない)ため、余裕を持って99に引き上げておく。
    p.potential = 99;
    p.growthType = PlayerGrowthType.early;
    p.setAttributeValue(AttributeKeys.determination, 99);
    p.individualFocus = TrainingFocus.attack;

    var flagged = false;
    for (int i = 0; i < 500 && !flagged; i++) {
      gameState.save!.trainingDoneThisWeek = false;
      await gameState.runWeeklyTraining();
      final summary =
          gameState.lastTrainingResults.where((r) => r.playerId == p.id);
      if (summary.isNotEmpty && summary.first.isBreakthrough) {
        flagged = true;
      }
    }

    expect(flagged, isTrue,
        reason: 'a breakthrough should eventually be flagged and '
            'propagated into the training summary within 500 simulated '
            'weeks');
  });

  test(
      'GameState.playNextMatchday clears role references (captain/set-piece '
      'takers) and any pending installment when a loaned-in player\'s loan '
      'expires, matching the cleanup already done for sales/releases',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    final loanPlayer = team.players.first;
    loanPlayer.isLoan = true;
    loanPlayer.loanWeeksRemaining = 1;
    team.captainId = loanPlayer.id;
    team.freeKickTakerId = loanPlayer.id;

    await gameState.playNextMatchday();
    if (gameState.isHalfTime) {
      await gameState.playSecondHalf();
    }

    expect(team.players.any((p) => p.id == loanPlayer.id), isFalse);
    expect(team.captainId, isNull);
    expect(team.freeKickTakerId, isNull);
  });

  test(
      'GameState.playNextMatchday guards against being invoked again before '
      'the current half-time match finishes, so the other fixtures already '
      'decided in this matchday are not silently re-simulated with new '
      'random results', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final league = gameState.save!.league;
    final md = league.nextUnplayedFixture!.matchday;

    final firstHalf = await gameState.playNextMatchday();
    expect(firstHalf, isNotNull);
    expect(gameState.isHalfTime, isTrue);

    final decidedFixtures =
        league.fixturesForMatchday(md).where((f) => f.result != null).toList();
    expect(decidedFixtures, isNotEmpty);
    final resultsBefore = [for (final f in decidedFixtures) f.result];

    final second = await gameState.playNextMatchday();

    expect(second, isNull);
    expect(gameState.isHalfTime, isTrue);
    for (var i = 0; i < decidedFixtures.length; i++) {
      expect(identical(decidedFixtures[i].result, resultsBefore[i]), isTrue,
          reason: 'a fixture already decided this matchday must not be '
              'overwritten by a re-entrant playNextMatchday call');
    }
  });

  test(
      'GameState.startNextSeason resets trainingDoneThisWeek so training is '
      'not silently blocked for the entire preseason if the flag was left '
      'set true from the final week of the previous season', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    while (!gameState.save!.league.isSeasonComplete) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
    }
    gameState.save!.trainingDoneThisWeek = true;

    await gameState.startNextSeason();

    expect(gameState.save!.trainingDoneThisWeek, isFalse);
  });

  test(
      'GameState.sellPlayer and acceptIncomingOffer refuse to dispose of a '
      'player who is currently loaned out to another club', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    final target =
        team.players.firstWhere((p) => !team.startingXI.contains(p.id));
    target.loanedOutToClubName = 'よそのクラブ';
    target.loanedOutWeeksRemaining = 4;

    final soldOk = await gameState.sellPlayer(target.id);
    expect(soldOk, isFalse);
    expect(team.players.any((p) => p.id == target.id), isTrue);

    gameState.save!.incomingOffers.add(IncomingOffer(
      id: 'loaned-out-offer',
      playerId: target.id,
      playerName: target.name,
      buyerClubName: 'また別のクラブ',
      amount: 500,
    ));
    final acceptedOk = await gameState.acceptIncomingOffer('loaned-out-offer');
    expect(acceptedOk, isFalse);
    expect(team.players.any((p) => p.id == target.id), isTrue);
    expect(
        gameState.save!.incomingOffers.any((o) => o.id == 'loaned-out-offer'),
        isTrue);
  });

  test(
      'GameState.buyPlayer fails gracefully instead of throwing when the '
      'requested player is no longer in the transfer market', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    final ok = await gameState.buyPlayer('no-such-player-id');

    expect(ok, isFalse);
  });

  test(
      'MatchEngine re-rolls matchFormMultiplier for a player who enters the '
      'lineup for the first time at half-time (e.g. a substitute), instead '
      'of silently reusing a stale value left over from a previous match', () {
    final home = PlayerGenerator.generateSquad(
        id: 'home-sub', name: 'Home FC', strengthTier: 60);
    home.formation = Formation.f442;
    LineupUtils.autoFill(home);
    final away = PlayerGenerator.generateSquad(
        id: 'away-sub', name: 'Away FC', strengthTier: 60);
    away.formation = Formation.f442;
    LineupUtils.autoFill(away);

    MatchEngine.simulateMinutes(
        home: home, away: away, startMinute: 1, endMinute: 45);

    final bench =
        home.players.firstWhere((p) => !home.startingXI.contains(p.id));
    bench.trait = PlayerTrait.streaky;
    // 前の試合から残っていそうな、streakyの範囲(0.85〜1.25)外の値を仕込む。
    bench.matchFormMultiplier = 5.0;
    bench.matchFormRolledThisMatch = false;
    home.startingXI[0] = bench.id;

    MatchEngine.simulateMinutes(
        home: home, away: away, startMinute: 46, endMinute: 90);

    expect(bench.matchFormRolledThisMatch, isTrue);
    expect(bench.matchFormMultiplier, inInclusiveRange(0.85, 1.25));
  });

  test(
      "MatchEngine converts a player's second yellow card within the same "
      'half into a red card instead of silently recording two independent '
      'yellows', () {
    var sawAnyRedCard = false;
    const trials = 3000;
    for (int i = 0; i < trials; i++) {
      final home = PlayerGenerator.generateSquad(
          id: 'card-h', name: 'Home FC', strengthTier: 60);
      home.formation = Formation.f442;
      LineupUtils.autoFill(home);
      final away = PlayerGenerator.generateSquad(
          id: 'card-a', name: 'Away FC', strengthTier: 60);
      away.formation = Formation.f442;
      LineupUtils.autoFill(away);

      final half = MatchEngine.simulateMinutes(
          home: home, away: away, startMinute: 1, endMinute: 45);

      final yellowCountByPlayer = <String, int>{};
      for (final e in half.events) {
        if (e.type == MatchEventType.yellowCard && e.scorerId != null) {
          yellowCountByPlayer[e.scorerId!] =
              (yellowCountByPlayer[e.scorerId!] ?? 0) + 1;
        }
      }
      expect(yellowCountByPlayer.values.every((c) => c <= 1), isTrue,
          reason: 'no player should ever be recorded with two yellow cards '
              'within the same half; a second offense must become a red '
              'card instead');

      if (half.events.any((e) => e.type == MatchEventType.redCard)) {
        sawAnyRedCard = true;
      }
    }

    expect(sawAnyRedCard, isTrue,
        reason: 'expected at least one red card to occur across $trials '
            'simulated halves');
  });

  test(
      'RotationEngine.suggest never recommends the same bench player as the '
      'replacement for two different fatigued starters', () {
    final starter1 = makeFreshPlayer(position: Position.dc);
    starter1.fatigue = 90;
    final starter2 = makeFreshPlayer(position: Position.dc);
    starter2.fatigue = 90;
    final freshBench = makeFreshPlayer(position: Position.dc);
    freshBench.fatigue = 5;
    final filler = [
      for (int i = 0; i < 9; i++) makeFreshPlayer(position: Position.st)
    ];

    final team = Team(
      id: 't',
      name: 'T',
      players: [starter1, starter2, freshBench, ...filler],
    );
    team.startingXI = [starter1.id, starter2.id, ...filler.map((p) => p.id)];

    final suggestions = RotationEngine.suggest(team);
    final replacementIds = suggestions.map((s) => s.replacementId).toList();

    expect(replacementIds, contains(freshBench.id));
    expect(replacementIds.toSet().length, replacementIds.length,
        reason: 'the same bench player must not be suggested as the '
            'replacement for two different starters');
  });

  test(
      "Player.marketValueBreakdown's components combine to exactly "
      'reproduce marketValue', () {
    final p = makeFreshPlayer(age: 24);
    final b = p.marketValueBreakdown;
    final recombined = ((b.base + b.potentialBonus) *
            b.ageFactor *
            b.personalityFactor *
            b.leadershipFactor)
        .round()
        .clamp(50, 20000);
    expect(recombined, p.marketValue);
  });

  test(
      'TrainingEngine.applyYouthAcademyGrowth respects a youth prospect\'s '
      'individualFocus, growing the chosen attribute group instead of the '
      'position-based default', () {
    int finishingGrowths(TrainingFocus? focus) {
      var growths = 0;
      const trials = 400;
      for (int i = 0; i < trials; i++) {
        final p = makeFreshPlayer(position: Position.mc);
        p.individualFocus = focus;
        TrainingEngine.applyYouthAcademyGrowth([p], 5);
        if (p.attributeValue(AttributeKeys.finishing) > 50) growths++;
      }
      return growths;
    }

    final withAttackFocus = finishingGrowths(TrainingFocus.attack);
    final withDefenseFocus = finishingGrowths(TrainingFocus.defense);
    expect(withAttackFocus, greaterThan(withDefenseFocus));
  });

  test(
      'ScoutingEngine.estimatedPotentialRange always brackets the true '
      'potential and narrows as scoutLevel increases', () {
    final p = PlayerGenerator.generate(position: Position.st, strengthTier: 70);
    final wide = ScoutingEngine.estimatedPotentialRange(p, scoutLevel: 1);
    final narrow = ScoutingEngine.estimatedPotentialRange(p, scoutLevel: 8);

    expect(wide.$1, lessThanOrEqualTo(p.potential));
    expect(wide.$2, greaterThanOrEqualTo(p.potential));
    expect(narrow.$1, lessThanOrEqualTo(p.potential));
    expect(narrow.$2, greaterThanOrEqualTo(p.potential));
    expect(narrow.$2 - narrow.$1, lessThan(wide.$2 - wide.$1));
  });

  test(
      'ScoutingEngine.refreshCostFor decreases with scoutLevel and clamps '
      'at the floor', () {
    expect(ScoutingEngine.refreshCostFor(1), ScoutingEngine.refreshCost);
    expect(ScoutingEngine.refreshCostFor(8),
        lessThan(ScoutingEngine.refreshCostFor(1)));
    expect(ScoutingEngine.refreshCostFor(100), greaterThanOrEqualTo(60));
  });

  test(
      'GameState.refreshScoutCandidates charges scoutRefreshCost and fails '
      'without charging or regenerating the pool when the budget is '
      'insufficient', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final cost = gameState.scoutRefreshCost;
    gameState.save!.budget = cost;

    final ok = await gameState.refreshScoutCandidates();

    expect(ok, isTrue);
    expect(gameState.save!.budget, 0);

    gameState.save!.budget = cost - 1;
    final beforeSecond = gameState.scoutCandidates.map((p) => p.id).toList();
    final ok2 = await gameState.refreshScoutCandidates();
    expect(ok2, isFalse);
    expect(gameState.save!.budget, cost - 1);
    expect(gameState.scoutCandidates.map((p) => p.id).toList(), beforeSecond);
  });

  test(
      'MatchEngine.simulate reports possession/shots stats that are '
      'internally consistent', () {
    final home = PlayerGenerator.generateSquad(
        id: 'stats-home', name: 'Stats Home FC', strengthTier: 65);
    final away = PlayerGenerator.generateSquad(
        id: 'stats-away', name: 'Stats Away FC', strengthTier: 65);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    final result = MatchEngine.simulate(home: home, away: away, matchday: 1);

    expect(result.homePossession, isNotNull);
    expect(result.awayPossession, isNotNull);
    expect(result.homePossession! + result.awayPossession!, 100);
    expect(result.homePossession!, inInclusiveRange(0, 100));
    expect(result.homeShots, isNotNull);
    expect(result.awayShots, isNotNull);
    expect(result.homeShotsOnTarget!, lessThanOrEqualTo(result.homeShots!));
    expect(result.awayShotsOnTarget!, lessThanOrEqualTo(result.awayShots!));
    expect(result.homeGoals, lessThanOrEqualTo(result.homeShotsOnTarget!));
    expect(result.awayGoals, lessThanOrEqualTo(result.awayShotsOnTarget!));
  });

  test(
      'MatchEngine.simulate assigns goal assists from a teammate other than '
      'the scorer, and both assisted and unassisted goals occur over many '
      'matches', () {
    bool sawAssisted = false;
    bool sawUnassisted = false;
    for (int i = 0; i < 60; i++) {
      final home = PlayerGenerator.generateSquad(
          id: 'assist-home-$i', name: 'Assist Home FC', strengthTier: 70);
      final away = PlayerGenerator.generateSquad(
          id: 'assist-away-$i', name: 'Assist Away FC', strengthTier: 70);
      LineupUtils.autoFill(home);
      LineupUtils.autoFill(away);
      final result = MatchEngine.simulate(home: home, away: away, matchday: 1);
      for (final e in result.events) {
        if (e.type != MatchEventType.goal) continue;
        if (e.assistId != null) {
          sawAssisted = true;
          expect(e.assistId, isNot(e.scorerId));
          expect(e.assistName, isNotNull);
        } else {
          sawUnassisted = true;
        }
      }
      if (sawAssisted && sawUnassisted) break;
    }
    expect(sawAssisted, isTrue, reason: 'アシスト付きのゴールが一度も発生しなかった');
    expect(sawUnassisted, isTrue, reason: 'アシストなしのゴールが一度も発生しなかった(PK・個人技等)');
  });

  test('MatchResult.fromJson defaults new stats fields to null for old saves',
      () {
    final legacyJson = {
      'matchday': 5,
      'homeTeamId': 'home',
      'awayTeamId': 'away',
      'homeGoals': 1,
      'awayGoals': 0,
      'events': <Map<String, dynamic>>[],
    };

    final result = MatchResult.fromJson(legacyJson);

    expect(result.homePossession, isNull);
    expect(result.awayPossession, isNull);
    expect(result.homeShots, isNull);
    expect(result.awayShots, isNull);
    expect(result.homeShotsOnTarget, isNull);
    expect(result.awayShotsOnTarget, isNull);
  });

  test('MatchResult/MatchEvent round-trip through JSON preserves new fields',
      () {
    final original = MatchResult(
      matchday: 3,
      homeTeamId: 'home',
      awayTeamId: 'away',
      homeGoals: 1,
      awayGoals: 0,
      events: [
        MatchEvent(
          minute: 12,
          teamId: 'home',
          scorerName: '得点者',
          scorerId: 'scorer-1',
          assistName: 'アシスト者',
          assistId: 'assist-1',
        ),
      ],
      homePossession: 58,
      awayPossession: 42,
      homeShots: 10,
      awayShots: 6,
      homeShotsOnTarget: 4,
      awayShotsOnTarget: 2,
    );

    final restored = MatchResult.fromJson(original.toJson());

    expect(restored.homePossession, 58);
    expect(restored.awayPossession, 42);
    expect(restored.homeShots, 10);
    expect(restored.awayShots, 6);
    expect(restored.homeShotsOnTarget, 4);
    expect(restored.awayShotsOnTarget, 2);
    expect(restored.events.single.assistName, 'アシスト者');
    expect(restored.events.single.assistId, 'assist-1');
  });

  test('matchCommentaryText is deterministic and reflects assist presence', () {
    final withAssist = MatchEvent(
      minute: 30,
      teamId: 'home',
      scorerName: '選手A',
      scorerId: 'a',
      assistName: '選手B',
      assistId: 'b',
    );
    final withoutAssist = MatchEvent(
      minute: 30,
      teamId: 'home',
      scorerName: '選手A',
      scorerId: 'a',
    );

    final text1 = matchCommentaryText(withAssist, 'ホームFC');
    final text2 = matchCommentaryText(withAssist, 'ホームFC');
    expect(text1, text2);
    expect(text1, contains('選手B'));

    final textNoAssist = matchCommentaryText(withoutAssist, 'ホームFC');
    expect(textNoAssist, isNot(contains('選手B')));
    expect(textNoAssist, contains('選手A'));
  });

  test(
      'MatchEngine.simulate produces cross-assisted header goals originating '
      'from wide positions over many matches', () {
    const wideSidePositions = {
      Position.dr,
      Position.dl,
      Position.wbr,
      Position.wbl,
      Position.mr,
      Position.ml,
      Position.amr,
      Position.aml,
    };
    bool sawWideAssistedHeader = false;
    for (int i = 0; i < 80; i++) {
      final home = PlayerGenerator.generateSquad(
          id: 'wide-home-$i', name: 'Wide Home FC', strengthTier: 70);
      final away = PlayerGenerator.generateSquad(
          id: 'wide-away-$i', name: 'Wide Away FC', strengthTier: 70);
      LineupUtils.autoFill(home);
      LineupUtils.autoFill(away);
      final result = MatchEngine.simulate(home: home, away: away, matchday: 1);
      final allPlayers = {
        for (final p in [...home.players, ...away.players]) p.id: p,
      };
      for (final e in result.events) {
        if (e.type != MatchEventType.goal || e.assistId == null) continue;
        final assistPlayer = allPlayers[e.assistId];
        final scorerPlayer = allPlayers[e.scorerId];
        if (assistPlayer != null &&
            wideSidePositions.contains(assistPlayer.position) &&
            scorerPlayer != null &&
            scorerPlayer.position.group == PositionGroup.att) {
          sawWideAssistedHeader = true;
          break;
        }
      }
      if (sawWideAssistedHeader) break;
    }
    expect(sawWideAssistedHeader, isTrue,
        reason: 'サイドからのクロス→ヘディングによるアシスト付きゴールが一度も発生しなかった');
  });

  test(
      'MatchEngine.computePlayerRatings rewards the assist provider in '
      'addition to the scorer', () {
    final home = PlayerGenerator.generateSquad(
        id: 'rate-home', name: 'Rate Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'rate-away', name: 'Rate Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);
    final homeLineup = MatchEngine.lineupOf(home);
    final scorer = homeLineup[0];
    final assistProvider = homeLineup[1];
    final neutral = homeLineup[2];

    final events = [
      MatchEvent(
        minute: 10,
        teamId: home.id,
        scorerName: scorer.name,
        scorerId: scorer.id,
        assistName: assistProvider.name,
        assistId: assistProvider.id,
      ),
    ];

    final ratings = MatchEngine.computePlayerRatings(
        home: home, away: away, events: events, homeGoals: 1, awayGoals: 0);

    expect(ratings[assistProvider.id], ratings[neutral.id]! + 0.5);
    expect(ratings[scorer.id], greaterThan(ratings[assistProvider.id]!));
  });

  test(
      'GameState.talkToPlayer boosts morale once, then blocks during '
      'cooldown', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    player.morale = 50;

    final ok1 = await gameState.talkToPlayer(player.id);
    expect(ok1, isTrue);
    expect(player.morale, greaterThan(50));
    expect(player.talkCooldownWeeks, TrainingEngine.talkCooldownWeeks);

    final moraleAfterFirst = player.morale;
    final ok2 = await gameState.talkToPlayer(player.id);
    expect(ok2, isFalse);
    expect(player.morale, moraleAfterFirst);
  });

  test(
      'GameState.holdTacticalMeeting grows mental attributes for at least '
      'one player, then enforces a cooldown', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    for (final p in gameState.userTeam.players) {
      p.potential = 99;
      p.setAttributeValue(AttributeKeys.decisions, 40);
      p.setAttributeValue(AttributeKeys.positioning, 40);
      p.setAttributeValue(AttributeKeys.teamwork, 40);
    }
    int mentalSum(Player p) =>
        p.attributeValue(AttributeKeys.decisions) +
        p.attributeValue(AttributeKeys.positioning) +
        p.attributeValue(AttributeKeys.teamwork);
    final before = {
      for (final p in gameState.userTeam.players) p.id: mentalSum(p),
    };

    final ok = await gameState.holdTacticalMeeting();
    expect(ok, isTrue);
    expect(gameState.userTeam.tacticalMeetingCooldownWeeks,
        GameState.tacticalMeetingCooldownWeeks);

    final grew =
        gameState.userTeam.players.any((p) => mentalSum(p) > before[p.id]!);
    expect(grew, isTrue);

    final ok2 = await gameState.holdTacticalMeeting();
    expect(ok2, isFalse);
  });

  test('Player/Team round-trip through JSON preserves new cooldown fields', () {
    final player =
        PlayerGenerator.generate(position: Position.st, strengthTier: 60)
          ..talkCooldownWeeks = 2;
    final restoredPlayer = Player.fromJson(player.toJson());
    expect(restoredPlayer.talkCooldownWeeks, 2);

    final team = PlayerGenerator.generateSquad(
        id: 'json-team', name: 'JSON FC', strengthTier: 60)
      ..tacticalMeetingCooldownWeeks = 2;
    final restoredTeam = Team.fromJson(team.toJson());
    expect(restoredTeam.tacticalMeetingCooldownWeeks, 2);
  });

  test(
      'GameState.startCupMatchLive plays a domestic cup match through the '
      'same live interactive engine as league matches, applies the result '
      'to the bracket (with a penalty winner on a draw), records post-match '
      'effects (appearances) for user players, and pays a win prize', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    // ブラケット消化順が自クラブの試合になるまで、他カードのカップ試合と
    // リーグ戦(消化間隔の解消のため)を進める。自クラブの試合は自動では
    // 消化しないため、必ずいずれ自クラブの番が来る。
    for (int guard = 0; guard < 300; guard++) {
      if (gameState.canPlayNextDomesticCupMatchLive) break;
      if (gameState.domesticCup == null || gameState.domesticCup!.isComplete) {
        break;
      }
      if (gameState.canPlayNextDomesticCupMatch) {
        await gameState.playNextCupMatch();
      } else {
        await gameState.playNextMatchday();
        await gameState.playSecondHalf();
      }
    }
    expect(gameState.canPlayNextDomesticCupMatchLive, isTrue);

    final cup = gameState.domesticCup!;
    final match = cup.nextUnplayedMatch!;
    final userId = gameState.userTeam.id;
    final budgetBefore = gameState.save!.budget;
    final appsBefore = gameState.userTeam.players
        .fold<int>(0, (s, p) => s + p.careerAppearances);

    expect(await gameState.startCupMatchLive(LiveCupKind.domestic), isTrue);
    expect(gameState.liveCupDescriptor, isNotNull);
    expect(gameState.liveCupDescriptor!.competitionLabel, cup.name);

    // リーグ戦のライブ観戦と同じAPIで最後まで進行できる。
    while (gameState.pendingChanceDecision != null) {
      await gameState.resolveChanceDecision(ChanceDecision.shoot);
    }
    MatchResult? merged = await gameState.playSecondHalf(interactive: true);
    while (merged == null && gameState.pendingChanceDecision != null) {
      merged =
          (await gameState.resolveChanceDecision(ChanceDecision.shoot)).merged;
    }
    expect(merged, isNotNull);

    // 結果がブラケットに適用され、ライブ状態はクリアされている。
    expect(match.result, isNotNull);
    expect(match.result!.homeGoals, merged!.homeGoals);
    expect(match.result!.awayGoals, merged.awayGoals);
    expect(gameState.liveCupDescriptor, isNull);
    if (merged.homeGoals == merged.awayGoals) {
      expect(match.penaltyWinnerId, isNotNull, reason: 'ノックアウトの引き分けはPK戦で決着する');
    }
    if (match.winnerId == userId) {
      expect(gameState.save!.budget, greaterThan(budgetBefore),
          reason: 'カップ戦の勝ち上がり賞金が入る');
    }

    // カップ戦でも試合後効果が適用され、出場記録が増える。
    final appsAfter = gameState.userTeam.players
        .fold<int>(0, (s, p) => s + p.careerAppearances);
    expect(appsAfter, greaterThan(appsBefore));
  });

  test(
      'GameState.playNextCupMatch (quick-sim path) also applies post-match '
      'effects to user players, so playing live and quick-simming cup '
      'matches carry the same physical consequences', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    for (int guard = 0; guard < 300; guard++) {
      if (gameState.canPlayNextDomesticCupMatchLive) break;
      if (gameState.domesticCup == null || gameState.domesticCup!.isComplete) {
        break;
      }
      if (gameState.canPlayNextDomesticCupMatch) {
        await gameState.playNextCupMatch();
      } else {
        await gameState.playNextMatchday();
        await gameState.playSecondHalf();
      }
    }
    expect(gameState.canPlayNextDomesticCupMatchLive, isTrue);
    final appsBefore = gameState.userTeam.players
        .fold<int>(0, (s, p) => s + p.careerAppearances);
    final result = await gameState.playNextCupMatch();
    expect(result, isNotNull);
    final appsAfter = gameState.userTeam.players
        .fold<int>(0, (s, p) => s + p.careerAppearances);
    expect(appsAfter, greaterThan(appsBefore));
  });

  test(
      'GameState.setDevelopmentTargetRole accepts only roles allowed for the '
      "player's position group (standard is rejected), and the plan "
      'round-trips through JSON', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final gk = gameState.userTeam.players
        .firstWhere((p) => p.position.group == PositionGroup.gk);

    gameState.setDevelopmentTargetRole(gk.id, PlayerRole.poacher);
    expect(gk.developmentTargetRole, isNull, reason: 'FW用ロールはGKに設定できない');

    gameState.setDevelopmentTargetRole(gk.id, PlayerRole.standard);
    expect(gk.developmentTargetRole, isNull, reason: 'standardは目標にできない');

    gameState.setDevelopmentTargetRole(gk.id, PlayerRole.sweeperKeeper);
    expect(gk.developmentTargetRole, PlayerRole.sweeperKeeper);

    final restored = Player.fromJson(gk.toJson());
    expect(restored.developmentTargetRole, PlayerRole.sweeperKeeper);

    gameState.setDevelopmentTargetRole(gk.id, null);
    expect(gk.developmentTargetRole, isNull);
  });

  test(
      'a development plan (target role) makes the weekly training grow that '
      "role's key attributes clearly faster than an otherwise identical "
      'player without a plan', () {
    Team buildSoloTeam(String id, {PlayerRole? plan}) {
      final p = Player(
        id: '$id-p',
        name: '$id-p',
        age: 20,
        position: Position.dm,
        potential: 99,
      );
      for (final key in AttributeKeys.all) {
        p.setAttributeValue(key, 30);
      }
      p.developmentTargetRole = plan;
      final team = Team(id: id, name: id, players: [p]);
      return team;
    }

    int keySum(Team t) {
      final p = t.players.first;
      return PlayerRole.anchorMan.keyAttributes
          .fold<int>(0, (s, k) => s + p.attributeValue(k));
    }

    final planned = buildSoloTeam('plan', plan: PlayerRole.anchorMan);
    final unplanned = buildSoloTeam('noplan');
    const weeks = 200;
    for (int i = 0; i < weeks; i++) {
      // 疲労・負傷でトレーニング効果が偏らないよう、毎週リセットして
      // 純粋な成長判定の差だけを比較する。
      for (final t in [planned, unplanned]) {
        final p = t.players.first;
        p.fatigue = 0;
        p.injuryWeeks = 0;
      }
      TrainingEngine.applyWeeklyTraining(planned);
      TrainingEngine.applyWeeklyTraining(unplanned);
    }
    expect(keySum(planned), greaterThan(keySum(unplanned)),
        reason: '育成プランの重視能力値(タックル・ポジショニング)が優先的に伸びるはず');
  });
}
