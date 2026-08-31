import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/scouting_engine.dart';
import '../models/club_infrastructure.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import '../l10n/tr.dart';

/// スタッフ・施設の現在レベル(と最大未満なら次レベル)の具体的な効果を1行にまとめる。
String _staffEffectLabel(StaffRole role, int level) {
  const maxLevel = ClubInfrastructure.maxLevel;
  switch (role) {
    case StaffRole.headCoach:
      final cur = ClubInfrastructure.trainingGrowthMultiplier(level, 1);
      final next = level < maxLevel
          ? ClubInfrastructure.trainingGrowthMultiplier(level + 1, 1)
          : null;
      return Tr.pick(
          '成長倍率 ${cur.toStringAsFixed(2)}倍${next == null ? '' : ' → 次Lv: ${next.toStringAsFixed(2)}倍'}',
          "Growth x${cur.toStringAsFixed(2)}${next == null ? '' : ' → next level: x${next.toStringAsFixed(2)}'}");
    case StaffRole.scout:
      final cur = ScoutingEngine.scoutCostFor(level);
      final curCount = ScoutingEngine.scoutCandidateCountFor(level);
      final next =
          level < maxLevel ? ScoutingEngine.scoutCostFor(level + 1) : null;
      final nextCount = level < maxLevel
          ? ScoutingEngine.scoutCandidateCountFor(level + 1)
          : null;
      return Tr.pick(
          '費用$cur万円 / 候補$curCount人${next == null ? '' : ' → 次Lv: 費用$next万円 / 候補$nextCount人'}',
          "$cur per signing / $curCount candidates${next == null ? '' : ' → next level: $next / $nextCount candidates'}");
    case StaffRole.physio:
      final cur = ClubInfrastructure.injuryFactor(level);
      final next =
          level < maxLevel ? ClubInfrastructure.injuryFactor(level + 1) : null;
      return Tr.pick(
          '負傷リスク${((1 - cur) * 100).round()}%軽減${next == null ? '' : ' → 次Lv: ${((1 - next) * 100).round()}%軽減'}',
          "Injury risk down ${((1 - cur) * 100).round()}%${next == null ? '' : ' → next level: down ${((1 - next) * 100).round()}%'}");
    case StaffRole.youthCoach:
      final bonus = (level - 1) * 3;
      final next = level < maxLevel ? level * 3 : null;
      return Tr.pick('アカデミー生の質+$bonus${next == null ? '' : ' → 次Lv: +$next'}',
          "Academy quality +$bonus${next == null ? '' : ' → next level: +$next'}");
    case StaffRole.fitnessCoach:
      final cur = ClubInfrastructure.fitnessCoachRecoveryBonus(level);
      final next = level < maxLevel
          ? ClubInfrastructure.fitnessCoachRecoveryBonus(level + 1)
          : null;
      return Tr.pick('追加疲労回復+$cur${next == null ? '' : ' → 次Lv: +$next'}',
          "Extra fatigue recovery +$cur${next == null ? '' : ' → next level: +$next'}");
  }
}

String _facilityEffectLabel(
  FacilityType type,
  int level,
  int expectedAttendance,
) {
  const maxLevel = ClubInfrastructure.maxLevel;
  switch (type) {
    case FacilityType.trainingGround:
      final curGrowth = ClubInfrastructure.trainingGrowthMultiplier(1, level);
      final curFatigue = ClubInfrastructure.fatigueRecoveryBonus(level);
      final next = level < maxLevel
          ? ClubInfrastructure.trainingGrowthMultiplier(1, level + 1)
          : null;
      final nextFatigue = level < maxLevel
          ? ClubInfrastructure.fatigueRecoveryBonus(level + 1)
          : null;
      return Tr.pick(
          '成長倍率 ${curGrowth.toStringAsFixed(2)}倍 / 追加疲労回復+$curFatigue${next == null ? '' : ' → 次Lv: ${next.toStringAsFixed(2)}倍 / +$nextFatigue'}',
          "Growth x${curGrowth.toStringAsFixed(2)} / extra recovery +$curFatigue${next == null ? '' : ' → next level: x${next.toStringAsFixed(2)} / +$nextFatigue'}");
    case FacilityType.stadium:
      final cur = ClubInfrastructure.stadiumCapacity(level);
      final next = level < maxLevel
          ? ClubInfrastructure.stadiumCapacity(level + 1)
          : null;
      return Tr.pick(
          '収容人数 $cur人 (平均動員目安 $expectedAttendance人)${next == null ? '' : ' → 次Lv: $next人'}',
          "Capacity $cur (typical attendance $expectedAttendance)${next == null ? '' : ' → next level: $next'}");
    case FacilityType.youthFacility:
      final cur = ScoutingEngine.maxProspectsFor(level);
      final next =
          level < maxLevel ? ScoutingEngine.maxProspectsFor(level + 1) : null;
      return Tr.pick('受け入れ枠 $cur人${next == null ? '' : ' → 次Lv: $next人'}',
          "$cur academy places${next == null ? '' : ' → next level: $next'}");
    case FacilityType.commercialFacility:
      final cur = ClubInfrastructure.commercialRevenueMultiplier(level);
      final next = level < maxLevel
          ? ClubInfrastructure.commercialRevenueMultiplier(level + 1)
          : null;
      return Tr.pick(
          '観客・スポンサー収入 x${cur.toStringAsFixed(2)}${next == null ? '' : ' → 次Lv: x${next.toStringAsFixed(2)}'}',
          "Gate and sponsorship income x${cur.toStringAsFixed(2)}${next == null ? '' : ' → next level: x${next.toStringAsFixed(2)}'}");
    case FacilityType.medicalCenter:
      final cur = ClubInfrastructure.medicalCenterInjuryFactor(level);
      final next = level < maxLevel
          ? ClubInfrastructure.medicalCenterInjuryFactor(level + 1)
          : null;
      return Tr.pick(
          'フィジオと合わせて負傷リスク追加${((1 - cur) * 100).round()}%軽減${next == null ? '' : ' → 次Lv: 追加${((1 - next) * 100).round()}%軽減'}',
          "With your physio, injury risk down a further ${((1 - cur) * 100).round()}%${next == null ? '' : ' → next level: a further ${((1 - next) * 100).round()}%'}");
  }
}

class ClubScreen extends StatelessWidget {
  const ClubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    final infra = save.infrastructure;
    final totalLevels = [
      ...StaffRole.values.map(infra.staffLevel),
      ...FacilityType.values.map(infra.facilityLevel),
    ].fold<int>(0, (s, l) => s + l);
    final maxTotalLevels =
        (StaffRole.values.length + FacilityType.values.length) *
            ClubInfrastructure.maxLevel;

    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.pick('クラブ施設・スタッフ', 'Facilities & staff')),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Tr.pick('資金: ${save.budget}万円', 'Funds: ${save.budget}'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Tr.pick('スタッフ週俸合計: ${infra.totalStaffWeeklyWage}万円',
                          'Total staff wages: ${infra.totalStaffWeeklyWage}'),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: totalLevels / maxTotalLevels,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Tr.pick('充実度 $totalLevels/$maxTotalLevels',
                              'Development $totalLevels/$maxTotalLevels'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(Tr.pick('スタッフ', 'Staff'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final role in StaffRole.values)
              _UpgradeCard(
                title: role.label,
                description: role.description,
                level: infra.staffLevel(role),
                cost: gameState.staffUpgradeCostFor(role),
                costLabel: Tr.pick('雇用費', 'Hiring cost'),
                extraLabel: Tr.pick(
                    '週俸 ${ClubInfrastructure.staffWeeklyWage(infra.staffLevel(role))}万円 / ${_staffEffectLabel(role, infra.staffLevel(role))}',
                    'Wage ${ClubInfrastructure.staffWeeklyWage(infra.staffLevel(role))} / ${_staffEffectLabel(role, infra.staffLevel(role))}'),
                canAfford: save.budget >= gameState.staffUpgradeCostFor(role),
                onUpgrade: () => gameState.upgradeStaff(role),
              ),
            const Divider(height: 32),
            Text(Tr.pick('施設', 'Facilities'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final type in FacilityType.values)
              _UpgradeCard(
                title: type.label,
                description: type.description,
                level: infra.facilityLevel(type),
                cost: gameState.facilityUpgradeCostFor(type),
                costLabel: Tr.pick('建設費', 'Build cost'),
                extraLabel: _facilityEffectLabel(
                  type,
                  infra.facilityLevel(type),
                  gameState.expectedAttendance,
                ),
                canAfford:
                    save.budget >= gameState.facilityUpgradeCostFor(type),
                onUpgrade: () => gameState.upgradeFacility(type),
              ),
            const Divider(height: 32),
            Text(Tr.pick('チケット価格戦略', 'Ticket pricing'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _TicketPricingCard(
              current: save.ticketPricing,
              onSelect: (p) => gameState.setTicketPricing(p),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketPricingCard extends StatelessWidget {
  final TicketPricing current;
  final ValueChanged<TicketPricing> onSelect;

  const _TicketPricingCard({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Tr.pick(
                  '観客動員率と1人あたり収入はトレードオフです。値上げは収容人数に対する実入場者数を減らし、値下げは満員に近づけます。',
                  'Attendance and revenue per head pull against each other. Raise prices and fewer of your seats fill; lower them and you get closer to a full house.'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            SegmentedButton<TicketPricing>(
              segments: TicketPricing.values
                  .map((p) => ButtonSegment(value: p, label: Text(p.label)))
                  .toList(),
              selected: {current},
              onSelectionChanged: (s) => onSelect(s.first),
            ),
            const SizedBox(height: 8),
            Text(
              current.description,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  final String title;
  final String description;
  final int level;
  final int cost;
  final String costLabel;
  final String? extraLabel;
  final bool canAfford;
  final Future<bool> Function() onUpgrade;

  const _UpgradeCard({
    required this.title,
    required this.description,
    required this.level,
    required this.cost,
    required this.costLabel,
    this.extraLabel,
    required this.canAfford,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    const maxLevel = ClubInfrastructure.maxLevel;
    final isMax = level >= maxLevel;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Row(
                  children: List.generate(
                    maxLevel,
                    (i) => Icon(
                      i < level ? Icons.star : Icons.star_border,
                      size: 16,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (extraLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                extraLabel!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: isMax || !canAfford
                    ? null
                    : () async {
                        final ok = await onUpgrade();
                        ok
                            ? FeedbackService.success()
                            : FeedbackService.error();
                      },
                child: Text(isMax
                    ? Tr.pick('最大レベル', 'Fully upgraded')
                    : Tr.pick('$costLabel $cost万円でアップグレード',
                        'Upgrade for $cost ($costLabel)')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
