import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/calendar_engine.dart';
import '../state/game_state.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';

/// シーズンの実日付をもとに、試合日・重点練習日を月表示で見渡せる
/// カレンダー画面。「今日は試合か練習か」を一目で把握できるようにする。
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final today = context.read<GameState>().currentDate;
    _visibleMonth = DateTime(today.year, today.month);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final league = gameState.save!.league;
    final today = gameState.currentDate;

    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final lastOfMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0);
    final gridStart =
        firstOfMonth.subtract(Duration(days: firstOfMonth.weekday - 1));
    final gridEnd = lastOfMonth.add(Duration(days: 7 - lastOfMonth.weekday));

    final days = CalendarEngine.buildRange(
      from: gridStart,
      to: gridEnd,
      league: league,
      userTeamId: gameState.userTeam.id,
      trainingDayOfWeek: gameState.userTeam.trainingDayOfWeek,
      today: today,
      domesticCup: gameState.domesticCup,
      continentalCup: gameState.continentalCup,
      continentalTeams: gameState.save!.continentalTeams,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('年間カレンダー'),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() {
                      _visibleMonth =
                          DateTime(_visibleMonth.year, _visibleMonth.month - 1);
                    }),
                  ),
                  Text('${_visibleMonth.year}年${_visibleMonth.month}月',
                      style: Theme.of(context).textTheme.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() {
                      _visibleMonth =
                          DateTime(_visibleMonth.year, _visibleMonth.month + 1);
                    }),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  for (final label in const ['月', '火', '水', '木', '金', '土', '日'])
                    Expanded(
                      child: Center(
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: label == '土'
                                    ? Colors.blue.shade700
                                    : label == '日'
                                        ? Colors.red.shade700
                                        : Colors.grey.shade700)),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.78,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: days.length,
                  itemBuilder: (context, i) {
                    final day = days[i];
                    final inMonth = day.date.month == _visibleMonth.month;
                    return _CalendarDayCell(
                      day: day,
                      dimmed: !inMonth,
                      onTap: () => _showDayDetail(context, day),
                    );
                  },
                ),
              ),
            ),
            const _CalendarLegend(),
          ],
        ),
      ),
    );
  }

  void _showDayDetail(BuildContext context, CalendarDayInfo day) {
    final dateLabel =
        '${day.date.month}/${day.date.day}(${CalendarEngine.weekdayLabel(day.date.weekday)})';
    final messages = <String>[];
    if (day.isLeagueMatchDay) {
      messages.add('第${day.matchday}節 ${day.isHomeMatch ? '(H)' : '(A)'} '
          'vs ${day.opponentName ?? '未定'}');
    } else if (day.isTrainingFocusDay) {
      messages.add('重点トレーニング日');
    } else {
      messages.add('練習日(通常メニュー)');
    }
    messages.addAll(day.cupLabels);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$dateLabel: ${messages.join(' / ')}')),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  final CalendarDayInfo day;
  final bool dimmed;
  final VoidCallback onTap;

  const _CalendarDayCell({
    required this.day,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color? background;
    Widget? marker;
    if (day.isLeagueMatchDay) {
      background = (day.isHomeMatch ? Colors.blue : Colors.grey)
          .withValues(alpha: dimmed ? 0.12 : 0.22);
      marker = Icon(Icons.sports_soccer,
          size: 14,
          color: (day.isHomeMatch ? Colors.blue.shade700 : Colors.grey.shade700)
              .withValues(alpha: dimmed ? 0.5 : 1));
    } else if (day.isTrainingFocusDay) {
      background = Colors.deepOrange.withValues(alpha: dimmed ? 0.08 : 0.14);
      marker = Icon(Icons.fitness_center,
          size: 14,
          color:
              Colors.deepOrange.shade400.withValues(alpha: dimmed ? 0.5 : 1));
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: day.isToday
              ? Border.all(color: scheme.primary, width: 2)
              : Border.all(color: Colors.transparent),
        ),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.date.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        day.isToday ? FontWeight.bold : FontWeight.normal,
                    color: dimmed ? Colors.grey.shade400 : null,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(height: 14, child: marker),
              ],
            ),
            if (day.isCupMatchDay)
              Positioned(
                top: 0,
                right: 0,
                child: Icon(Icons.emoji_events,
                    size: 12,
                    color: Colors.amber.shade700
                        .withValues(alpha: dimmed ? 0.5 : 1)),
              ),
          ],
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          item(Icons.sports_soccer, Colors.blue.shade700, 'ホーム'),
          item(Icons.sports_soccer, Colors.grey.shade700, 'アウェイ'),
          item(Icons.fitness_center, Colors.deepOrange.shade400, '重点練習日'),
          item(Icons.emoji_events, Colors.amber.shade700, 'カップ戦消化可能'),
        ],
      ),
    );
  }
}
