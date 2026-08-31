import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/contract_engine.dart';
import '../logic/investment_engine.dart';
import '../logic/loan_engine.dart';
import '../models/player.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/reward_funds_card.dart';
import '../widgets/responsive_body.dart';
import 'player_detail_screen.dart';
import '../l10n/tr.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    final team = gameState.userTeam;
    final income = gameState.weeklyIncomeFor(team.id);
    final wageBill = gameState.weeklyWageBill;
    final loanRepayment = gameState.bankLoans.fold<int>(
      0,
      (s, l) => s + l.weeklyRepayment,
    );
    final net = income - wageBill - loanRepayment;

    final sortedByExpiry = team.players.where((p) => !p.isLoan).toList()
      ..sort(
        (a, b) => a.contractYearsRemaining.compareTo(b.contractYearsRemaining),
      );
    final loanPlayers = team.players.where((p) => p.isLoan).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.pick('クラブ経営', 'Club finances')),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 特典資金。広告も課金も使えない環境では自分で消える。
            const RewardFundsCard(),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Tr.pick('資金: ${save.budget}万円', 'Funds: ${save.budget}'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(Tr.pick('週間収入: +$income万円（観客動員・スポンサー・グッズ収入込み）',
                        'Weekly income: +$income (gate receipts, sponsorship and merchandise)')),
                    Text(Tr.pick('週間人件費: -$wageBill万円（スタッフ週俸込み）',
                        'Weekly wages: -$wageBill (including staff)')),
                    if (loanRepayment > 0)
                      Text(Tr.pick('週間融資返済: -$loanRepayment万円',
                          'Weekly loan repayment: -$loanRepayment')),
                    const SizedBox(height: 8),
                    _CashFlowBar(
                      income: income,
                      expenses: wageBill + loanRepayment,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      Tr.pick('週間収支: ${net >= 0 ? '+' : ''}$net万円',
                          "Weekly balance: ${net >= 0 ? '+' : ''}$net"),
                      style: TextStyle(
                        color: net >= 0
                            ? SemanticColors.positive(context)
                            : SemanticColors.negative(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 理事会が設定する週給予算。上限を超える新規獲得は
                    // ブロックされるため、残り枠を常に確認できるようにする。
                    Builder(builder: (context) {
                      final cap = gameState.wageBudgetCap;
                      final usage =
                          cap > 0 ? (wageBill / cap).clamp(0.0, 1.0) : 0.0;
                      final over = wageBill > cap;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Tr.pick(
                                '週給予算(理事会設定): $wageBill / $cap万円${over ? '(超過中: 新規獲得は不可)' : ''}',
                                "Wage budget set by the board: $wageBill / $cap${over ? ' (over budget: no new signings)' : ''}"),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: over
                                  ? SemanticColors.negative(context)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: usage,
                              minHeight: 6,
                              color: over
                                  ? SemanticColors.negative(context)
                                  : null,
                              backgroundColor: Colors.grey.shade300,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(Tr.pick('資金調達（銀行融資）', 'Raise money (bank loan)'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _LoanSection(gameState: gameState),
            const SizedBox(height: 16),
            Text(Tr.pick('資金運用（定期預金）', 'Invest (fixed deposit)'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _InvestmentSection(gameState: gameState),
            const SizedBox(height: 16),
            Text(Tr.pick('スポンサー契約', 'Sponsorship'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _SponsorSection(gameState: gameState),
            if (save.pendingInstallments.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(Tr.pick('分割払い残金', 'Instalments outstanding'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final inst in save.pendingInstallments)
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    onTap: inst.playerId == null
                        ? null
                        : () => _openPlayer(context, inst.playerId!),
                    title: Text(inst.description),
                    subtitle: Text(Tr.pick('残り${inst.weeksRemaining}週',
                        '${Tr.plural(inst.weeksRemaining, 'week')} left')),
                    trailing: Text(Tr.pick('-${inst.weeklyAmount}万円/週',
                        '-${inst.weeklyAmount} per week')),
                  ),
                ),
            ],
            if (loanPlayers.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(Tr.pick('ローン加入中の選手', 'Players on loan at your club'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final p in loanPlayers)
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    onTap: () => _openPlayer(context, p.id),
                    title: Text(p.name),
                    subtitle: Text(Tr.pick(
                        '${p.position.label} / 週俸 ${p.wage}万円',
                        '${p.position.label} / wage ${p.wage}')),
                    trailing: Text(Tr.pick('残り${p.loanWeeksRemaining}週',
                        '${Tr.plural(p.loanWeeksRemaining, 'week')} left')),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Text(
              Tr.pick('契約状況（残り年数が少ない順）', 'Contracts, shortest remaining first'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final p in sortedByExpiry)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  onTap: () => _openPlayer(context, p.id),
                  title: Text(p.name),
                  subtitle: Text(Tr.pick('${p.position.label} / 週俸 ${p.wage}万円',
                      '${p.position.label} / wage ${p.wage}')),
                  trailing: Text(
                    ContractEngine.yearsShortLabel(p.contractYearsRemaining),
                    style: TextStyle(
                      color: p.contractYearsRemaining <= 1
                          ? SemanticColors.negative(context)
                          : null,
                      fontWeight: p.contractYearsRemaining <= 1
                          ? FontWeight.bold
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openPlayer(BuildContext context, String playerId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerDetailScreen(playerId: playerId)),
    );
  }
}

/// 週間収入と支出(人件費+融資返済)の比率を視覚化する内訳バー。
class _CashFlowBar extends StatelessWidget {
  final int income;
  final int expenses;

  const _CashFlowBar({required this.income, required this.expenses});

  @override
  Widget build(BuildContext context) {
    final total = income + expenses;
    if (total <= 0) return const SizedBox.shrink();
    final incomeFlex = ((income / total) * 100).round().clamp(1, 99);

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            Expanded(
              flex: incomeFlex,
              child: Container(color: SemanticColors.positive(context)),
            ),
            Expanded(
              flex: 100 - incomeFlex,
              child: Container(color: SemanticColors.negative(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SponsorSection extends StatelessWidget {
  final GameState gameState;

  const _SponsorSection({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final deal = gameState.save!.sponsorDeal;
    final offers = gameState.pendingSponsorOffers;

    if (deal != null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.handshake),
          title: Text(deal.name),
          subtitle: Text(ContractEngine.yearsShortLabel(deal.yearsRemaining)),
          trailing: Text(
            Tr.pick(
                '+${deal.weeklyIncome}万円/週', '+${deal.weeklyIncome} per week'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    if (offers.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.hourglass_empty),
          title: Text(Tr.pick('現在スポンサーはついていません', 'You have no sponsor')),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              Tr.pick('週間収入が高いほど契約期間は短くなる。契約する候補を選んでください。',
                  'The more it pays weekly, the shorter the deal. Choose which offer to take.'),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ),
        for (int i = 0; i < offers.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: const Icon(Icons.handshake_outlined),
              title: Text(offers[i].name),
              subtitle: Text(
                Tr.pick(
                    '契約期間: ${ContractEngine.yearsShortLabel(offers[i].yearsRemaining)}',
                    'Length: ${ContractEngine.yearsShortLabel(offers[i].yearsRemaining)}'),
              ),
              trailing: FilledButton(
                onPressed: () => _choose(context, i),
                child: Text(Tr.pick('+${offers[i].weeklyIncome}万円/週',
                    '+${offers[i].weeklyIncome} per week')),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _choose(BuildContext context, int index) async {
    await gameState.chooseSponsor(index);
    FeedbackService.success();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(Tr.pick('スポンサー契約を結んだ', 'Sponsorship deal signed'))));
    }
  }
}

class _LoanSection extends StatelessWidget {
  final GameState gameState;

  const _LoanSection({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final loans = gameState.bankLoans;
    final maxAmount = gameState.maxLoanAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final loan in loans)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: const Icon(Icons.account_balance),
              title: Text(Tr.pick(
                  '借入元本 ${loan.principal}万円', 'Principal ${loan.principal}')),
              subtitle: Text(
                Tr.pick(
                    '残り${loan.weeksRemaining}週 / 返済総額残り${loan.totalRemaining}万円',
                    '${Tr.plural(loan.weeksRemaining, 'week')} left / ${loan.totalRemaining} still to repay'),
              ),
              trailing: Text(
                Tr.pick('-${loan.weeklyRepayment}万円/週',
                    '-${loan.weeklyRepayment} per week'),
                style: TextStyle(color: SemanticColors.negative(context)),
              ),
            ),
          ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: Text(Tr.pick(
                '借入可能額: $maxAmount万円', 'You can borrow up to $maxAmount')),
            subtitle: Text(Tr.pick('スタジアムの規模・監督としての評価が高いほど上限が上がる',
                'A bigger stadium and a better reputation raise the ceiling')),
            trailing: FilledButton(
              onPressed: maxAmount <= 0 ? null : () => _showLoanSheet(context),
              child: Text(Tr.pick('融資を申し込む', 'Apply for a loan')),
            ),
          ),
        ),
      ],
    );
  }

  void _showLoanSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _LoanRequestSheet(gameState: gameState),
    );
  }
}

class _LoanRequestSheet extends StatefulWidget {
  final GameState gameState;

  const _LoanRequestSheet({required this.gameState});

  @override
  State<_LoanRequestSheet> createState() => _LoanRequestSheetState();
}

class _LoanRequestSheetState extends State<_LoanRequestSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.gameState.maxLoanAmount.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxAmount = widget.gameState.maxLoanAmount;
    final amount = int.tryParse(_controller.text)?.clamp(0, maxAmount) ?? 0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('融資を申し込む', 'Apply for a loan'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              Tr.pick('借入可能額: $maxAmount万円', 'You can borrow up to $maxAmount'),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: Tr.pick('借入額(万円)', 'Amount to borrow'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            for (final term in LoanEngine.terms)
              ListTile(
                leading: Icon(
                  term.weeks <= 12 ? Icons.speed : Icons.hourglass_bottom,
                ),
                title: Text(
                  Tr.pick(
                      '${term.label}（${term.weeks}週・利率${term.interestRatePercent.toStringAsFixed(0)}%）',
                      '${term.label} (${Tr.plural(term.weeks, 'week')}, ${term.interestRatePercent.toStringAsFixed(0)}% interest)'),
                ),
                subtitle: Text(
                  amount <= 0
                      ? Tr.pick('借入額を入力してください', 'Enter an amount to borrow')
                      : Tr.pick(
                          '週${LoanEngine.weeklyRepaymentFor(amount, term)}万円 × ${term.weeks}週 = 返済総額${LoanEngine.totalRepaymentFor(amount, term)}万円',
                          '${LoanEngine.weeklyRepaymentFor(amount, term)} a week x ${Tr.plural(term.weeks, 'week')} = ${LoanEngine.totalRepaymentFor(amount, term)} repaid in total'),
                ),
                enabled: amount > 0,
                onTap:
                    amount <= 0 ? null : () => _confirm(context, amount, term),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, int amount, LoanTerm term) async {
    // シートを閉じる前にScaffoldMessengerを確保しておく。閉じた後のcontextで
    // 取得・mounted判定すると、閉じるアニメーションと非同期処理の完了が
    // 競合し、成否のフィードバックが表示されないことがあるため。
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final ok = await widget.gameState.takeLoan(amount, term);
    ok ? FeedbackService.success() : FeedbackService.error();
    messenger.showSnackBar(
      SnackBar(
          content: Text(ok
              ? Tr.pick('$amount万円を借り入れました', 'You borrowed $amount')
              : Tr.pick('融資を申し込めませんでした', 'The loan was not approved'))),
    );
  }
}

class _InvestmentSection extends StatelessWidget {
  final GameState gameState;

  const _InvestmentSection({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final deposits = gameState.fixedDeposits;
    final available = gameState.save!.budget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final deposit in deposits)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: const Icon(Icons.savings),
              title: Text(Tr.pick('預入元本 ${deposit.principal}万円',
                  'Principal ${deposit.principal}')),
              subtitle: Text(
                Tr.pick(
                    '残り${deposit.weeksRemaining}週 / 満期時+${deposit.interestEarned}万円',
                    '${Tr.plural(deposit.weeksRemaining, 'week')} left / +${deposit.interestEarned} at maturity'),
              ),
              trailing: Text(
                Tr.pick('満期${deposit.maturityValue}万円',
                    'Matures at ${deposit.maturityValue}'),
                style: TextStyle(color: SemanticColors.positive(context)),
              ),
            ),
          ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: Text(Tr.pick(
                '運用可能な資金: $available万円', 'Available to invest: $available')),
            subtitle: Text(Tr.pick('満期まで引き出せない代わりに、満期時にまとまった利息を受け取れる',
                'Locked away until it matures, and pays a lump of interest when it does')),
            trailing: FilledButton(
              onPressed:
                  available <= 0 ? null : () => _showDepositSheet(context),
              child: Text(Tr.pick('定期預金を組む', 'Open a deposit')),
            ),
          ),
        ),
      ],
    );
  }

  void _showDepositSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _DepositRequestSheet(gameState: gameState),
    );
  }
}

class _DepositRequestSheet extends StatefulWidget {
  final GameState gameState;

  const _DepositRequestSheet({required this.gameState});

  @override
  State<_DepositRequestSheet> createState() => _DepositRequestSheetState();
}

class _DepositRequestSheetState extends State<_DepositRequestSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.gameState.save!.budget.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxAmount = widget.gameState.save!.budget;
    final amount = int.tryParse(_controller.text)?.clamp(0, maxAmount) ?? 0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Tr.pick('定期預金を組む', 'Open a deposit'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              Tr.pick(
                  '運用可能な資金: $maxAmount万円', 'Available to invest: $maxAmount'),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: Tr.pick('預入額(万円)', 'Amount to deposit'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            for (final term in InvestmentEngine.terms)
              ListTile(
                leading: Icon(
                  term.weeks <= 12 ? Icons.speed : Icons.hourglass_bottom,
                ),
                title: Text(
                  Tr.pick(
                      '${term.label}（${term.weeks}週・利回り${term.interestRatePercent.toStringAsFixed(0)}%）',
                      '${term.label} (${Tr.plural(term.weeks, 'week')}, ${term.interestRatePercent.toStringAsFixed(0)}% return)'),
                ),
                subtitle: Text(
                  amount <= 0
                      ? Tr.pick('預入額を入力してください', 'Enter an amount to deposit')
                      : Tr.pick(
                          '満期時 ${InvestmentEngine.maturityValueFor(amount, term)}万円(利息+${InvestmentEngine.interestFor(amount, term)}万円)',
                          'Matures at ${InvestmentEngine.maturityValueFor(amount, term)} (interest +${InvestmentEngine.interestFor(amount, term)})'),
                ),
                enabled: amount > 0,
                onTap:
                    amount <= 0 ? null : () => _confirm(context, amount, term),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    int amount,
    DepositTerm term,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final ok = await widget.gameState.openFixedDeposit(amount, term);
    ok ? FeedbackService.success() : FeedbackService.error();
    messenger.showSnackBar(
      SnackBar(
          content: Text(ok
              ? Tr.pick('$amount万円を預け入れました', 'You deposited $amount')
              : Tr.pick('定期預金を組めませんでした', 'The deposit could not be opened'))),
    );
  }
}
