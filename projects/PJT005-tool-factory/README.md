# [PJT005] tool-factory

## 概要

計算ツールのサイトを**量産する**ための仕組み。現在 10 ツール。
ツールを1本足すのに必要なのは `tools/` に定義ファイルを1つ置くことだけで、
ページ・SEO・構造化データ・広告枠・アフィリ導線・内部リンク・サイトマップは自動で付く。

PJT004 の[副業立ち上げ工程表](../PJT004-ai-side-business/README.md)で出した結論の実装。

- 記事ではなくツールを量産する（陳腐化せず、競合が弱い）
- **広告だけでは分岐点に届かない。** 30本で 3,150円 対 26,775円 と 8.5 倍差が付くため、
  収益導線を設定していないツールはビルド時に警告し、テストでも落とす
- 多産多死。1本にかける時間を短くすることが、そのまま到達時期を縮める

## 1本増やす手順

```powershell
python new_tool.py cpk "工程能力指数 Cpk 計算ツール" --category 品質管理
# tools/cpk.py を埋める
python build.py --serve
```

埋めるのは次の4つだけ。

| 項目 | 内容 |
|---|---|
| `description` / `lead` | 検索意図に最初に答える文 |
| `inputs` / `outputs` | 入力欄と、JS の式で書いた計算 |
| `affiliate` | **誰に何を勧めるか。ここが収益点** |
| `faq` / `steps` / `formula_note` | 使い方と根拠 |

## ツール定義の書き方

```python
TOOL = Tool(
    slug="safety-stock",                  # URL になる
    title="安全在庫・発注点 計算ツール",
    description="…",                      # 検索結果に出る一文
    category="在庫管理",                   # 一覧のグループ分けと内部リンクに使う
    inputs=[
        Field("daily", "1日あたりの平均使用量", unit="個/日", default=100),
        Field("z", "欠品許容率", kind="select", default=1.65,
              options=[("5%（安全率95%）", 1.65), ("1%（安全率99%）", 2.33)]),
    ],
    outputs=[
        Output("safety_stock", "安全在庫", "z * sigma * Math.sqrt(lead_time)",
               unit="個", decimals=0, primary=True),
        Output("reorder_point", "発注点", "daily * lead_time + safety_stock"),
    ],
    affiliate=Affiliate(heading="…", body="…", cta="…", url="…"),
)
```

- `expression` は **JS の式**。先に定義した出力も参照できる（`safety_stock` を発注点の式で使うなど）
- `Math.sqrt` など JS の組み込み関数がそのまま使える。複雑な計算も式の中に書ける
- `primary=True` の出力が大きく表示される。指定しなければ最初の1つ

## 自動で付くもの

| 項目 | 内容 |
|---|---|
| SEO | title / description / canonical / OGP |
| 構造化データ | SoftwareApplication・BreadcrumbList・FAQPage（FAQがある場合） |
| **PR表記** | アフィリリンクがあるページに自動挿入（ステマ規制対応） |
| リンク属性 | アフィリリンクに `rel="sponsored nofollow noopener"` |
| 内部リンク | 同カテゴリのツールを優先して4本 |
| URL共有 | 入力値がURLに載り、開き直すと結果が復元される |
| サイト全体 | 一覧ページ・sitemap.xml・robots.txt |
| favicon | data URI で埋め込み（追加リクエストなし） |
| 固定ページ | 運営者情報・プライバシーポリシー・お問い合わせ（フッターから全ページに導線） |

広告（AdSense）と計測（GA・Search Console）は `site.json` に設定したときだけ出力される。
未設定なら一切のタグが入らないので、審査前でもそのまま公開できる。

## 公開まで

### 公開の前に site.json を埋める

```json
{
  "name": "生産管理の計算ツール",
  "base_url": "https://<ユーザー名>.github.io/<リポジトリ名>",
  "owner": "運営者名（個人名または屋号）",
  "contact_email": "連絡先メールアドレス",
  "published_at": "2026-09-01"
}
```

`owner` と `contact_email` が空だとビルド時に警告が出る。
**ASP と広告配信の審査では、運営者情報と連絡先の記載が見られる**ため、
空のまま公開しても審査を通りにくい。

### GitHub Pages に自動公開する

`.github/workflows/pages.yml` を用意してある。`master` に push すると、
テスト → ビルド → 公開まで自動で走る。

**GitHub 側で1度だけ設定が要る。**

1. リポジトリの **Settings → Pages → Build and deployment → Source** を
   「**GitHub Actions**」に変更する
2. 公開URL（`https://<ユーザー名>.github.io/<リポジトリ名>/`）を
   `site.json` の `base_url` に設定する
3. `master` に push する

テストが落ちるとビルドされないので、収益導線の無いツールや壊れた定義が
公開されることはない。

### 手動で公開する場合

```powershell
python build.py            # dist/ に出力
```

`dist/` の中身をそのまま任意の静的ホスティングに置ける。サーバー処理は不要。

### 資産の参照は相対パス

`style.css` などへの参照は相対パスで出力している。
絶対パス（`/style.css`）にすると、GitHub Pages のプロジェクトサイトのように
**サブディレクトリで配信したときにドメイン直下を指してしまい 404 になる**。
相対パスなので、ドメイン直下・サブパス・ローカルファイル（`file://`）の
いずれでも同じように動く。

`site.json` の `base_url` は canonical と sitemap.xml にのみ使われる。
ここは実際の公開URLに合わせておくこと。

### 長期的には専用リポジトリを

いまは開発ワークスペースのサブディレクトリを公開する形になっている。
独自ドメインを当てる段階になったら、`PJT005-tool-factory` の中身を
専用リポジトリに移してドメイン直下で配信するほうが扱いやすい。
その場合も相対パスなので、コードの変更は要らない。

## 設計

### プライバシーポリシーは設定から組み立てる

ポリシーの本文は `site.json` の設定と、ツールに収益導線があるかから生成している。
アクセス解析を入れていなければ解析の項は出ないし、広告タグを設定していなければ
広告配信の項も出ない。**やっていないことが書かれたポリシーにならない**ようにするため。

逆に、広告や解析を有効にすれば該当する項が自動で入るので、
設定を変えたあとにポリシーの更新を忘れることもない。

### 計算はブラウザ内で完結する

入力値は一切サーバーに送られない。実務の数字を入れるツールなので、
「送信していない」と明記できる形にした。フッターにもその旨を出している。

### 収益導線が無いツールは作らせない

`build.py` は導線未設定のツールを一覧で警告し、`tests/test_build.py` は
それを失敗として扱う。広告のみだと分岐点に 50,000PV 必要で、
30本作っても届かないため、あとから足すのではなく最初から入れる。

### 式は JS のまま書く

計算式を独自のミニ言語にすると、複雑な計算のたびに言語側を拡張することになる。
JS の式をそのまま埋め込む形にしたので、`Math.*` も三項演算子も条件分岐も書ける。
式は自分で書くもので外部入力ではないため、この方式で問題ない。

### `<script>` の中に入る文字列はすべてエスケープする

JSON-LD やツール定義を script 要素に埋め込む際、文字列中の `</script>` が
要素を途中で終わらせてしまう。`<` `>` `&` をユニコードエスケープすることで、
JSON としての意味を変えずにこれを防いでいる。

## テスト

```powershell
python -m unittest discover -s tests
```

46件。仕様の検証、HTMLの構造、構造化データがJSONとしてパースできること、
PR表記の有無、エスケープ、広告タグが設定時のみ出ること、
固定ページが設定に応じて正しく出し分けられること、
そして**実際に置いてあるツールが公開できる状態か**を確認する。

公開ワークフローはテストが通らないとビルドに進まないので、
収益導線の無いツールや、説明・FAQの欠けたツールは公開されない。

## 構成

```
PJT005-tool-factory/
├── build.py            全ツールを dist/ に出力
├── new_tool.py         ツールのひな型を作る
├── site.json           サイト名・ドメイン・広告ID・計測ID
├── tools/              ツール定義（1ファイル＝1ツール）
│   ├── _spec.py        Tool / Field / Output / Faq / Affiliate
│   ├── safety_stock.py 安全在庫・発注点
│   ├── eoq.py          経済的発注量
│   ├── oee.py          設備総合効率
│   ├── cpk.py          工程能力指数
│   ├── standard_time.py 標準時間・必要人員
│   ├── labor_productivity.py 人時生産性
│   ├── yield_rate.py   歩留まり・投入必要数
│   ├── manufacturing_cost.py 製造原価・損益分岐点
│   ├── payback_period.py 設備投資の回収期間
│   └── paid_leave.py   有給休暇の付与日数
├── theme/
│   ├── base.py         HTML の組み立て
│   ├── pages.py        固定ページ（運営者情報・ポリシー・問い合わせ）
│   ├── style.css       共通スタイル（全ページで共有）
│   └── app.js          共通スクリプト（計算・URL共有）
├── tests/
└── dist/               出力（git 除外）
```

## 進め方

- [x] 共通テンプレート（レイアウト・SEO・構造化データ・広告枠・アフィリ導線）
- [x] ツール定義の宣言化とひな型生成
- [x] ビルドとテスト
- [x] 最初の10本（在庫2・生産管理2・品質2・原価2・労務1、うち1本は生産管理）
- [x] GitHub Pages への自動公開（テスト通過が公開の条件）
- [x] 運営者情報・プライバシーポリシー・お問い合わせ（審査で見られるページ）
- [ ] `site.json` の `owner` / `contact_email` / `base_url` を設定する
- [ ] **サイトを公開する**（多くのASPは審査に実在するサイトのURLを求める）
- [ ] **ASP に登録し、`affiliate.url` を実際の提携リンクに差し替える**
- [ ] Search Console に登録し、sitemap.xml を送信する
- [ ] 30本まで量産
