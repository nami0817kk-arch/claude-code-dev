import 'package:flutter/material.dart';

import '../screens/achievements_screen.dart';
import '../screens/awards_screen.dart';
import '../screens/best_eleven_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/club_screen.dart';
import '../screens/cup_screen.dart';
import '../screens/finance_screen.dart';
import '../screens/glossary_screen.dart';
import '../screens/guide_screen.dart';
import '../screens/hall_of_fame_screen.dart';
import '../screens/league_ranking_screen.dart';
import '../screens/manager_career_screen.dart';
import '../screens/news_screen.dart';
import '../screens/season_history_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/training_screen.dart';
import '../screens/transfer_screen.dart';
import '../screens/youth_screen.dart';

/// ホーム画面の「クラブ運営」タイルと、各メインタブのクイックアクセス
/// ドロワーの両方から参照する遷移先の一覧。1箇所で管理することで、
/// 新しい管理画面を追加したときにどちらか一方だけ更新し忘れる事故を防ぐ。
class QuickAccessDestination {
  final IconData icon;
  final String label;
  final Color color;
  final WidgetBuilder builder;

  const QuickAccessDestination({
    required this.icon,
    required this.label,
    required this.color,
    required this.builder,
  });
}

final List<QuickAccessDestination> quickAccessDestinations = [
  QuickAccessDestination(
    icon: Icons.fitness_center,
    label: 'トレーニング',
    color: Colors.deepOrange.shade400,
    builder: (_) => const TrainingScreen(),
  ),
  QuickAccessDestination(
    icon: Icons.swap_horiz,
    label: '移籍市場',
    color: Colors.indigo.shade400,
    builder: (_) => const TransferScreen(),
  ),
  QuickAccessDestination(
    icon: Icons.emoji_people,
    label: 'ユース・スカウト',
    color: Colors.teal.shade400,
    builder: (_) => const YouthScreen(),
  ),
  QuickAccessDestination(
    icon: Icons.account_balance,
    label: 'クラブ経営',
    color: Colors.brown.shade400,
    builder: (_) => const FinanceScreen(),
  ),
  QuickAccessDestination(
    icon: Icons.newspaper,
    label: 'クラブニュース',
    color: Colors.deepPurple.shade400,
    builder: (_) => const NewsScreen(),
  ),
  QuickAccessDestination(
    icon: Icons.apartment,
    label: '施設・スタッフ',
    color: Colors.blueGrey.shade400,
    builder: (_) => const ClubScreen(),
  ),
  QuickAccessDestination(
    icon: Icons.emoji_events,
    label: 'カップ戦',
    color: Colors.purple.shade400,
    builder: (_) => const CupScreen(),
  ),
  QuickAccessDestination(
    icon: Icons.military_tech,
    label: '個人タイトル',
    color: Colors.amber.shade700,
    builder: (_) => const AwardsScreen(),
  ),
  QuickAccessDestination(
    icon: Icons.format_list_numbered,
    label: 'リーグランキング',
    color: Colors.green.shade700,
    builder: (_) => const LeagueRankingScreen(),
  ),
  QuickAccessDestination(
    icon: Icons.workspace_premium,
    label: '監督キャリア',
    color: Colors.indigo.shade700,
    builder: (_) => const ManagerCareerScreen(),
  ),
  QuickAccessDestination(
    icon: Icons.settings,
    label: '設定',
    color: Colors.blueGrey.shade700,
    builder: (_) => const SettingsScreen(),
  ),
  QuickAccessDestination(
    icon: Icons.history,
    label: 'シーズン成績',
    color: Colors.teal.shade700,
    builder: (_) => const SeasonHistoryScreen(),
  ),
  QuickAccessDestination(
    icon: Icons.groups,
    label: 'ベストイレブン',
    color: Colors.orange.shade700,
    builder: (_) => const BestElevenScreen(),
  ),
  QuickAccessDestination(
    icon: Icons.emoji_events,
    label: '殿堂',
    color: Colors.brown.shade700,
    builder: (_) => const HallOfFameScreen(),
  ),
  QuickAccessDestination(
    icon: Icons.menu_book,
    label: '用語集',
    color: Colors.cyan.shade700,
    builder: (_) => const GlossaryScreen(),
  ),
  QuickAccessDestination(
    icon: Icons.help_outline,
    label: 'ガイド',
    color: Colors.lightGreen.shade700,
    builder: (_) => const GuideScreen(),
  ),
  QuickAccessDestination(
    icon: Icons.emoji_events,
    label: '実績',
    color: Colors.amber.shade700,
    builder: (_) => const AchievementsScreen(),
  ),
  QuickAccessDestination(
    icon: Icons.calendar_month,
    label: 'カレンダー',
    color: Colors.lightBlue.shade700,
    builder: (_) => const CalendarScreen(),
  ),
];
