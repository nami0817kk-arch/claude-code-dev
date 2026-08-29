/// 新規クラブ作成時に選べるリーグの雰囲気(架空名で再現した5つの国風リーグ)。
enum LeagueTheme { england, spain, germany, italy, france }

extension LeagueThemeInfo on LeagueTheme {
  /// リーグの表示名。
  String get label {
    switch (this) {
      case LeagueTheme.england:
        return 'アルビオン・リーグ';
      case LeagueTheme.spain:
        return 'イベリア・リーグ';
      case LeagueTheme.germany:
        return 'ゲルマニア・リーグ';
      case LeagueTheme.italy:
        return 'アペニン・リーグ';
      case LeagueTheme.france:
        return 'ガリア・リーグ';
    }
  }

  /// どの国をイメージしたリーグかの補足表示。
  String get flavorLabel {
    switch (this) {
      case LeagueTheme.england:
        return 'イングランド風';
      case LeagueTheme.spain:
        return 'スペイン風';
      case LeagueTheme.germany:
        return 'ドイツ風';
      case LeagueTheme.italy:
        return 'イタリア風';
      case LeagueTheme.france:
        return 'フランス風';
    }
  }

  /// この国風テーマにおける国内カップ戦の名称(リーグ名の語幹に由来する)。
  String get domesticCupName {
    switch (this) {
      case LeagueTheme.england:
        return 'アルビオン杯';
      case LeagueTheme.spain:
        return 'イベリア杯';
      case LeagueTheme.germany:
        return 'ゲルマニア杯';
      case LeagueTheme.italy:
        return 'アペニン杯';
      case LeagueTheme.france:
        return 'ガリア杯';
    }
  }
}
