# [PJT006] gainer-ranking-site

## 概要

日本株（東証プライム/スタンダード/グロース）の値上がり率ランキングを毎日自動取得し、
静的サイトとして公開する。広告（Google AdSense想定）による収益化が目的。

GitHub Actions が毎日平日 16:00 JST（大引け後）にランキングを取得・記録し、
GitHub Pages に自動デプロイする。

## 構成

```
src/
  fetcher.py     kabutan.jp から当日の値上がりランキングを取得
  build_site.py  取得→data/*.json保存→サイトビルドのエントリポイント
  render.py      Jinja2テンプレートからoutput/に静的HTMLを生成
templates/       ページテンプレート（Jinja2）
data/            日別ランキング（YYYY-MM-DD.json）。過去分の蓄積がアーカイブページの元データ
output/          ビルド成果物（gitignore対象、CI実行のたびに再生成）
```

## ローカルでの動作確認

```powershell
cd projects/PJT006-gainer-ranking-site
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python src/build_site.py
```

`output/index.html` をブラウザで開いて確認する。

## 自動更新（GitHub Actions）

`.github/workflows/daily-gainers-site.yml`（リポジトリルート）が
平日 16:00 JST に自動実行し、`data/*.json` をコミット、`output/` を
GitHub Pages にデプロイする。手動テストは GitHub の Actions タブから
`workflow_dispatch` で実行できる。

市場休場日などでランキングが0件の場合は、コミット・デプロイをスキップして
正常終了する（既存データは壊さない）。

## AdSense（要対応・TODO）

- `templates/base.html` に広告枠のプレースホルダーを設置済み（`data-ad-client="ca-pub-XXXXXXXXXXXXXXXX"`）。
  AdSenseアカウントの取得・審査申請はユーザー本人が行う必要がある。
  審査には一般的に、プライバシーポリシー・実際のコンテンツ・一定期間の運用実績が求められる。
- 審査通過後、`templates/base.html` の publisher ID・ad-slot ID を実際の値に置き換え、
  コメントアウトしている `<script>` タグを有効化する。

## 既知の制約・注意事項（v1時点）

- データ取得元（kabutan.jp）のスクレイピングは利用規約上のリスクを許容した上で採用している。
  今後規約変更や取得停止要請があった場合はデータ取得方法の見直しが必要。
- 14日間のパフォーマンス追跡（`PJT003-quality-gainer-tracker` にある機能）は v1 では未実装。
- 掲載情報は投資助言ではない旨を `templates/about.html` に明記している。
