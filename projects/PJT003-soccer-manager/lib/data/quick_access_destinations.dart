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
import '../screens/player_search_screen.dart';
import '../screens/season_history_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/training_screen.dart';
import '../screens/transfer_screen.dart';
import '../screens/youth_screen.dart';
import '../l10n/tr.dart';

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

// 同上。final だと最初のアクセス時の言語でラベルが固定される。
List<QuickAccessDestination> get quickAccessDestinations => [
      QuickAccessDestination(
        icon: Icons.fitness_center,
        label: Tr.pick('トレーニング', 'Training'),
        color: Colors.deepOrange.shade400,
        builder: (_) => const TrainingScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.swap_horiz,
        label: Tr.pick('移籍市場', 'Transfers'),
        color: Colors.indigo.shade400,
        builder: (_) => const TransferScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.emoji_people,
        label: Tr.pick('ユース・スカウト', 'Youth & scouting'),
        color: Colors.teal.shade400,
        builder: (_) => const YouthScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.account_balance,
        label: Tr.pick('クラブ経営', 'Club finances'),
        color: Colors.brown.shade400,
        builder: (_) => const FinanceScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.person_search,
        label: Tr.pick('選手検索', 'Player search'),
        color: Colors.pink.shade400,
        builder: (_) => const PlayerSearchScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.newspaper,
        label: Tr.pick('クラブニュース', 'Club news'),
        color: Colors.deepPurple.shade400,
        builder: (_) => const NewsScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.apartment,
        label: Tr.pick('施設・スタッフ', 'Facilities & staff'),
        color: Colors.blueGrey.shade400,
        builder: (_) => const ClubScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.emoji_events,
        label: Tr.pick('カップ戦', 'Cups'),
        color: Colors.purple.shade400,
        builder: (_) => const CupScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.military_tech,
        label: Tr.pick('個人タイトル', 'Individual awards'),
        color: Colors.amber.shade700,
        builder: (_) => const AwardsScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.format_list_numbered,
        label: Tr.pick('リーグランキング', 'League rankings'),
        color: Colors.green.shade700,
        builder: (_) => const LeagueRankingScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.workspace_premium,
        label: Tr.pick('監督キャリア', 'Managerial career'),
        color: Colors.indigo.shade700,
        builder: (_) => const ManagerCareerScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.settings,
        label: Tr.pick('設定', 'Settings'),
        color: Colors.blueGrey.shade700,
        builder: (_) => const SettingsScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.history,
        label: Tr.pick('シーズン成績', 'Season archive'),
        color: Colors.teal.shade700,
        builder: (_) => const SeasonHistoryScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.groups,
        label: Tr.pick('ベストイレブン', 'Team of the season'),
        color: Colors.orange.shade700,
        builder: (_) => const BestElevenScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.emoji_events,
        label: Tr.pick('殿堂', 'Hall of fame'),
        color: Colors.brown.shade700,
        builder: (_) => const HallOfFameScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.menu_book,
        label: Tr.pick('用語集', 'Glossary'),
        color: Colors.cyan.shade700,
        builder: (_) => const GlossaryScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.help_outline,
        label: Tr.pick('ガイド', 'Guide'),
        color: Colors.lightGreen.shade700,
        builder: (_) => const GuideScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.emoji_events,
        label: Tr.pick('実績', 'Achievements'),
        color: Colors.amber.shade700,
        builder: (_) => const AchievementsScreen(),
      ),
      QuickAccessDestination(
        icon: Icons.calendar_month,
        label: Tr.pick('カレンダー', 'Calendar'),
        color: Colors.lightBlue.shade700,
        builder: (_) => const CalendarScreen(),
      ),
    ];
