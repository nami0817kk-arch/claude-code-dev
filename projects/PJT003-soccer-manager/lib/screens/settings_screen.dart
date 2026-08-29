import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state/game_state.dart';
import '../state/settings_controller.dart';
import '../widgets/quick_access_drawer.dart';
import 'onboarding_screen.dart';
import 'start_screen.dart';

const String _privacyPolicyUrl =
    'https://nami0817kk-arch.github.io/kabu-agari-ranking/legal/privacy.html';
const String _termsUrl =
    'https://nami0817kk-arch.github.io/kabu-agari-ranking/legal/terms.html';

/// 表示・操作設定とセーブデータ管理をまとめた画面。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final gameState = context.watch<GameState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('表示', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _ThemeModeTile(
                  label: '端末の設定に合わせる',
                  mode: ThemeMode.system,
                  current: settings.themeMode,
                  onSelect: settings.setThemeMode,
                ),
                _ThemeModeTile(
                  label: 'ライトモード',
                  mode: ThemeMode.light,
                  current: settings.themeMode,
                  onSelect: settings.setThemeMode,
                ),
                _ThemeModeTile(
                  label: 'ダークモード',
                  mode: ThemeMode.dark,
                  current: settings.themeMode,
                  onSelect: settings.setThemeMode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('文字サイズ'),
                      Text('${(settings.textScale * 100).round()}%'),
                    ],
                  ),
                  Slider(
                    value: settings.textScale,
                    min: SettingsController.minTextScale,
                    max: SettingsController.maxTextScale,
                    divisions: 9,
                    onChanged: (v) => settings.setTextScale(v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('アクセシビリティ', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('色覚サポートモード'),
                  subtitle: const Text('勝敗などの色分けを、赤緑ではなく青とオレンジで表示します'),
                  value: settings.colorblindMode,
                  onChanged: (v) => settings.setColorblindMode(v),
                ),
                SwitchListTile(
                  title: const Text('太字強調モード'),
                  subtitle: const Text('文字を全体的に太くして見やすくします'),
                  value: settings.boldTextMode,
                  onChanged: (v) => settings.setBoldTextMode(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('サウンド・触覚', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('効果音'),
                  subtitle: const Text('得点・試合結果などで再生します'),
                  value: settings.soundEnabled,
                  onChanged: (v) => settings.setSoundEnabled(v),
                ),
                SwitchListTile(
                  title: const Text('触覚フィードバック'),
                  subtitle: const Text('ボタン操作や試合の展開に合わせて振動します'),
                  value: settings.hapticsEnabled,
                  onChanged: (v) => settings.setHapticsEnabled(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('ヘルプ', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('チュートリアルをもう一度見る'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OnboardingScreen(
                      onDone: () => Navigator.of(context).pop()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('セーブデータ', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.copy_all_outlined),
                  title: const Text('セーブデータをコピー(バックアップ)'),
                  subtitle: const Text('クリップボードにJSON形式で書き出します'),
                  onTap: () => _exportSave(context),
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('セーブデータを復元'),
                  subtitle: const Text('コピーしたJSONを貼り付けて復元します'),
                  onTap: () => _importSave(context),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.delete_forever, color: Colors.redAccent),
                  title: const Text('セーブデータを削除',
                      style: TextStyle(color: Colors.redAccent)),
                  subtitle: const Text('最初からやり直します。この操作は取り消せません'),
                  onTap: () => _confirmDelete(context),
                ),
              ],
            ),
          ),
          if (gameState.save != null) ...[
            const SizedBox(height: 20),
            Text('デバッグ(管理者専用)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.build_circle_outlined),
                title: const Text('資金を追加'),
                subtitle: const Text('動作確認・検証用に、任意の額だけクラブ資金を増減させます'),
                onTap: () => _showAddFundsDialog(context),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('アプリ情報', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: const Icon(Icons.sports_soccer, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('サッカー経営マネージャー',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 2),
                        FutureBuilder<PackageInfo>(
                          future: PackageInfo.fromPlatform(),
                          builder: (context, snapshot) {
                            final info = snapshot.data;
                            final label = info == null
                                ? '読み込み中…'
                                : 'バージョン ${info.version}+${info.buildNumber}';
                            return Text(label,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey));
                          },
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'クラブ経営からスタメン編成、移籍市場、ユース育成までを1本で楽しめる'
                          'サッカーマネージメントゲームです。',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('プライバシーポリシー'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => _openLink(context, _privacyPolicyUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('利用規約'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => _openLink(context, _termsUrl),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('リンクを開けませんでした')),
      );
    }
  }

  Future<void> _exportSave(BuildContext context) async {
    final gameState = context.read<GameState>();
    final json = gameState.exportSaveJson();
    if (json == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('セーブデータがないためコピーできませんでした')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: json));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('セーブデータをクリップボードにコピーしました')),
      );
    }
  }

  void _importSave(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('セーブデータを復元'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
              hintText: 'コピーしたJSONを貼り付けてください', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () async {
              final gameState = ctx.read<GameState>();
              final ok = await gameState.importSaveJson(controller.text.trim());
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(ok ? '復元しました' : '復元に失敗しました(形式を確認してください)')),
                );
              }
            },
            child: const Text('復元する'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _showAddFundsDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('資金を追加'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: const InputDecoration(
            labelText: '増減額(万円)',
            hintText: '例: 100000(マイナスで減額)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              final amount = int.tryParse(controller.text.trim());
              Navigator.pop(ctx);
              if (amount == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('数値を入力してください')),
                );
                return;
              }
              context.read<GameState>().addDebugFunds(amount);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('資金を${amount >= 0 ? '+' : ''}$amount万円しました')),
              );
            },
            child: const Text('反映する'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('セーブデータを削除しますか？'),
        content: const Text('この操作は取り消せません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          TextButton(
            onPressed: () async {
              final gameState = ctx.read<GameState>();
              await gameState.deleteSave();
              if (ctx.mounted) {
                Navigator.of(ctx).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const StartScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('削除する'),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  final String label;
  final ThemeMode mode;
  final ThemeMode current;
  final ValueChanged<ThemeMode> onSelect;

  const _ThemeModeTile({
    required this.label,
    required this.mode,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final selected = mode == current;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () => onSelect(mode),
    );
  }
}
