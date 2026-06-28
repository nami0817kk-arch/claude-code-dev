# [PJT001] stock-investment

## 概要

日本株・米国株を対象とした投資支援システム。
株価データ取得・テクニカル分析・ポートフォリオ管理・ニュース分析を Python で実装する。

## 機能

| モジュール | 内容 |
|---|---|
| `src/data/fetcher.py` | yfinance で株価・銘柄情報を取得 |
| `src/analysis/indicators.py` | SMA / RSI / MACD / ボリンジャーバンドを計算 |
| `src/analysis/screener.py` | 条件でスクリーニング |
| `src/portfolio/manager.py` | 保有銘柄の損益管理 |
| `src/report/chart.py` | Plotly でローソク足・構成比チャート生成 |
| `src/report/news.py` | RSS 収集 + Claude API でニュース要約 |

## 構成

```
PJT001-stock-investment/
├── src/
│   ├── data/          # 株価取得
│   ├── analysis/      # 指標・スクリーニング
│   ├── portfolio/     # 保有管理
│   └── report/        # チャート・ニュース分析
├── tests/
├── docs/
├── data/
│   ├── raw/           # 取得した生データ（git 除外）
│   └── portfolio.csv  # 保有銘柄リスト
├── .env               # API キー（git 除外）
├── .env.example       # キーのひな型
└── requirements.txt
```

## セットアップ

```powershell
# 仮想環境を有効化
.venv\Scripts\Activate.ps1

# API キーを設定
copy .env.example .env
# .env を編集して ANTHROPIC_API_KEY を入力
```

## 使い方（例）

```python
from src.data.fetcher import fetch_price
from src.analysis.indicators import add_indicators
from src.report.chart import candlestick

df = fetch_price("7203.T", period="6mo")   # トヨタ
df = add_indicators(df)
fig = candlestick(df, "7203.T")
fig.show()
```

## 進め方

- [x] 環境構築
- [x] 各モジュールのスケルトン実装
- [ ] ポートフォリオ登録・サマリー動作確認
- [ ] スクリーニング動作確認
- [ ] ニュース分析動作確認
- [ ] レポート出力の整備
