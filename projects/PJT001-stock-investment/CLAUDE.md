# PJT001 stock-investment

日本株・米国株の投資支援。株価取得・テクニカル指標・スクリーニング・レポート生成。

## 前提

- Windows 11 / PowerShell 前提。`requirements.txt` に `pyodbc` と `pywin32` が入っており、
  **Linux では丸ごとはインストールできない**。
- CI（Linux）はテスト用の最小セット `requirements-test.txt` だけを入れて `pytest` を回す。
  テストは Windows 専用パッケージに依存しない部分だけを対象にしている。

## よく使うコマンド

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt

pytest                 # テスト（ネットワーク不要）
python main.py         # 本体
```

## 手を入れるときに気をつけること

- `screener` の `_swing_score`（配点）と `_passes_*_filters`（絞り込み）が
  「どの銘柄を買い候補に出すか」を決めている中心部分。しきい値を変えると
  結果が静かに変わるので、`tests/test_swing_score.py` /
  `tests/test_screen_filters.py` も必ず一緒に直す。
  テストが落ちたら、それは意図した変更かどうかの確認を促している。
- `_passes_technical_filters` の MACD 判定は `macd and macd_sig` という
  真偽値評価なので、**値が厳密に 0.0 だと「無い」扱いになる**。
  直すと選定結果が変わるため現状維持にしてあり、その挙動はテストで固定している。
- `data/watchlist.csv` は入力データ。`market` は JP/US、`cap_type` は large/mid/small。
- `.env` は git 除外。必要なキーは `.env.example` にある。
- `requirements.txt` は現状バージョン未固定。上流の新版で壊れうるので、
  動いている環境で `pip freeze` を取って `==` に固定するとよい
  （pywin32 / pyodbc を含むため、固定作業は Windows 側で行う必要がある）。
- ネットワークに出る処理（yfinance / RSS / Claude API）はテストに含めない。
  テストは常にオフラインで通る状態を保つ。
