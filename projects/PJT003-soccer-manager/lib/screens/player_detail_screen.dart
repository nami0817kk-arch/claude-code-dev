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
            tooltip: '能力値の意味を見る',
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
                  '${p.position.fullLabel} ・ ${p.age}歳',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (p.secondaryPositions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '対応可能ポジション: ${p.secondaryPositions.map((s) => s.label).join(', ')}',
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
                  'ポジション慣れ度(習得中): ${familiarities.map((f) => '${f.pos.label} ${f.value}/100').join(' / ')}'
                  '${p.trainingConvertTargetPosition != null ? ' ★コンバート特訓中' : ''}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              );
            },
          ),
          if (seasonStats.appearances > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '今シーズン: ${seasonStats.appearances}試合 ${seasonStats.goals}得点'
                '${seasonStats.yellowCards > 0 ? ' 警告${seasonStats.yellowCards}' : ''}'
                '${seasonStats.redCards > 0 ? ' 退場${seasonStats.redCards}' : ''}'
                ' / 平均採点${seasonStats.averageRating!.toStringAsFixed(1)}',
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
                '通算成績: ${p.careerAppearances}試合 ${p.careerGoals}得点',
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
                  label: const Text('スタメン'),
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                ),
              if (team.captainId == p.id)
                const Chip(
                  label: Text('キャプテン'),
                  backgroundColor: Colors.amber,
                  labelStyle: TextStyle(color: Colors.white),
                ),
              if (team.viceCaptainId == p.id)
                const Chip(
                  label: Text('副キャプテン'),
                  backgroundColor: Colors.blueGrey,
                  labelStyle: TextStyle(color: Colors.white),
                ),
              // ダイナミクス: 影響力上位のチームリーダー。機嫌がロッカー
              // ルーム全体へ波及し、放出するとチームが動揺する。
              if (DynamicsEngine.isTeamLeader(team, p.id))
                const Chip(
                  label: Text('チームリーダー'),
                  backgroundColor: Colors.deepOrange,
                  labelStyle: TextStyle(color: Colors.white),
                ),
              if (p.isLoan)
                const Chip(
                  label: Text('ローン加入中'),
                  backgroundColor: Colors.indigo,
                  labelStyle: TextStyle(color: Colors.white),
                ),
              if (p.wantsTransfer)
                const Chip(
                  label: Text('移籍を希望している'),
                  backgroundColor: Colors.redAccent,
                  labelStyle: TextStyle(color: Colors.white),
                ),
              Chip(label: Text(p.personality.label)),
              if (p.isOnInternationalDuty)
                const Chip(
                  label: Text('代表召集中'),
                  backgroundColor: Colors.blueAccent,
                  labelStyle: TextStyle(color: Colors.white),
                ),
              if (p.isLoanedOut)
                Chip(
                  label: Text('${p.loanedOutToClubName}へローン中'),
                  backgroundColor: Colors.deepPurple,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              if (p.isTransferListed)
                const Chip(
                  label: Text('移籍リスト登録中'),
                  backgroundColor: Colors.orange,
                  labelStyle: TextStyle(color: Colors.white),
                ),
            ],
          ),
          if (p.isInjured)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                p.injuryType == null
                    ? '負傷中（あと${p.injuryWeeks}週は出場不可）'
                    : '${p.injuryType!.label}で負傷中（あと${p.injuryWeeks}週は出場不可）',
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
                '負傷歴: ${p.injuryHistoryCounts.entries.map((e) {
                  final type = InjuryType.values.firstWhere(
                      (t) => t.name == e.key,
                      orElse: () => InjuryType.bruise);
                  return '${type.label}${e.value}回';
                }).join('・')}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          if (p.isSuspended)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '出場停止中（あと${p.suspendedMatches}試合は出場不可）',
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
                '警告累積: ${p.yellowCards}/$yellowCardSuspensionThreshold'
                '(あと${yellowCardSuspensionThreshold - p.yellowCards}枚で出場停止)',
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
                '代表召集中（あと${p.internationalDutyWeeksRemaining}週は出場不可）',
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
                '総合力: ${p.overall}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (latestGrowth != null && latestGrowth.overallDelta != 0) ...[
                const SizedBox(width: 8),
                Text(
                  '(今週${latestGrowth.overallDelta > 0 ? '+' : ''}${latestGrowth.overallDelta})',
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
                      '潜在能力到達度: ${potentialProgress.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.purple,
                      ),
                    ),
                    if (seasonDelta != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        '今シーズンの成長: ${seasonDelta > 0 ? '+' : ''}$seasonDelta',
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
          Text('市場価値: ${p.marketValue}万円'),
          Builder(
            builder: (context) {
              final b = p.marketValueBreakdown;
              return Text(
                '内訳: 基礎${b.base.round()}万円 + 伸びしろ${b.potentialBonus.round()}万円 を'
                '年齢×${b.ageFactor.toStringAsFixed(2)} 性格×${b.personalityFactor.toStringAsFixed(2)} '
                '統率力×${b.leadershipFactor.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              );
            },
          ),
          Text(
            p.isLoan
                ? '週俸: ${p.wage}万円 / ローン残り${p.loanWeeksRemaining}週'
                : '週俸: ${p.wage}万円 / ${ContractEngine.yearsLabel(p.contractYearsRemaining)}',
          ),
          if (p.releaseClause != null)
            Text(
              'リリース条項: ${p.releaseClause}万円',
              style: const TextStyle(color: Colors.deepPurple),
            ),
          const SizedBox(height: 4),
          Text(
            p.personality.description,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            p.wantsTransfer
                ? '不満度${p.happiness}が移籍希望ライン(${p.personality.transferRequestThreshold}未満)を下回っており、移籍を希望している'
                : '移籍希望ライン: 不満度が${p.personality.transferRequestThreshold}未満になると移籍を希望する(現在${p.happiness})',
            style: TextStyle(
              fontSize: 11,
              color: p.wantsTransfer ? Colors.redAccent : Colors.grey,
            ),
          ),
          if (p.role != PlayerRole.standard) ...[
            const SizedBox(height: 4),
            Text(
              'ロール: ${p.role.label} — ${p.role.description}',
              style: const TextStyle(fontSize: 12, color: Colors.teal),
            ),
          ],
          if (p.trait != null) ...[
            const SizedBox(height: 4),
            Text(
              '特性(${p.trait!.category.label}): ${p.trait!.label} — '
              '${p.trait!.description}',
              style: const TextStyle(fontSize: 12, color: Colors.deepOrange),
            ),
          ],
          if (p.growthType != PlayerGrowthType.balanced) ...[
            const SizedBox(height: 4),
            Text(
              '成長タイプ: ${p.growthType.label} — ${p.growthType.description}',
              style: const TextStyle(fontSize: 12, color: Colors.indigo),
            ),
          ],
          if (latestGrowth != null && latestGrowth.isBreakthrough) ...[
            const SizedBox(height: 4),
            const Text(
              '★ 今週、才能開花が発生しました！',
              style: TextStyle(
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
                      '成長推移(直近${p.overallHistory.length}節): '
                      '総合 ${p.overallHistory.first} → ${p.overallHistory.last}',
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
          Text('選手を操作', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          // スカッド・ステータス(出場機会の約束)。自クラブ所属の選手のみ
          // 設定でき、ベンチ時の不満の増え方と契約の要求週給に影響する。
          if (gameState.userTeam.players.any((tp) => tp.id == p.id)) ...[
            Text(
              'スカッド・ステータス(出場機会の約束)',
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
                  const Text(
                    'ローン加入中の選手は契約更新・放出の対象外です。ローン期間終了時に自動的にチームを離れます。',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  if (p.loanBuyOptionFee != null) ...[
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: gameState.save!.budget < p.loanBuyOptionFee!
                          ? null
                          : () => _exerciseBuyOption(context),
                      child: Text('買取オプションを行使する（${p.loanBuyOptionFee}万円）'),
                    ),
                  ],
                ],
              ),
            )
          else if (p.isLoanedOut)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '他クラブへローン放出中は契約更新・放出の対象外です。期間終了時に自動的に復帰します。',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            )
          else ...[
            Text(
              '現在の出場手当: ${p.appearanceFee}万円/試合',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: gameState.save!.budget < totalRenewalCost
                  ? null
                  : () => _renew(context),
              child: Text(
                '契約更新する（基本$renewalCost万円 + サインボーナス$signingBonus万円 / +40週 / '
                '新出場手当$newAppearanceFee万円）',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.handshake_outlined),
              onPressed: () => _negotiate(context, isNegotiatingThisPlayer),
              label: Text(
                isNegotiatingThisPlayer
                    ? '交渉を続ける（選手の対案: ${negotiation.counterWage}万円/週）'
                    : '週俸交渉で更新する',
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
                    ? '放出する（$netReleaseValue万円 獲得）'
                    : '放出する（違約金${-netReleaseValue}万円 支払い）',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.sell_outlined),
              onPressed: () {
                FeedbackService.tap();
                gameState.setTransferListed(playerId, !p.isTransferListed);
              },
              label: Text(p.isTransferListed ? '移籍リストから外す' : '移籍リストに登録する'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.flight_takeoff),
              onPressed: (team.players.length <= minSquadSize ||
                      !gameState.isTransferWindowOpen)
                  ? null
                  : () => _showLoanOutDialog(context),
              label: const Text('他クラブへローン放出する'),
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
                  ? '話し合う（あと${p.reassureCooldownWeeks}週は待つ必要がある）'
                  : '話し合う（不満度を和らげる）',
            ),
          ),
          if (!p.isLoan && !p.isLoanedOut) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.gavel),
              onPressed: () =>
                  _editReleaseClause(context, p.releaseClause, p.marketValue),
              label: Text(
                p.releaseClause == null ? 'リリース条項を設定する' : 'リリース条項を変更する',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.shield),
              onPressed: () {
                FeedbackService.tap();
                gameState.setCaptain(team.captainId == p.id ? null : p.id);
              },
              label: Text(team.captainId == p.id ? 'キャプテンを解任する' : 'キャプテンに任命する'),
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
                team.viceCaptainId == p.id ? '副キャプテンを解任する' : '副キャプテンに任命する',
              ),
            ),
          ],
          const Divider(height: 32),
          StatBar(label: '攻撃', value: p.attack),
          StatBar(label: '守備', value: p.defense),
          StatBar(label: '技術', value: p.technique),
          StatBar(label: 'スタミナ', value: p.stamina),
          if (p.position == Position.gk)
            StatBar(label: 'ゴールキーピング', value: p.goalkeeping),
          const Divider(height: 32),
          StatBar(label: '潜在能力', value: p.potential, color: Colors.purple),
          StatBar(
            label: '疲労',
            value: p.fatigue,
            max: 100,
            color: Colors.redAccent,
          ),
          StatBar(
            label: '士気',
            value: p.morale,
            max: 100,
            color: Colors.blueAccent,
          ),
          StatBar(
            label: 'マッチシャープネス',
            value: p.matchSharpness,
            max: 100,
            color: Colors.teal,
          ),
          StatBar(
            label: '不満度(高いほど満足)',
            value: p.happiness,
            max: 100,
            color: p.happiness < 30
                ? SemanticColors.negative(context)
                : SemanticColors.positive(context),
          ),
          const Divider(height: 32),
          Text('詳細能力値', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final category in categories)
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text('${category.label}（${category.keys.length}項目）'),
                subtitle: Text(
                  '平均 ${(category.keys.fold<int>(0, (s, k) => s + p.attributeValue(k)) / category.keys.length).round()}',
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
        SnackBar(content: Text(ok ? '選手を安心させた' : '既に満足しており、話し合う必要はなさそうだ')),
      );
    }
  }

  Future<void> _renew(BuildContext context) async {
    final gameState = context.read<GameState>();
    final ok = await gameState.renewContract(playerId);
    ok ? FeedbackService.success() : FeedbackService.error();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '契約を更新しました' : '契約を更新できませんでした')),
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
        title: const Text('週俸交渉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('現在の週俸: ${negotiation.initialWage}万円'),
            Text(
              '選手の対案: ${negotiation.counterWage}万円/週',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '交渉回数: ${negotiation.roundsUsed}/${ContractEngine.maxNegotiationRounds}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '提示する週俸（万円）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              gameState.cancelContractNegotiation();
              Navigator.pop(dialogContext);
            },
            child: const Text('交渉をやめる'),
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
            child: const Text('提示する'),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('週俸交渉が成立し、契約を更新しました')));
        break;
      case ContractOfferResult.countered:
        FeedbackService.tap();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('選手から対案が届きました。もう一度交渉できます')),
        );
        break;
      case ContractOfferResult.insufficientFunds:
        FeedbackService.error();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('資金が不足しており契約を更新できませんでした')));
        break;
      case ContractOfferResult.walkedAway:
        FeedbackService.error();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('選手は交渉に納得できず、交渉から離脱しました')));
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
          content: Text(ok ? '買取オプションを行使し、完全移籍が成立しました' : '買取オプションを行使できませんでした'),
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
            title: const Text('リリース条項の設定'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('市場価値: $marketValue万円'),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: '解放金額(万円)',
                    border: const OutlineInputBorder(),
                    errorText: isValid ? null : '1以上の金額を入力してください',
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
                  child: const Text('解除する'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: !isValid
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        gameState.setReleaseClause(playerId, amount);
                      },
                child: const Text('設定する'),
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
          title: const Text('ローン放出期間'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$weeks週間、他クラブへ貸し出します。期間中の週俸は放出先が負担します。'),
              Slider(
                value: weeks.toDouble(),
                min: GameState.loanOutMinWeeks.toDouble(),
                max: GameState.loanOutMaxWeeks.toDouble(),
                divisions:
                    GameState.loanOutMaxWeeks - GameState.loanOutMinWeeks,
                label: '$weeks週',
                onChanged: (v) => setState(() => weeks = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await gameState.loanOutPlayer(playerId, weeks);
                ok ? FeedbackService.success() : FeedbackService.error();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'ローン放出しました' : 'ローン放出できませんでした')),
                  );
                }
              },
              child: const Text('放出する'),
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
        title: const Text('この選手を放出しますか？'),
        content: Text(
          netReleaseValue >= 0
              ? '$netReleaseValue万円を獲得しますが、元には戻せません。'
              : '違約金として${-netReleaseValue}万円を支払うことになりますが、元には戻せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
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
                    content: Text(gameState.lastSaleNews ?? '選手を放出しました'),
                  ),
                );
              }
              if (context.mounted && ok) {
                Navigator.pop(context);
              }
            },
            child: const Text('放出する'),
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
            '試合への影響(定量)',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'ロール適性: 攻撃${pct(roleAttack)} / 守備${pct(roleDefense)}',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            'デューティ(${player.duty.label}): 攻撃${pct(dutyAttack)} / 守備${pct(dutyDefense)}',
            style: const TextStyle(fontSize: 12),
          ),
          if (positionFit != null && positionFit != 1.0)
            Text(
              'ポジション適性(${assignedSlot.label}で起用中): ${pct(positionFit)}',
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
