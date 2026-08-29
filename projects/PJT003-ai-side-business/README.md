# [PJT003] ai-side-business

## 概要

AI で成果物を自動生成して納品する副業のための、**実行エンジン + 経営管理ツール**。

このツールは2層でできている。

| 層 | やること | 主なコマンド |
|---|---|---|
| **自動化エンジン** | 案件を受けて、成果物の生成・検品・納品ファイル出力までを人手なしで実行する | `service` `job` `auto` `cost` |
| **経営レイヤー** | 何を売るか決め、計画し、売上と原価を数字で管理する | `ideas` `research` `plan` `status` `price` |

自動化エンジンが実際の作業をやり、経営レイヤーが「儲かっているか」を見る。
文章の生成は Claude が担当し、**適合スコア・見積もり・原価・粗利率は自前の計算式**で出すので、
「なぜこの順位なのか」「なぜこの金額なのか」「1件あたりいくら残るのか」を数字で説明できる。

### 自動化の流れ

```
依頼を登録        python main.py job add minutes --input meeting.txt --price 6000
       ↓
  auto を実行     python main.py auto
       ↓
  ① 生成         Claude が成果物を作る
  ② 検品         機械チェック（文字数・必須項目・景表法NG語・AIの前置き残り）
                 ＋ AI検品（依頼を満たしているかを100点満点で採点）
  ③ 修正         80点未満なら指摘を渡して自動で書き直す（既定1回まで）
  ④ 納品         deliverables/ にファイル出力・送付文も生成
  ⑤ 記録         検品を通ったものだけ売上に計上し、API原価を差し引いて粗利を出す
       ↓
  人が見るのは「要確認」になった案件だけ
```

**人手が要るのは、検品を通らなかった案件の確認だけ。**
それ以外は `auto` 一発で納品ファイルまで出る。Windows タスクスケジューラに
`run-auto.ps1` を登録すれば、案件を溜めておくだけで自動処理される。

## できること

### 自動化エンジン

| コマンド | 内容 |
|---|---|
| `service` | 自動化できるサービス（議事録・ブログ・LP・FAQ など9種）の一覧と詳細 |
| `job add` | 依頼を案件として登録する |
| `auto` | 未処理の案件をまとめて生成・検品・納品ファイル出力する |
| `job show` | 納品物と品質スコア・原価・粗利を確認する |
| `job delivered` | 納品完了にして売上を計上する |
| `cost` | API原価と粗利率のレポート（`--estimate` で実行前の概算） |

### 経営レイヤー

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

## 提供できるサービス（自動化済み）

| key | サービス | 想定単価 | 手作業 | 自動実行 |
|---|---|---:|---:|---:|
| `minutes` | 議事録作成 | 3,000〜8,000円 | 1.5h | 2分 |
| `blog` | ブログ記事執筆 | 5,000〜15,000円 | 3h | 3分 |
| `product` | 商品説明文作成 | 2,000〜5,000円 | 1h | 2分 |
| `sns` | SNS投稿作成（10本） | 3,000〜10,000円 | 2h | 2分 |
| `lp` | LPコピー作成 | 20,000〜50,000円 | 8h | 4分 |
| `mail` | ステップメール（5通） | 15,000〜30,000円 | 6h | 3分 |
| `summary` | 資料要約 | 2,000〜5,000円 | 1h | 2分 |
| `faq` | FAQ作成（15問） | 5,000〜15,000円 | 2.5h | 2分 |
| `script` | 動画台本作成 | 5,000〜15,000円 | 3h | 3分 |

サービスを増やしたい場合は `src/auto/services.py` に定義を1つ足すだけでよい。

## 構成

```
PJT003-ai-side-business/
├── main.py             CLI エントリポイント
├── run-auto.ps1        タスクスケジューラ用の定期実行スクリプト
├── src/
│   ├── auto/           ★ 自動化エンジン
│   │   ├── services.py   サービス定義（プロンプト・品質基準・単価）
│   │   ├── pipeline.py   生成 → 検品 → 修正 のループ
│   │   ├── qa.py         機械チェック + AI検品
│   │   ├── jobs.py       案件キューと自動実行
│   │   ├── deliver.py    納品ファイル・送付文の出力
│   │   └── cost.py       API原価と粗利の集計
│   ├── llm.py          Claude API ラッパー（使用量計測・構造化出力）
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
├── tests/              単体テスト（70件・API を呼ばない）
├── data/               プロフィール・タスク・売上・案件（git 除外）
├── deliverables/       納品ファイル（git 除外）
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

## 使い方（自動化エンジン）

### 何を自動化できるか見る

```powershell
python main.py service                    # 一覧
python main.py service show minutes       # 詳細（必要な入力・品質基準・検品観点）
```

### 実行前に原価を確認する

```powershell
python main.py cost --estimate
```

```
  サービス                想定原価                想定単価       粗利率      目標必要件数
  議事録作成                25円      3,000〜8,000円     99.2%        17 件/月
  ブログ記事執筆              43円      5,000〜15,000円     99.1%        11 件/月
  LPコピー作成              53円     20,000〜50,000円     99.7%         3 件/月
```

API 利用料は 1 件あたり数十円。**単価の 1% 未満**なので、粗利率は 99% 前後になる。
「目標必要件数」は、プロフィールの目標月収を最低単価で達成するのに要する件数。

### 依頼を登録する

```powershell
# ファイルから（文字起こし・資料など）
python main.py job add minutes --input meeting.txt --client "株式会社A" --price 6000 --title "8月定例"

# 直接指定
python main.py job add blog --text "テーマ: 40代からの副業の始め方 / 読者: 会社員" --price 8000

# 追加の指定を渡す
python main.py job add sns --input theme.txt --options "トーンは丁寧め。絵文字なし" --price 5000
```

### 自動処理する

```powershell
python main.py auto              # 未処理をすべて処理
python main.py auto --limit 3    # 3件だけ
python main.py auto --no-qa      # AI検品を省く（機械チェックのみ・原価を約4割削減）
```

実行するとこう出る。

```
[1] 8月定例  <議事録作成>  株式会社A
  [1/3] 議事録を生成中...
  [2/3] 検品中...（2,140文字）
  [3/3] 指摘 2 件を修正中...（1回目）
  完了: 2,380文字 / 47.2秒 / 原価 31.4円
  売価 6,000円 → 粗利 5,969円（粗利率 99.5%）
  納品ファイル: deliverables\2026-08-29_001_株式会社A_8月定例.md
```

検品を通らなかった案件は `要確認` として残り、**売上には計上されない**。
内容を直してから納品完了にする。

```powershell
python main.py job list                # 案件の一覧と粗利率
python main.py job show 1              # 納品物の中身と品質スコア
python main.py job delivered 1         # 納品完了 → ここで売上を計上
```

### 実績を確認する

```powershell
python main.py cost
```

```
  売上          6,000 円
  原価             31 円（API利用料）
  粗利          5,969 円   粗利率 99.5%

  1件あたり: 売価 6,000円 / 原価 31円
  実行時間 : 合計 0.03時間  → 実質時給 179,084 円
  手作業なら 1.5時間かかる内容（1.5時間の削減）
```

### 定期実行で完全自動にする

`run-auto.ps1` をタスクスケジューラに登録すると、案件を溜めておくだけで自動処理される。

```powershell
# 毎日 6:00 に実行する（PowerShell を管理者で開いて実行）
$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
           -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PWD\run-auto.ps1`""
$trigger = New-ScheduledTaskTrigger -Daily -At 6:00
Register-ScheduledTask -TaskName "AI副業-自動処理" -Action $action -Trigger $trigger
```

実行ログは `logs/auto-YYYY-MM-DD.log` に残る。

### 品質はどう担保しているか

自動化の弱点は「誰も見ないまま納品されること」なので、二段で止めている。

| 段 | 内容 | 特徴 |
|---|---|---|
| 機械チェック | 文字数・必須項目の有無・景表法NG語・AIの前置きやプレースホルダの残り | 確実に検出。**AIが何点を付けようとここで引っかかれば不合格** |
| AI検品 | サービスごとの観点で100点満点採点し、指摘を出す | 依頼を満たしているかを見る |

80点未満または「高」深刻度の指摘があれば、指摘を渡して自動で書き直す（既定1回）。
それでも通らなければ `要確認` として人に上げる。**設計上、人が見るのはここだけ。**

---

## 使い方（経営レイヤー）

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

外部 API を呼ばない部分は単体テスト済み（70件）。Claude の応答はモックに差し替えて、
生成 → 検品 → 修正 → 納品 → 売上計上 → 原価集計まで通しで検証している。

```powershell
python -m unittest discover -s tests
```

| ファイル | 対象 |
|---|---|
| `tests/test_core.py` | 適合スコア・見積もり・進捗集計・JSONパース・プロフィール入力 |
| `tests/test_auto.py` | サービス定義の整合性・機械チェック・修正ループ・案件実行・原価計算 |

## データの扱い

- プロフィール・タスク・売上・案件は `data/` 配下の JSON に保存される
- **`deliverables/`（納品物）と `logs/` は顧客の情報が入るため `.gitignore` 済み**
- `data/*.json` と `data/reports/` も `.gitignore` 済み（個人情報を push しない）
- API キーは `.env` にのみ置く

### モデルと原価

既定は `claude-opus-5`（入力 $5 / 出力 $25 per 1M トークン）。
費用を抑えたい場合は `.env` の `CLAUDE_MODEL` で変更できる。

```
CLAUDE_MODEL=claude-sonnet-5     # 入力 $2 / 出力 $10 — 原価が約6割になる
```

円換算レートは `.env` の `USD_JPY`（既定 155）で調整する。
同じサービスを連続処理する際はプロンプトキャッシュが効くため、実測原価は概算より下がる。

## 注意

- **納品前に必ず自分で目を通す。** 検品は二段で入れているが、事実関係の正しさまでは保証できない。
  特に固有名詞・数値・日付は原文と突き合わせる
- 顧客から預かった情報を AI に渡すことになるため、**守秘義務契約の内容を事前に確認する**。
  機密性の高い案件は受けない判断も必要
- AI 生成物であることの開示が必要かは、取引先の規約による。事前に確認する
- このツールは意思決定を支援するもので、**収益を保証するものではない**
- 本業の就業規則（副業規定）は事前に確認する
- 年間の副業所得が 20 万円を超える場合は確定申告が必要

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
- [x] 自動化エンジン（生成 → 検品 → 修正 → 納品 → 原価計算）
- [x] サービスカタログ9種
- [x] 定期実行スクリプト
- [ ] 実運用での検証（初報酬まで）
- [ ] 案件検索の自動化（クラウドソーシングの新着チェック）
- [ ] Batches API での夜間一括処理（原価が半額になる）
