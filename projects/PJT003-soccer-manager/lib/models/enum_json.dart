/// セーブデータの列挙型を安全に復元する。将来enumの値が削除・改名された場合でも、
/// 未知の文字列に対しては例外を投げず[fallback]へ倒すことで、古いセーブの
/// 読み込みがクラッシュしないようにする(Team._parseFormationと同じ考え方)。
T enumFromName<T>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final v in values) {
    if ((v as Enum).name == name) return v;
  }
  return fallback;
}
