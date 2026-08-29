import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import 'fixtures_screen.dart';
import 'home_screen.dart';
import 'lineup_screen.dart';
import 'squad_screen.dart';

/// ホーム/スカッド/戦術/順位表をボトムナビゲーションのタブとして保持するシェル。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _tabs = [
    HomeScreen(),
    SquadScreen(),
    LineupScreen(),
    FixturesScreen(),
  ];

  int _pendingHomeActionCount(GameState gameState) {
    var count = 0;
    if (gameState.pendingPressConference != null) count++;
    if (gameState.pendingJobOfferTeam != null) count++;
    count += gameState.pendingYouthIntake.length;
    count += gameState.incomingOffers.length;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final homeBadgeCount = _pendingHomeActionCount(gameState);

    Widget homeIcon(bool selected) {
      final icon = Icon(selected ? Icons.home : Icons.home_outlined);
      if (homeBadgeCount == 0) return icon;
      return Badge(
        label: Text('$homeBadgeCount'),
        child: icon,
      );
    }

    return PopScope(
      // ボトムナビゲーションのタブ切り替えはルートを積まないため、ホーム以外の
      // タブを表示中に戻る操作をすると、そのままタイトル画面まで戻ってしまう。
      // ホーム以外のタブではまずホームタブへ戻し、ホームタブの状態で戻る操作を
      // した場合のみ実際にこの画面を閉じる(=タイトルへ戻る)。
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _index = 0);
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: _tabs),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            FeedbackService.tap();
            setState(() => _index = i);
          },
          destinations: [
            NavigationDestination(
                icon: homeIcon(false),
                selectedIcon: homeIcon(true),
                label: 'ホーム'),
            const NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups),
                label: 'スカッド'),
            const NavigationDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist),
                label: '戦術'),
            const NavigationDestination(
                icon: Icon(Icons.leaderboard_outlined),
                selectedIcon: Icon(Icons.leaderboard),
                label: '順位表'),
          ],
        ),
      ),
    );
  }
}
