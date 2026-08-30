import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/news_item.dart';
import '../state/game_state.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';

/// クラブニュース(お知らせ履歴)画面。SnackBarやダイアログで一度だけ
/// 流れて消える通知(移籍・賞金・実績・シーズン開始の出来事など)を、
/// 新しい順にいつでも見返せる。
class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final List<NewsItem> news = gameState.save?.newsLog ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('クラブニュース'),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: news.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'まだニュースはありません。\n'
                    '節を進めると、移籍・賞金・実績などのお知らせがここに記録されていきます。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: news.length,
                itemBuilder: (context, index) {
                  final item = news[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        _iconFor(item.context),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(item.text),
                      subtitle: Text(
                        'シーズン${item.season}・${item.context}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  IconData _iconFor(String context) {
    if (context.contains('移籍')) return Icons.swap_horiz;
    if (context.contains('カップ')) return Icons.emoji_events;
    if (context.contains('実績')) return Icons.military_tech;
    if (context.contains('表彰')) return Icons.star;
    if (context.contains('シーズン開始')) return Icons.flag;
    return Icons.info_outline;
  }
}
