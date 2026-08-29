# [PJT003] ai-side-business

## 概要

AI（生成AI）を使った副業を、**思いつきで終わらせずに収益化まで持っていく**ための伴走ツール。

「AIで稼げるらしい」で止まってしまう原因は、たいてい次の3つ。

1. 自分に合う稼ぎ方が分からない
2. 調べただけで、最初の1件を取る動きに入れない
3. 進んでいるかどうかが分からず、続かない

このツールは、その3点をコマンドで潰していく。
アイデア出しと文章生成は Claude が担当し、**適合スコア・見積もり・進捗率は自前の計算式**で出すので、
「なぜこの順位なのか」「なぜこの金額なのか」を数字で説明できる。

## できること

| コマンド | 内容 |
|---|---|
| `init` | スキル・稼働時間・目標月収などのプロフィール登録 |
| `ideas` | プロフィールに合う副業アイデアを提案し、適合スコア順に並べる |
| `research` | 選んだアイデアの需要・競合・価格・撤退基準を調査する |
| `plan` | 90日ロードマップを作り、そのままタスクに登録する |
| `task` | タスクの確認・追加・完了 |
| `revenue` | 売上の記録と、実質時給の算出 |
| `status` | 今月の売上・目標達成率・進捗のダッシュボード |
| `price` | 手取りで希望時給が残る見積もり金額を逆算する |
| `proposal` | 応募文・DM・プロフィール文などをそのまま送れる形で作る |
| `review` | 週次レビュー。詰まっている一点を指摘し、来週のタスクを出す |
| `ask` | 現在の数字を踏まえた個別相談 |
| `report` | ここまでの内容を Markdown レポートに出力する |

## 構成

```
PJT003-ai-side-business/
├── main.py             CLI エントリポイント
├── src/
│   ├── llm.py          Claude API ラッパー（JSON 応答のパースまで）
│   ├── store.py        JSON ファイル永続化
│   ├── profile.py      プロフィール管理
│   ├── ideas.py        アイデア生成と適合スコア計算
│   ├── research.py     市場調査・実現性検証
│   ├── roadmap.py      90日ロードマップ生成とタスク化
│   ├── tracker.py      タスク・売上の記録と進捗計算
│   ├── pricing.py      見積もり計算
│   ├── proposal.py     営業文・提案文の生成
│   ├── coach.py        週次レビュー・相談
│   └── report.py       ダッシュボードと Markdown 出力
├── tests/              単体テスト（API を呼ばない部分）
├── data/               プロフィール・タスク・売上（git 除外）
├── .env.example
└── requirements.txt
```

## セットアップ

```powershell
cd projects\PJT003-ai-side-business

python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt

copy .env.example .env
# .env を開いて ANTHROPIC_API_KEY を記入する
```

## 使い方

### 1. プロフィールを登録する

```powershell
python main.py init
```

対話形式で、スキル・週の稼働時間・目標月収・初期投資の上限などを登録する。
以降のすべての提案がこの内容を土台にするので、ここは正直に入れる。

あとから変えるとき:

```powershell
python main.py profile --set hours_per_week=15 target_income=10万
```

### 2. アイデアを出す

```powershell
python main.py ideas --detail
```

Claude が案を出し、**適合スコア（100点満点）** を付けて並べる。配点は次のとおり。

| 観点 | 配点 | 見ているもの |
|---|---:|---|
| スキル適合 | 25 | 今のスキルで戦えるか |
| 稼働時間 | 20 | 週の使える時間に収まるか |
| 初期費用 | 15 | 予算内に収まるか |
| 収益化速度 | 15 | 期限内に初報酬が出るか |
| 収益の天井 | 15 | 目標月収に届く見込みがあるか |
| 競合の少なさ | 10 | 埋もれずに済むか |

`--detail` を付けるとスコアの内訳まで表示される。
2回目以降は保存済みを表示するだけなので、作り直すときは `--refresh` を付ける。

### 3. 本当に売れるか調べる

```powershell
python main.py research 1
```

需要の実態・顧客像・競合の弱点・適正価格・集客経路・**1週間でできる検証手順**・**撤退基準**を出す。
「進める / 条件付きで進める / 見送り推奨」の判定も付く。

### 4. 90日計画に落とす

```powershell
python main.py plan 1
```

3フェーズ（1〜30日 / 31〜60日 / 61〜90日）のロードマップを作り、
各タスクを期限付きでタスクリストに自動登録する。
市場調査を先に済ませてあれば、その結果も踏まえた計画になる。

### 5. 実行して記録する

```powershell
python main.py task list                  # やることを確認
python main.py task start 3               # 着手
python main.py task done 3                # 完了
python main.py task add "提案文を10件送る" --due 2026-09-30 --hours 4

python main.py revenue add 5000 --source "議事録作成" --hours 2
python main.py status                     # 今どこにいるかを確認
```

`--hours` を入れておくと**実質時給**が出る。単価の判断材料になる。

### 6. 値付けする

```powershell
python main.py price --hours 8 --hourly 3000 --difficulty 4 --platform crowdworks
```

難易度・修正回数・特急対応・経費・プラットフォーム手数料を踏まえ、
**手取りで希望時給が残る金額**を逆算し、ライト / 標準 / しっかり の3プランで提示する。
「受注ライン」を下回る依頼は、断るか対応範囲を削る判断に使う。

`--advice` を付けると、提示文面・値下げ要求への返し方まで出す。

### 7. 営業文を作る

```powershell
python main.py proposal apply --context "議事録作成の募集。月20本、単価3000円"
python main.py proposal profile
python main.py proposal dm --service "中小企業向けの議事録要約代行"
```

種類は `apply`（案件応募）/ `dm`（直接メッセージ）/ `profile`（自己紹介）/
`service`（サービス紹介）/ `followup`（追いかけ連絡）。

### 8. 毎週振り返る

```powershell
python main.py review           # 今週の評価と、詰まっている一点を出す
python main.py review --apply   # 提案された来週のタスクを登録する
python main.py ask "3週間提案しても返信がありません"
```

`ask` は現在のタスク進捗と売上を渡した上で答えるので、一般論ではなく今の状況への回答が返る。

### 9. まとめて記録に残す

```powershell
python main.py report --idea 1
```

`data/reports/report-YYYY-MM-DD.md` に、プロフィール・売上推移・調査結果・計画・タスクを出力する。

## テスト

外部 API を呼ばない部分（スコア計算・見積もり・進捗集計・JSON パース）は単体テスト済み。

```powershell
python -m unittest discover -s tests
```

## データの扱い

- プロフィール・タスク・売上は `data/` 配下の JSON に保存される
- `data/*.json` と `data/reports/` は `.gitignore` 済み（個人情報を push しない）
- API キーは `.env` にのみ置く

## 注意

- このツールは意思決定を支援するもので、**収益を保証するものではない**。AI の提案は必ず自分で裏を取る
- 本業の就業規則（副業規定）は事前に確認する
- 年間の副業所得が 20 万円を超える場合は確定申告が必要（`research` の出力にも注意点が出る）

## 進め方

- [x] プロフィール管理
- [x] アイデア生成 + 適合スコア
- [x] 市場調査・実現性検証
- [x] 90日ロードマップ + タスク化
- [x] タスク・売上トラッキング
- [x] 見積もり計算
- [x] 営業文生成
- [x] 週次レビュー・相談
- [x] Markdown レポート出力
- [ ] 実運用での検証（初報酬まで）
- [ ] 案件検索の自動化（クラウドソーシングの新着チェック）
