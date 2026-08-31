import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/contract_engine.dart';
import '../logic/dynamics_engine.dart';
import '../logic/lineup_utils.dart';
import '../logic/match_engine.dart';
import '../models/attributes.dart';
import '../models/contract_negotiation.dart';
import '../models/player.dart';
import '../models/training_result.dart';
import '../data/glossary_entries.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import 'glossary_screen.dart';
import '../widgets/attribute_radar.dart';
import '../widgets/growth_sparkline.dart';
import '../widgets/player_face_avatar.dart';
import '../widgets/stat_bar.dart';
import '../l10n/tr.dart';

class PlayerDetailScreen extends StatelessWidget {
  final String playerId;

  const PlayerDetailScreen({super.key, required this.playerId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;
    final p = team.players.firstWhere((pl) => pl.id == playerId);
    final isStarting = team.startingXI.contains(p.id);
    final netReleaseValue = gameState.netReleaseValueFor(p.id);
    final renewalCost = gameState.renewalCostFor(p.id);
    final signingBonus = gameState.signingBonusFor(p.id);
    final newAppearanceFee = gameState.appearanceFeeFor(p.id);
    final totalRenewalCost = renewalCost + signingBonus;
    final negotiation = gameState.pendingContractNegotiation;
    final isNegotiatingThisPlayer =
        negotiation != null && negotiation.playerId == p.id;
    final seasonStats = gameState.seasonStatsFor(p.id);
    final assignedSlot =
        LineupUtils.assignedSlotByPlayerId(team)[p.id] ?? p.position;
    PlayerGrowthSummary? latestGrowth;
    for (final r in gameState.lastTrainingResults) {
      if (r.playerId == p.id) {
        latestGrowth = r;
        break;
      }
    }

    final categories = [
      AttributeCategory.technical,
      AttributeCategory.mental,
      AttributeCategory.physical,
      if (p.position == Position.gk) AttributeCategory.goalkeeping,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: Tr.pick('能力値の意味を見る', 'What the attributes mean'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const GlossaryScreen(
                  initialCategory: GlossaryCategory.attribute,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              PlayerFaceAvatar(
                playerId: p.id,
                position: p.position,
                size: 56,
                highlighted: true,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  Tr.pick('${p.position.fullLabel} ・ ${p.age}歳',
                      '${p.position.fullLabel} · ${p.age}'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (p.secondaryPositions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                Tr.pick(
                    '対応可能ポジション: ${p.secondaryPositions.map((s) => s.label).join(', ')}',
                    "Also plays: ${p.secondaryPositions.map((s) => s.label).join(', ')}"),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          Builder(
            builder: (context) {
              final familiarities = [
                for (final pos in Position.values)
                  if (pos != p.position &&
                      !p.secondaryPositions.contains(pos) &&
                      p.familiarityFor(pos) > 0)
                    (pos: pos, value: p.familiarityFor(pos)),
              ]..sort((a, b) => b.value.compareTo(a.value));
              if (familiarities.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  Tr.pick(
                      'ポジション慣れ度(習得中): ${familiarities.map((f) => '${f.pos.label} ${f.value}/100').join(' / ')}${p.trainingConvertTargetPosition != null ? ' ★コンバート特訓中' : ''}',
                      "Learning positions: ${familiarities.map((f) => '${f.pos.label} ${f.value}/100').join(' / ')}${p.trainingConvertTargetPosition != null ? ' ★retraining' : ''}"),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              );
            },
          ),
          if (seasonStats.appearances > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                Tr.pick(
                    '今シーズン: ${seasonStats.appearances}試合 ${seasonStats.goals}得点${seasonStats.yellowCards > 0 ? ' 警告${seasonStats.yellowCards}' : ''}${seasonStats.redCards > 0 ? ' 退場${seasonStats.redCards}' : ''} / 平均採点${seasonStats.averageRating!.toStringAsFixed(1)}',
                    "This season: ${seasonStats.appearances} apps, ${seasonStats.goals} goals${seasonStats.yellowCards > 0 ? ', ${seasonStats.yellowCards} yellow' : ''}${seasonStats.redCards > 0 ? ', ${seasonStats.redCards} red' : ''} / avg rating ${seasonStats.averageRating!.toStringAsFixed(1)}"),
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (p.careerAppearances > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                Tr.pick('通算成績: ${p.careerAppearances}試合 ${p.careerGoals}得点',
                    'Career: ${p.careerAppearances} apps, ${p.careerGoals} goals'),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (isStarting)
                Chip(
                  label: Text(Tr.pick('スタメン', 'Starter')),
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                ),
              if (team.captainId == p.id)
                Chip(
                  label: Text(Tr.pick('キャプテン', 'Captain')),
                  backgroundColor: Colors.amber,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              if (team.viceCaptainId == p.id)
                Chip(
                  label: Text(Tr.pick('副キャプテン', 'Vice Captain')),
                  backgroundColor: Colors.blueGrey,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              // ダイナミクス: 影響力上位のチームリーダー。機嫌がロッカー
              // ルーム全体へ波及し、放出するとチームが動揺する。
              if (DynamicsEngine.isTeamLeader(team, p.id))
                Chip(
                  label: Text(Tr.pick('チームリーダー', 'Team Leader')),
                  backgroundColor: Colors.deepOrange,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              if (p.isLoan)
                Chip(
                  label: Text(Tr.pick('ローン加入中', 'On loan here')),
                  backgroundColor: Colors.indigo,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              if (p.wantsTransfer)
                Chip(
                  label: Text(Tr.pick('移籍を希望している', 'Wants a move away')),
                  backgroundColor: Colors.redAccent,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              Chip(label: Text(p.personality.label)),
              if (p.isOnInternationalDuty)
                Chip(
                  label: Text(Tr.pick('代表召集中', 'On international duty')),
                  backgroundColor: Colors.blueAccent,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              if (p.isLoanedOut)
                Chip(
                  label: Text(Tr.pick('${p.loanedOutToClubName}へローン中',
                      'On loan at ${p.loanedOutToClubName}')),
                  backgroundColor: Colors.deepPurple,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              if (p.isTransferListed)
                Chip(
                  label: Text(Tr.pick('移籍リスト登録中', 'Transfer listed')),
                  backgroundColor: Colors.orange,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
            ],
          ),
          if (p.isInjured)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                p.injuryType == null
                    ? Tr.pick('負傷中（あと${p.injuryWeeks}週は出場不可）',
                        'Injured (out for another ${p.injuryWeeks} weeks)')
                    : Tr.pick(
                        '${p.injuryType!.label}で負傷中（あと${p.injuryWeeks}週は出場不可）',
                        '${p.injuryType!.label} (out for another ${p.injuryWeeks} weeks)'),
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (p.injuryHistoryCounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${Tr.pick('負傷歴', 'Injury history')}: ${p.injuryHistoryCounts.entries.map((e) {
                  final type = InjuryType.values.firstWhere(
                      (t) => t.name == e.key,
                      orElse: () => InjuryType.bruise);
                  return Tr.pick(
                      '${type.label}${e.value}回', '${type.label} x${e.value}');
                }).join(Tr.pick('・', ' · '))}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          if (p.isSuspended)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                Tr.pick('出場停止中（あと${p.suspendedMatches}試合は出場不可）',
                    'Suspended (out for another ${p.suspendedMatches} matches)'),
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (p.yellowCards > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                Tr.pick(
                    '警告累積: ${p.yellowCards}/$yellowCardSuspensionThreshold(あと${yellowCardSuspensionThreshold - p.yellowCards}枚で出場停止)',
                    'Yellow cards: ${p.yellowCards}/$yellowCardSuspensionThreshold (${yellowCardSuspensionThreshold - p.yellowCards} more brings a ban)'),
                style: TextStyle(
                  color: p.yellowCards >= yellowCardSuspensionThreshold - 1
                      ? Colors.redAccent
                      : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
          if (p.isOnInternationalDuty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                Tr.pick('代表召集中（あと${p.internationalDutyWeeksRemaining}週は出場不可）',
                    'On international duty (away for another ${p.internationalDutyWeeksRemaining} weeks)'),
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                Tr.pick('総合力: ${p.overall}', 'Overall: ${p.overall}'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (latestGrowth != null && latestGrowth.overallDelta != 0) ...[
                const SizedBox(width: 8),
                Text(
                  Tr.pick(
                      '(今週${latestGrowth.overallDelta > 0 ? '+' : ''}${latestGrowth.overallDelta})',
                      " (this week ${latestGrowth.overallDelta > 0 ? '+' : ''}${latestGrowth.overallDelta})"),
                  style: TextStyle(
                    color: latestGrowth.overallDelta > 0
                        ? Colors.green
                        : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          Builder(
            builder: (context) {
              final potentialProgress = p.potential > 0
                  ? (p.overall / p.potential * 100).clamp(0, 100)
                  : 0.0;
              final seasonStart =
                  gameState.save?.seasonStartOverallByPlayerId[p.id];
              final seasonDelta =
                  seasonStart != null ? p.overall - seasonStart : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text(
                      Tr.pick(
                          '潜在能力到達度: ${potentialProgress.toStringAsFixed(0)}%',
                          'Potential reached: ${potentialProgress.toStringAsFixed(0)}%'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.purple,
                      ),
                    ),
                    if (seasonDelta != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        Tr.pick(
                            '今シーズンの成長: ${seasonDelta > 0 ? '+' : ''}$seasonDelta',
                            "Growth this season: ${seasonDelta > 0 ? '+' : ''}$seasonDelta"),
                        style: TextStyle(
                          fontSize: 12,
                          color: seasonDelta > 0 ? Colors.green : Colors.grey,
                          fontWeight: seasonDelta > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          Text(Tr.pick('市場価値: ${p.marketValue}万円', 'Value: ${p.marketValue}')),
          Builder(
            builder: (context) {
              final b = p.marketValueBreakdown;
              return Text(
                Tr.pick(
                    '内訳: 基礎${b.base.round()}万円 + 伸びしろ${b.potentialBonus.round()}万円 を年齢×${b.ageFactor.toStringAsFixed(2)} 性格×${b.personalityFactor.toStringAsFixed(2)} 統率力×${b.leadershipFactor.toStringAsFixed(2)}',
                    'Breakdown: base ${b.base.round()} + potential ${b.potentialBonus.round()}, times age ${b.ageFactor.toStringAsFixed(2)}, personality ${b.personalityFactor.toStringAsFixed(2)}, leadership ${b.leadershipFactor.toStringAsFixed(2)}'),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              );
            },
          ),
          Text(
            p.isLoan
                ? Tr.pick('週俸: ${p.wage}万円 / ローン残り${p.loanWeeksRemaining}週',
                    'Wage: ${p.wage} / ${p.loanWeeksRemaining} weeks left on loan')
                : Tr.pick(
                    '週俸: ${p.wage}万円 / ${ContractEngine.yearsLabel(p.contractYearsRemaining)}',
                    'Wage: ${p.wage} / ${ContractEngine.yearsLabel(p.contractYearsRemaining)}'),
          ),
          if (p.releaseClause != null)
            Text(
              Tr.pick('リリース条項: ${p.releaseClause}万円',
                  'Release clause: ${p.releaseClause}'),
              style: const TextStyle(color: Colors.deepPurple),
            ),
          const SizedBox(height: 4),
          Text(
            p.personality.description,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            p.wantsTransfer
                ? Tr.pick(
                    '不満度${p.happiness}が移籍希望ライン(${p.personality.transferRequestThreshold}未満)を下回っており、移籍を希望している',
                    'Happiness ${p.happiness} has fallen below the transfer-request line (under ${p.personality.transferRequestThreshold}), so they want a move')
                : Tr.pick(
                    '移籍希望ライン: 不満度が${p.personality.transferRequestThreshold}未満になると移籍を希望する(現在${p.happiness})',
                    'Transfer-request line: they ask for a move below ${p.personality.transferRequestThreshold} happiness (currently ${p.happiness})'),
            style: TextStyle(
              fontSize: 11,
              color: p.wantsTransfer ? Colors.redAccent : Colors.grey,
            ),
          ),
          if (p.role != PlayerRole.standard) ...[
            const SizedBox(height: 4),
            Text(
              Tr.pick('ロール: ${p.role.label} — ${p.role.description}',
                  'Role: ${p.role.label} — ${p.role.description}'),
              style: const TextStyle(fontSize: 12, color: Colors.teal),
            ),
          ],
          if (p.trait != null) ...[
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                  '特性(${p.trait!.category.label}): ${p.trait!.label} — ${p.trait!.description}',
                  'Trait (${p.trait!.category.label}): ${p.trait!.label} — ${p.trait!.description}'),
              style: const TextStyle(fontSize: 12, color: Colors.deepOrange),
            ),
          ],
          if (p.growthType != PlayerGrowthType.balanced) ...[
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                  '成長タイプ: ${p.growthType.label} — ${p.growthType.description}',
                  'Growth: ${p.growthType.label} — ${p.growthType.description}'),
              style: const TextStyle(fontSize: 12, color: Colors.indigo),
            ),
          ],
          if (latestGrowth != null && latestGrowth.isBreakthrough) ...[
            const SizedBox(height: 4),
            Text(
              Tr.pick('★ 今週、才能開花が発生しました！', '★ A breakthrough came this week.'),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (p.overallHistory.length >= 2) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Tr.pick(
                          '成長推移(直近${p.overallHistory.length}節): 総合 ${p.overallHistory.first} → ${p.overallHistory.last}',
                          'Progress (last ${p.overallHistory.length} matchdays): overall ${p.overallHistory.first} → ${p.overallHistory.last}'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GrowthSparkline(history: p.overallHistory),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Center(child: AttributeRadar(player: p)),
          const SizedBox(height: 12),
          _MatchImpactSummary(
            player: p,
            isStarting: isStarting,
            assignedSlot: assignedSlot,
          ),
          const SizedBox(height: 16),
          Text(Tr.pick('選手を操作', 'Player actions'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          // スカッド・ステータス(出場機会の約束)。自クラブ所属の選手のみ
          // 設定でき、ベンチ時の不満の増え方と契約の要求週給に影響する。
          if (gameState.userTeam.players.any((tp) => tp.id == p.id)) ...[
            Text(
              Tr.pick('スカッド・ステータス(出場機会の約束)',
                  'Squad status (what you promise them)'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in SquadStatus.values)
                  ChoiceChip(
                    label: Text(s.label),
                    selected: p.squadStatus == s,
                    onSelected: (_) =>
                        context.read<GameState>().setSquadStatus(p.id, s),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              p.squadStatus.description,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
          ],
          if (p.isLoan)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Tr.pick('ローン加入中の選手は契約更新・放出の対象外です。ローン期間終了時に自動的にチームを離れます。',
                        'Players on loan here cannot be re-signed or released. They leave automatically when the loan ends.'),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  if (p.loanBuyOptionFee != null) ...[
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: gameState.save!.budget < p.loanBuyOptionFee!
                          ? null
                          : () => _exerciseBuyOption(context),
                      child: Text(Tr.pick(
                          '買取オプションを行使する（${p.loanBuyOptionFee}万円）',
                          'Trigger the buy option (${p.loanBuyOptionFee})')),
                    ),
                  ],
                ],
              ),
            )
          else if (p.isLoanedOut)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                Tr.pick('他クラブへローン放出中は契約更新・放出の対象外です。期間終了時に自動的に復帰します。',
                    'A player out on loan cannot be re-signed or released. They return automatically when the loan ends.'),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            )
          else ...[
            Text(
              Tr.pick('現在の出場手当: ${p.appearanceFee}万円/試合',
                  'Current appearance fee: ${p.appearanceFee} per match'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: gameState.save!.budget < totalRenewalCost
                  ? null
                  : () => _renew(context),
              child: Text(
                Tr.pick(
                    '契約更新する（基本$renewalCost万円 + サインボーナス$signingBonus万円 / +40週 / 新出場手当$newAppearanceFee万円）',
                    'Renew his contract (base $renewalCost + signing bonus $signingBonus / +40 weeks / new appearance fee $newAppearanceFee)'),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.handshake_outlined),
              onPressed: () => _negotiate(context, isNegotiatingThisPlayer),
              label: Text(
                isNegotiatingThisPlayer
                    ? Tr.pick('交渉を続ける（選手の対案: ${negotiation.counterWage}万円/週）',
                        'Keep negotiating (their counter: ${negotiation.counterWage} per week)')
                    : Tr.pick('週俸交渉で更新する', 'Re-sign after wage talks'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: (team.players.length <= minSquadSize ||
                      !gameState.isTransferWindowOpen)
                  ? null
                  : () => _confirmSell(context, netReleaseValue),
              child: Text(
                netReleaseValue >= 0
                    ? Tr.pick('放出する（$netReleaseValue万円 獲得）',
                        'Release him (you receive $netReleaseValue)')
                    : Tr.pick('放出する（違約金${-netReleaseValue}万円 支払い）',
                        'Release him (you pay ${-netReleaseValue} in compensation)'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.sell_outlined),
              onPressed: () {
                FeedbackService.tap();
                gameState.setTransferListed(playerId, !p.isTransferListed);
              },
              label: Text(p.isTransferListed
                  ? Tr.pick('移籍リストから外す', 'Take off the transfer list')
                  : Tr.pick('移籍リストに登録する', 'Put on the transfer list')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.flight_takeoff),
              onPressed: (team.players.length <= minSquadSize ||
                      !gameState.isTransferWindowOpen)
                  ? null
                  : () => _showLoanOutDialog(context),
              label: Text(Tr.pick('他クラブへローン放出する', 'Loan him out')),
            ),
            if (!gameState.isTransferWindowOpen) ...[
              const SizedBox(height: 4),
              Text(
                gameState.transferWindowStatusLabel,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed:
                p.reassureCooldownWeeks > 0 ? null : () => _reassure(context),
            label: Text(
              p.reassureCooldownWeeks > 0
                  ? Tr.pick('話し合う（あと${p.reassureCooldownWeeks}週は待つ必要がある）',
                      'Have a word (you must wait another ${p.reassureCooldownWeeks} weeks)')
                  : Tr.pick('話し合う（不満度を和らげる）',
                      'Have a word (eases their unhappiness)'),
            ),
          ),
          if (!p.isLoan && !p.isLoanedOut) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.gavel),
              onPressed: () =>
                  _editReleaseClause(context, p.releaseClause, p.marketValue),
              label: Text(
                p.releaseClause == null
                    ? Tr.pick('リリース条項を設定する', 'Set a release clause')
                    : Tr.pick('リリース条項を変更する', 'Change the release clause'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.shield),
              onPressed: () {
                FeedbackService.tap();
                gameState.setCaptain(team.captainId == p.id ? null : p.id);
              },
              label: Text(team.captainId == p.id
                  ? Tr.pick('キャプテンを解任する', 'Strip the captaincy')
                  : Tr.pick('キャプテンに任命する', 'Make him captain')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.shield_outlined),
              onPressed: () {
                FeedbackService.tap();
                gameState.setViceCaptain(
                  team.viceCaptainId == p.id ? null : p.id,
                );
              },
              label: Text(
                team.viceCaptainId == p.id
                    ? Tr.pick('副キャプテンを解任する', 'Strip the vice captaincy')
                    : Tr.pick('副キャプテンに任命する', 'Make him vice captain'),
              ),
            ),
          ],
          const Divider(height: 32),
          StatBar(label: Tr.pick('攻撃', 'Attack'), value: p.attack),
          StatBar(label: Tr.pick('守備', 'Defence'), value: p.defense),
          StatBar(label: Tr.pick('技術', 'Technical'), value: p.technique),
          StatBar(label: Tr.pick('スタミナ', 'Stamina'), value: p.stamina),
          if (p.position == Position.gk)
            StatBar(
                label: Tr.pick('ゴールキーピング', 'Goalkeeping'),
                value: p.goalkeeping),
          const Divider(height: 32),
          StatBar(
              label: Tr.pick('潜在能力', 'Potential'),
              value: p.potential,
              color: Colors.purple),
          StatBar(
            label: Tr.pick('疲労', 'Fatigue'),
            value: p.fatigue,
            max: 100,
            color: Colors.redAccent,
          ),
          StatBar(
            label: Tr.pick('士気', 'Morale'),
            value: p.morale,
            max: 100,
            color: Colors.blueAccent,
          ),
          StatBar(
            label: Tr.pick('マッチシャープネス', 'Match Sharpness'),
            value: p.matchSharpness,
            max: 100,
            color: Colors.teal,
          ),
          StatBar(
            label: Tr.pick('不満度(高いほど満足)', 'Happiness (higher is happier)'),
            value: p.happiness,
            max: 100,
            color: p.happiness < 30
                ? SemanticColors.negative(context)
                : SemanticColors.positive(context),
          ),
          const Divider(height: 32),
          Text(Tr.pick('詳細能力値', 'Full attributes'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final category in categories)
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(Tr.pick(
                    '${category.label}（${category.keys.length}項目）',
                    '${category.label} (${category.keys.length})')),
                subtitle: Text(
                  Tr.pick(
                      '平均 ${(category.keys.fold<int>(0, (s, k) => s + p.attributeValue(k)) / category.keys.length).round()}',
                      'avg ${(category.keys.fold<int>(0, (s, k) => s + p.attributeValue(k)) / category.keys.length).round()}'),
                  style: const TextStyle(color: Colors.grey),
                ),
                initiallyExpanded: false,
                children: [
                  for (final key in category.keys)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: StatBar(
                        label: AttributeKeys.labelOf(key),
                        value: p.attributeValue(key),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _reassure(BuildContext context) async {
    final gameState = context.read<GameState>();
    final ok = await gameState.reassurePlayer(playerId);
    ok ? FeedbackService.success() : FeedbackService.tap();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ok
                ? Tr.pick('選手を安心させた', 'You put his mind at rest')
                : Tr.pick('既に満足しており、話し合う必要はなさそうだ',
                    'He is already content; there is nothing to talk about'))),
      );
    }
  }

  Future<void> _renew(BuildContext context) async {
    final gameState = context.read<GameState>();
    final ok = await gameState.renewContract(playerId);
    ok ? FeedbackService.success() : FeedbackService.error();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ok
                ? Tr.pick('契約を更新しました', 'Contract renewed')
                : Tr.pick('契約を更新できませんでした', 'Could not renew the contract'))),
      );
    }
  }

  Future<void> _negotiate(BuildContext context, bool isOngoing) async {
    final gameState = context.read<GameState>();
    if (!isOngoing) {
      gameState.startContractNegotiation(playerId);
    }
    if (!context.mounted) return;
    await _showNegotiationDialog(context);
  }

  Future<void> _showNegotiationDialog(BuildContext context) async {
    final gameState = context.read<GameState>();
    final negotiation = gameState.pendingContractNegotiation;
    if (negotiation == null) return;
    final controller = TextEditingController(
      text: negotiation.counterWage.toString(),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(Tr.pick('週俸交渉', 'Wage negotiation')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('現在の週俸: ${negotiation.initialWage}万円',
                'Current wage: ${negotiation.initialWage}')),
            Text(
              Tr.pick('選手の対案: ${negotiation.counterWage}万円/週',
                  'His counter-offer: ${negotiation.counterWage} per week'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              Tr.pick(
                  '交渉回数: ${negotiation.roundsUsed}/${ContractEngine.maxNegotiationRounds}',
                  'Rounds used: ${negotiation.roundsUsed}/${ContractEngine.maxNegotiationRounds}'),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: Tr.pick('提示する週俸（万円）', 'Wage you are offering')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              gameState.cancelContractNegotiation();
              Navigator.pop(dialogContext);
            },
            child: Text(Tr.pick('交渉をやめる', 'Walk away')),
          ),
          FilledButton(
            onPressed: () async {
              final wage = int.tryParse(controller.text);
              if (wage == null || wage <= 0) return;
              final result = await gameState.offerContractWage(wage);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) {
                _showNegotiationResultSnackBar(context, result);
              }
            },
            child: Text(Tr.pick('提示する', 'Offer')),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  void _showNegotiationResultSnackBar(
    BuildContext context,
    ContractOfferResult result,
  ) {
    switch (result) {
      case ContractOfferResult.accepted:
        FeedbackService.success();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(Tr.pick('週俸交渉が成立し、契約を更新しました',
                'You agreed terms and renewed the contract'))));
        break;
      case ContractOfferResult.countered:
        FeedbackService.tap();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(Tr.pick('選手から対案が届きました。もう一度交渉できます',
                  'He has come back with a counter-offer. You can negotiate again'))),
        );
        break;
      case ContractOfferResult.insufficientFunds:
        FeedbackService.error();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
            content: Text(Tr.pick('資金が不足しており契約を更新できませんでした',
                'Not enough funds to renew the contract'))));
        break;
      case ContractOfferResult.walkedAway:
        FeedbackService.error();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
            content: Text(Tr.pick('選手は交渉に納得できず、交渉から離脱しました',
                'He was not satisfied and walked away from the talks'))));
        break;
    }
  }

  Future<void> _exerciseBuyOption(BuildContext context) async {
    final gameState = context.read<GameState>();
    final ok = await gameState.exerciseLoanBuyOption(playerId);
    ok ? FeedbackService.success() : FeedbackService.error();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? Tr.pick('買取オプションを行使し、完全移籍が成立しました',
                  'You triggered the buy option and the permanent transfer went through')
              : Tr.pick(
                  '買取オプションを行使できませんでした', 'Could not trigger the buy option')),
        ),
      );
    }
  }

  void _editReleaseClause(BuildContext context, int? current, int marketValue) {
    final controller = TextEditingController(
      text: (current ?? marketValue).toString(),
    );
    final gameState = context.read<GameState>();
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final amount = int.tryParse(controller.text);
          final isValid = amount != null && amount > 0;
          return AlertDialog(
            title: Text(Tr.pick('リリース条項の設定', 'Set a release clause')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Tr.pick('市場価値: $marketValue万円', 'Value: $marketValue')),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: Tr.pick('解放金額(万円)', 'Clause amount'),
                    border: const OutlineInputBorder(),
                    errorText: isValid
                        ? null
                        : Tr.pick(
                            '1以上の金額を入力してください', 'Enter an amount of 1 or more'),
                  ),
                ),
              ],
            ),
            actions: [
              if (current != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    gameState.setReleaseClause(playerId, null);
                  },
                  child: Text(Tr.pick('解除する', 'Remove')),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(Tr.pick('キャンセル', 'Cancel')),
              ),
              FilledButton(
                onPressed: !isValid
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        gameState.setReleaseClause(playerId, amount);
                      },
                child: Text(Tr.pick('設定する', 'Set')),
              ),
            ],
          );
        },
      ),
    ).then((_) => controller.dispose());
  }

  void _showLoanOutDialog(BuildContext context) {
    final gameState = context.read<GameState>();
    int weeks = 8;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(Tr.pick('ローン放出期間', 'Loan length')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Tr.pick('$weeks週間、他クラブへ貸し出します。期間中の週俸は放出先が負担します。',
                  'He goes out on loan for $weeks weeks. The other club pays his wages while he is there.')),
              Slider(
                value: weeks.toDouble(),
                min: GameState.loanOutMinWeeks.toDouble(),
                max: GameState.loanOutMaxWeeks.toDouble(),
                divisions:
                    GameState.loanOutMaxWeeks - GameState.loanOutMinWeeks,
                label: Tr.pick('$weeks週', '$weeks weeks'),
                onChanged: (v) => setState(() => weeks = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(Tr.pick('キャンセル', 'Cancel')),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await gameState.loanOutPlayer(playerId, weeks);
                ok ? FeedbackService.success() : FeedbackService.error();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(ok
                            ? Tr.pick('ローン放出しました', 'Loan agreed')
                            : Tr.pick('ローン放出できませんでした',
                                'Could not arrange the loan'))),
                  );
                }
              },
              child: Text(Tr.pick('放出する', 'Release')),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSell(BuildContext context, int netReleaseValue) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Tr.pick('この選手を放出しますか？', 'Release this player?')),
        content: Text(
          netReleaseValue >= 0
              ? Tr.pick('$netReleaseValue万円を獲得しますが、元には戻せません。',
                  'You receive $netReleaseValue, and this cannot be undone.')
              : Tr.pick('違約金として${-netReleaseValue}万円を支払うことになりますが、元には戻せません。',
                  'You pay ${-netReleaseValue} in compensation, and this cannot be undone.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Tr.pick('キャンセル', 'Cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final gameState = context.read<GameState>();
              final messenger = ScaffoldMessenger.of(context);
              final ok = await gameState.sellPlayer(playerId);
              ok ? FeedbackService.success() : FeedbackService.error();
              if (ok) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(gameState.lastSaleNews ??
                        Tr.pick('選手を放出しました', 'Player released')),
                  ),
                );
              }
              if (context.mounted && ok) {
                Navigator.pop(context);
              }
            },
            child: Text(Tr.pick('放出する', 'Release')),
          ),
        ],
      ),
    );
  }
}

/// 選手の性格・ロール・デューティ・ポジション適性が、実際の試合でどれだけ
/// 攻撃力・守備力に影響するかを定量的にまとめたカード。
class _MatchImpactSummary extends StatelessWidget {
  final Player player;
  final bool isStarting;
  final Position assignedSlot;

  const _MatchImpactSummary({
    required this.player,
    required this.isStarting,
    required this.assignedSlot,
  });

  @override
  Widget build(BuildContext context) {
    String pct(double multiplier) {
      final delta = ((multiplier - 1) * 100).round();
      return delta >= 0 ? '+$delta%' : '$delta%';
    }

    final roleAttack = MatchEngine.roleMultiplier(player, forAttack: true);
    final roleDefense = MatchEngine.roleMultiplier(player, forAttack: false);
    final dutyAttack = MatchEngine.dutyAttackMultiplier(player.duty);
    final dutyDefense = MatchEngine.dutyDefenseMultiplier(player.duty);
    final positionFit = isStarting
        ? MatchEngine.positionFitMultiplier(player, assignedSlot)
        : null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Tr.pick('試合への影響(定量)', 'Effect on matches'),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            Tr.pick('ロール適性: 攻撃${pct(roleAttack)} / 守備${pct(roleDefense)}',
                'Role fit: attack ${pct(roleAttack)} / defence ${pct(roleDefense)}'),
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            Tr.pick(
                'デューティ(${player.duty.label}): 攻撃${pct(dutyAttack)} / 守備${pct(dutyDefense)}',
                'Duty (${player.duty.label}): attack ${pct(dutyAttack)} / defence ${pct(dutyDefense)}'),
            style: const TextStyle(fontSize: 12),
          ),
          if (positionFit != null && positionFit != 1.0)
            Text(
              Tr.pick('ポジション適性(${assignedSlot.label}で起用中): ${pct(positionFit)}',
                  'Position fit (playing at ${assignedSlot.label}): ${pct(positionFit)}'),
              style: TextStyle(
                fontSize: 12,
                color: SemanticColors.negative(context),
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
