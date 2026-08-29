import 'package:flutter/material.dart';
import '../data/glossary_entries.dart';
import '../widgets/quick_access_drawer.dart';

/// 選手能力値・複合指標・コンディション・契約・戦術など、アプリ内に登場する
/// 各種指標の意味をまとめた用語集画面。検索とカテゴリ絞り込みに対応する。
class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key, this.initialCategory});

  /// 指定した場合、その用語集カテゴリのみを表示した状態で開く。
  final GlossaryCategory? initialCategory;

  /// 検索・カテゴリ絞り込みを適用した用語一覧を返す。UIから切り離してテスト可能にしてある。
  static List<GlossaryEntry> filter(
    List<GlossaryEntry> all, {
    GlossaryCategory? category,
    String query = '',
  }) {
    var entries = all;
    if (category != null) {
      entries = entries.where((e) => e.category == category).toList();
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      entries = entries
          .where((e) =>
              e.term.toLowerCase().contains(q) ||
              e.description.toLowerCase().contains(q))
          .toList();
    }
    return entries;
  }

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  GlossaryCategory? _category;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = GlossaryScreen.filter(
      glossaryEntries,
      category: _category,
      query: _query,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('用語集'),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: '用語で検索',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: '検索をクリア',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: const Text('すべて'),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                ),
                for (final c in GlossaryCategory.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(c.label),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('該当する用語が見つかりません'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final e = filtered[i];
                      return ListTile(
                        title: Text(e.term,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(e.description),
                        ),
                        isThreeLine: e.description.length > 28,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
