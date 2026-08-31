# 多言語対応の現状と、残りの進め方

## 仕組み

- 文言は `lib/l10n/app_ja.arb` (原本) と `lib/l10n/app_en.arb` (翻訳) に置く
- `flutter gen-l10n` で `lib/l10n/app_localizations.dart` が生成される
  (`flutter pub get` / ビルド時にも自動で走る)
- 画面側からは `context.l10n.キー名` で引く (`lib/l10n/l10n_ext.dart`)
- 表示言語は端末の言語設定に従う。英語なら英語、それ以外は日本語

日本語をテンプレートにしているのは、このアプリの文言が日本語で書かれ、
日本語で見直されるため。英語を原本にすると日本語のニュアンスが
英語経由で劣化する。

## 移行済みの範囲

新規プレイヤーが最初に触れる導線を優先して移行してある。

- アプリ名
- オンボーディング (スキップ / 次へ / はじめる)
- スタート画面 (スロット一覧・新規クラブ作成ダイアログ・削除確認)
- ボトムナビゲーション (ホーム / スカッド / 戦術 / 順位表)
- 初回ガイド (はじめの一歩) の全文言

つまり **英語の端末でアプリを起動し、クラブを作るところまでは英語で完結する**。
そこから先の画面は日本語のままになる。

## 残っている範囲

`lib/` にはまだ日本語の文字列リテラルが残っている。多い順:

- `lib/models/player.dart` — 特性54種・性格20種・ロール20種のラベルと説明
- `lib/data/guide_sections.dart` — ゲーム内ガイド
- `lib/data/glossary_entries.dart` — 用語集
- `lib/data/name_pool.dart` — 選手名・クラブ名のプール
- 各画面 (`lib/screens/*.dart`)

現在の残数は次のコマンドで数えられる。

```bash
python3 - <<'PY'
import glob,re,io
jp=re.compile(r'[぀-ヿ一-鿿]')
lit=re.compile(r"""'([^'\\\n]|\\.)*'""")
total=0
for p in glob.glob('lib/**/*.dart',recursive=True):
    if '/l10n/' in p: continue
    src=io.open(p,encoding='utf-8').read()
    lines=[l for l in src.split('\n')
           if not l.strip().startswith('//') and not l.strip().startswith('///')]
    total+=sum(1 for l in lines for m in lit.finditer(l) if jp.search(m.group(0)))
print(total)
PY
```

## 進め方

**一度に全部やらないこと。** 画面単位で進めて、そのつど
`flutter analyze` と `flutter test` を通す。まとめて書き換えると、
どこで壊れたか分からなくなる。

1. 対象の画面の文字列を `app_ja.arb` にキーとして追加する
2. `app_en.arb` に英訳を追加する (キーを揃えないとテストが落ちる)
3. `flutter gen-l10n`
4. 画面側を `context.l10n.キー名` に差し替える
5. `flutter analyze && flutter test`

### 注意

- `const` なウィジェットの中では `context` を使えない。
  `const InputDecoration(...)` のような箇所は `const` を外し、
  内側の変わらない部分にだけ `const` を残す
- 数値を含む文言は文字列連結ではなくプレースホルダを使う
  (`"{number}位以内"` のように)。語順が言語で変わるため
- 英語は日本語より横に長くなる。ボタンやチップは
  `overflow: TextOverflow.ellipsis` を添えるか `Flexible` で包む
- `name_pool.dart` の選手名・クラブ名は翻訳ではなく、
  英語ロケール用に別のプールを用意するのが自然

## 優先順位についての注記

英語化は市場を広げるが、日本語で手応えを得る前に着手すると、
翻訳の保守コストだけが先に増える。日本語版で遊んでもらえる感触を
掴んでから残りを進めるのが順当。基盤と入口は用意してあるので、
必要になったときに画面単位で足していけばよい。
