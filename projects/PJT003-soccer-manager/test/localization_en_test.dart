import 'package:flutter_test/flutter_test.dart';
import 'package:soccer_manager/data/glossary_entries.dart';
import 'package:soccer_manager/data/guide_sections.dart';
import 'package:soccer_manager/data/name_pool.dart';
import 'package:soccer_manager/l10n/tr.dart';
import 'package:soccer_manager/logic/achievement_engine.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/player.dart';

/// 英語表示そのものを確認するテスト。
///
/// game_logic_test は表示言語を日本語に固定しているので、英語側は誰も
/// 見ていない状態になりうる。ここでは英語に切り替えたうえで、実際に
/// 英語が返ることと、言語を切り替えたら追随することを確かめる。
final _japanese = RegExp(r'[぀-ゟ゠-ヿ一-鿿]');

void main() {
  setUp(() => Tr.language = AppLanguage.english);
  tearDown(() {
    Tr.language = AppLanguage.system;
    Tr.resolvedLocaleIsEnglish = null;
  });

  test(
      'enum labels and descriptions come back in English, with no Japanese '
      'left in them', () {
    final samples = <String>[
      for (final p in Position.values) ...[p.label, p.fullLabel],
      for (final r in PlayerRole.values) ...[r.label, r.description],
      for (final p in PlayerPersonality.values) ...[p.label, p.description],
      for (final t in PlayerTrait.values) ...[t.label, t.description],
      for (final s in SquadStatus.values) ...[s.label, s.description],
      for (final d in PlayerDuty.values) ...[d.label, d.description],
      for (final k in AttributeKeys.all) AttributeKeys.labelOf(k),
    ];
    expect(samples, isNotEmpty);
    for (final s in samples) {
      expect(_japanese.hasMatch(s), isFalse, reason: '日本語が残っている: $s');
    }
  });

  test('the long-form content (guide, glossary, achievements) is English too',
      () {
    final texts = <String>[
      for (final s in guideSections) ...[
        s.title,
        s.overview,
        for (final t in s.topics) ...[t.title, t.description],
      ],
      for (final e in glossaryEntries) ...[
        e.term,
        e.description,
        e.category.label,
      ],
      for (final a in AchievementEngine.all) ...[a.name, a.description],
    ];
    expect(texts.length, greaterThan(300),
        reason: 'ガイド・用語集・実績がほとんど空なら、そもそも検査になっていない');
    for (final t in texts) {
      expect(_japanese.hasMatch(t), isFalse, reason: '日本語が残っている: $t');
    }
  });

  test(
      'new games generate English club and player names, and Japanese ones '
      'when the language is Japanese', () {
    for (final theme in LeagueTheme.values) {
      for (final name in NamePool.themedClubNames(theme, 20)) {
        expect(_japanese.hasMatch(name), isFalse,
            reason: '英語のクラブ名に日本語が混じっている: $name');
      }
    }
    // 英語の選手名は「名 姓」の2語。
    final player = NamePool.randomPlayerName();
    expect(_japanese.hasMatch(player), isFalse);
    expect(player.split(' ').length, 2, reason: '英語名は名と姓の2語: $player');

    Tr.language = AppLanguage.japanese;
    expect(_japanese.hasMatch(NamePool.randomPlayerName()), isTrue,
        reason: '日本語に戻したら日本語の名前が出るはず');
  });

  test('switching the language switches the text, in both directions', () {
    Tr.language = AppLanguage.japanese;
    final ja = Position.gk.fullLabel;
    Tr.language = AppLanguage.english;
    final en = Position.gk.fullLabel;
    expect(ja, 'ゴールキーパー');
    expect(en, 'Goalkeeper');

    // 一度英語で読んだあとに日本語へ戻しても、キャッシュされずに追随する
    // (const/final で組み立てると、ここが固定されて落ちる)。
    Tr.language = AppLanguage.japanese;
    expect(Position.gk.fullLabel, 'ゴールキーパー');
    expect(AchievementEngine.all.first.name, isNot(equals('First Title')));
    expect(glossaryEntries.first.category.label, '選手能力値');
  });

  test('Tr follows the locale Flutter resolved, not the raw device locale', () {
    Tr.language = AppLanguage.system;
    // 端末は日本語だが、アプリが解決したロケールは英語、という食い違い。
    Tr.deviceIsEnglish = Tr.deviceIsEnglishForTest;
    Tr.resolvedLocaleIsEnglish = true;
    expect(Tr.isEnglish, isTrue);
    Tr.resolvedLocaleIsEnglish = false;
    expect(Tr.isEnglish, isFalse);
  });
}
