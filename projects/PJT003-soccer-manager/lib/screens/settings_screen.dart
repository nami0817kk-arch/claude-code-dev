import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/tr.dart';
import '../state/game_state.dart';
import '../state/settings_controller.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/supporter_section.dart';
import 'onboarding_screen.dart';
import 'start_screen.dart';

const String _privacyPolicyUrl =
    'https://nami0817kk-arch.github.io/claude-code-dev/soccer-manager/legal/privacy.html';
const String _termsUrl =
    'https://nami0817kk-arch.github.io/claude-code-dev/soccer-manager/legal/terms.html';

/// 表示・操作設定とセーブデータ管理をまとめた画面。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final gameState = context.watch<GameState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(Tr.pick('設定', 'Settings')),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            Tr.pick('言語', 'Language'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final option in AppLanguage.values)
                  ListTile(
                    title: Text(option.label),
                    trailing: option == settings.language
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () => settings.setLanguage(option),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            Tr.pick('表示', 'Display'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _ThemeModeTile(
                  label: Tr.pick('端末の設定に合わせる', 'Follow the device setting'),
                  mode: ThemeMode.system,
                  current: settings.themeMode,
                  onSelect: settings.setThemeMode,
                ),
                _ThemeModeTile(
                  label: Tr.pick('ライトモード', 'Light'),
                  mode: ThemeMode.light,
                  current: settings.themeMode,
                  onSelect: settings.setThemeMode,
                ),
                _ThemeModeTile(
                  label: Tr.pick('ダークモード', 'Dark'),
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
                      Text(Tr.pick('文字サイズ', 'Text size')),
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
          Text(Tr.pick('アクセシビリティ', 'Accessibility'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title:
                      Text(Tr.pick('色覚サポートモード', 'Colourblind-friendly mode')),
                  subtitle: Text(Tr.pick('勝敗などの色分けを、赤緑ではなく青とオレンジで表示します',
                      'Uses blue and orange instead of red and green for results and other colour coding')),
                  value: settings.colorblindMode,
                  onChanged: (v) => settings.setColorblindMode(v),
                ),
                SwitchListTile(
                  title: Text(Tr.pick('太字強調モード', 'Bold text')),
                  subtitle: Text(Tr.pick('文字を全体的に太くして見やすくします',
                      'Makes all text heavier so it is easier to read')),
                  value: settings.boldTextMode,
                  onChanged: (v) => settings.setBoldTextMode(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(Tr.pick('サウンド・触覚', 'Sound & haptics'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(Tr.pick('効果音', 'Sound effects')),
                  subtitle: Text(Tr.pick('得点・試合結果などで再生します',
                      'Plays on goals, results and similar moments')),
                  value: settings.soundEnabled,
                  onChanged: (v) => settings.setSoundEnabled(v),
                ),
                SwitchListTile(
                  title: Text(Tr.pick('触覚フィードバック', 'Haptic feedback')),
                  subtitle: Text(Tr.pick('ボタン操作や試合の展開に合わせて振動します',
                      'Vibrates on taps and during matches')),
                  value: settings.hapticsEnabled,
                  onChanged: (v) => settings.setHapticsEnabled(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(Tr.pick('ヘルプ', 'Help'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.school_outlined),
              title:
                  Text(Tr.pick('チュートリアルをもう一度見る', 'Watch the tutorial again')),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OnboardingScreen(
                    onDone: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(Tr.pick('セーブデータ', 'Saved game'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.copy_all_outlined),
                  title: Text(
                      Tr.pick('セーブデータをコピー(バックアップ)', 'Copy your save (backup)')),
                  subtitle: Text(Tr.pick('クリップボードにJSON形式で書き出します',
                      'Writes it to the clipboard as JSON')),
                  onTap: () => _exportSave(context),
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: Text(Tr.pick('セーブデータを復元', 'Restore a save')),
                  subtitle: Text(Tr.pick('コピーしたJSONを貼り付けて復元します',
                      'Paste the JSON you copied to restore it')),
                  onTap: () => _importSave(context),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    Tr.pick('セーブデータを削除', 'Delete your save'),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  subtitle: Text(Tr.pick('最初からやり直します。この操作は取り消せません',
                      'Starts again from scratch. This cannot be undone')),
                  onTap: () => _confirmDelete(context),
                ),
              ],
            ),
          ),
          if (gameState.save != null) ...[
            const SizedBox(height: 20),
            Text(Tr.pick('デバッグ(管理者専用)', 'Debug (developer only)'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.build_circle_outlined),
                title: Text(Tr.pick('資金を追加', 'Add funds')),
                subtitle: Text(Tr.pick('動作確認・検証用に、任意の額だけクラブ資金を増減させます',
                    "Raises or lowers the club's funds by any amount, for testing")),
                onTap: () => _showAddFundsDialog(context),
              ),
            ),
          ],
          const SupporterSection(),
          const SizedBox(height: 20),
          Text(Tr.pick('アプリ情報', 'About'),
              style: Theme.of(context).textTheme.titleMedium),
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
                        Text(
                          Tr.pick('サッカー経営マネージャー', 'Soccer Club Manager'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        FutureBuilder<PackageInfo>(
                          future: PackageInfo.fromPlatform(),
                          builder: (context, snapshot) {
                            final info = snapshot.data;
                            final label = info == null
                                ? Tr.pick('読み込み中…', 'Loading…')
                                : Tr.pick(
                                    'バージョン ${info.version}+${info.buildNumber}',
                                    'Version ${info.version}+${info.buildNumber}');
                            return Text(
                              label,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          Tr.pick(
                              'クラブ経営からスタメン編成、移籍市場、ユース育成までを1本で楽しめるサッカーマネージメントゲームです。',
                              'A football management game covering everything from running the club to picking your XI, working the transfer market and bringing through the academy.'),
                          style: const TextStyle(fontSize: 12),
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
                  title: Text(Tr.pick('プライバシーポリシー', 'Privacy policy')),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => _openLink(context, _privacyPolicyUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(Tr.pick('利用規約', 'Terms of use')),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(Tr.pick('リンクを開けませんでした', 'Could not open the link'))));
    }
  }

  Future<void> _exportSave(BuildContext context) async {
    final gameState = context.read<GameState>();
    final json = gameState.exportSaveJson();
    if (json == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(
          content: Text(
              Tr.pick('セーブデータがないためコピーできませんでした', 'There is no save to copy'))));
      return;
    }
    await Clipboard.setData(ClipboardData(text: json));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(
          content: Text(Tr.pick(
              'セーブデータをクリップボードにコピーしました', 'Save copied to the clipboard'))));
    }
  }

  void _importSave(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Tr.pick('セーブデータを復元', 'Restore a save')),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: InputDecoration(
            hintText:
                Tr.pick('コピーしたJSONを貼り付けてください', 'Paste the JSON you copied'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Tr.pick('キャンセル', 'Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final gameState = ctx.read<GameState>();
              final ok = await gameState.importSaveJson(controller.text.trim());
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? Tr.pick('復元しました', 'Restored')
                        : Tr.pick('復元に失敗しました(形式を確認してください)',
                            'Restore failed. Check the format')),
                  ),
                );
              }
            },
            child: Text(Tr.pick('復元する', 'Restore')),
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
        title: Text(Tr.pick('資金を追加', 'Add funds')),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: InputDecoration(
            labelText: Tr.pick('増減額(万円)', 'Amount to add or remove'),
            hintText: Tr.pick(
                '例: 100000(マイナスで減額)', 'e.g. 100000 (negative to remove)'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Tr.pick('キャンセル', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final amount = int.tryParse(controller.text.trim());
              Navigator.pop(ctx);
              if (amount == null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(Tr.pick('数値を入力してください', 'Enter a number'))));
                return;
              }
              context.read<GameState>().addDebugFunds(amount);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(Tr.pick(
                      '資金を${amount >= 0 ? '+' : ''}$amount万円しました',
                      "Funds changed by ${amount >= 0 ? '+' : ''}$amount")),
                ),
              );
            },
            child: Text(Tr.pick('反映する', 'Apply')),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Tr.pick('セーブデータを削除しますか？', 'Delete your save?')),
        content: Text(Tr.pick('この操作は取り消せません。', 'This cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Tr.pick('キャンセル', 'Cancel')),
          ),
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
            child: Text(Tr.pick('削除する', 'Delete')),
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
