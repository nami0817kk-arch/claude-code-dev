import '../l10n/tr.dart';

/// 新規クラブ作成時に選べるリーグの雰囲気(架空名で再現した5つの国風リーグ)。
enum LeagueTheme { england, spain, germany, italy, france }

extension LeagueThemeInfo on LeagueTheme {
  /// リーグの表示名。
  String get label {
    switch (this) {
      case LeagueTheme.england:
        return Tr.pick('アルビオン・リーグ', 'Albion League');
      case LeagueTheme.spain:
        return Tr.pick('イベリア・リーグ', 'Iberia League');
      case LeagueTheme.germany:
        return Tr.pick('ゲルマニア・リーグ', 'Germania League');
      case LeagueTheme.italy:
        return Tr.pick('アペニン・リーグ', 'Apennine League');
      case LeagueTheme.france:
        return Tr.pick('ガリア・リーグ', 'Gallia League');
    }
  }

  /// どの国をイメージしたリーグかの補足表示。
  String get flavorLabel {
    switch (this) {
      case LeagueTheme.england:
        return Tr.pick('イングランド風', 'England-inspired');
      case LeagueTheme.spain:
        return Tr.pick('スペイン風', 'Spain-inspired');
      case LeagueTheme.germany:
        return Tr.pick('ドイツ風', 'Germany-inspired');
      case LeagueTheme.italy:
        return Tr.pick('イタリア風', 'Italy-inspired');
      case LeagueTheme.france:
        return Tr.pick('フランス風', 'France-inspired');
    }
  }

  /// この国風テーマにおける国内カップ戦の名称(リーグ名の語幹に由来する)。
  String get domesticCupName {
    switch (this) {
      case LeagueTheme.england:
        return Tr.pick('アルビオン杯', 'Albion Cup');
      case LeagueTheme.spain:
        return Tr.pick('イベリア杯', 'Iberia Cup');
      case LeagueTheme.germany:
        return Tr.pick('ゲルマニア杯', 'Germania Cup');
      case LeagueTheme.italy:
        return Tr.pick('アペニン杯', 'Apennine Cup');
      case LeagueTheme.france:
        return Tr.pick('ガリア杯', 'Gallia Cup');
    }
  }
}
