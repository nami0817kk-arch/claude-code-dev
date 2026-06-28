"""
自動株選定モジュール

pick_from_news  : ニュース → テクニカル → Claude 判定
pick_from_screen: スクリーニング → テクニカル → Claude 判定

両関数とも dict を返す:
{
  "flow": str,
  "market": str,
  "date": str,
  "rankings": [{"rank", "ticker", "name", "stars", "reason", ...}],
  "summary": str
}
"""
import json
import os
from datetime import date
import anthropic
import pandas as pd
import feedparser

from src.data.fetcher import fetch_price
from src.analysis.indicators import add_indicators
from src.analysis.screener import screen, load_watchlist
from src.report.news import fetch_news, GOOGLE_NEWS_URL


def _claude(prompt: str, max_tokens: int = 1024) -> str:
    client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
    msg = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=max_tokens,
        messages=[{"role": "user", "content": prompt}]
    )
    return msg.content[0].text


def _technical_summary(ticker: str) -> dict | None:
    try:
        df = fetch_price(ticker, period="3mo")
        if df.empty:
            return None
        df = add_indicators(df)
        r = df.iloc[-1]
        close    = float(r["Close"])
        sma20    = float(r["SMA20"])     if not pd.isna(r["SMA20"])     else None
        rsi      = float(r["RSI14"])     if not pd.isna(r["RSI14"])     else None
        macd     = float(r["MACD"])      if not pd.isna(r["MACD"])      else None
        macd_sig = float(r["MACD_signal"]) if not pd.isna(r["MACD_signal"]) else None
        bb_upper = float(r["BB_upper"])  if not pd.isna(r["BB_upper"])  else None
        bb_lower = float(r["BB_lower"])  if not pd.isna(r["BB_lower"])  else None
        return {
            "ticker":   ticker,
            "close":    round(close, 2),
            "RSI14":    round(rsi, 1)   if rsi      else None,
            "MACD方向": "買い" if (macd and macd_sig and macd > macd_sig) else "売り",
            "SMA20比":  f"{'上' if sma20 and close > sma20 else '下'}回り",
            "BB位置":   _bb_position(close, bb_upper, bb_lower),
        }
    except Exception:
        return None


def _bb_position(close: float, upper: float | None, lower: float | None) -> str:
    if upper is None or lower is None:
        return "不明"
    band = upper - lower
    if band == 0:
        return "中央"
    pos = (close - lower) / band
    if pos >= 0.8:
        return "上限付近"
    if pos <= 0.2:
        return "下限付近"
    return "中央付近"


def _parse_judge(raw: str, tech_list: list[dict]) -> tuple[list[dict], str]:
    """Claude の JSON 応答をパースして (rankings, summary) を返す"""
    try:
        start = raw.find("{")
        end   = raw.rfind("}") + 1
        data  = json.loads(raw[start:end])
        rankings = data.get("rankings", [])
        summary  = data.get("summary", "")
        # テクニカルデータをランキングにマージ
        tech_map = {t["ticker"]: t for t in tech_list}
        for item in rankings:
            t = tech_map.get(item.get("ticker", ""), {})
            item.setdefault("close",    t.get("close"))
            item.setdefault("RSI14",    t.get("RSI14"))
            item.setdefault("MACD方向", t.get("MACD方向"))
            item.setdefault("SMA20比",  t.get("SMA20比"))
            item.setdefault("BB位置",   t.get("BB位置"))
        return rankings, summary
    except Exception:
        return [], raw


_JUDGE_FORMAT = """
回答は必ず以下の JSON 形式のみで返してください（マークダウン・説明不要）:
{{
  "rankings": [
    {{
      "rank": 1,
      "ticker": "7203.T",
      "name": "トヨタ自動車",
      "stars": "★★★★★",
      "reason": "理由を2文で"
    }}
  ],
  "summary": "総評を3文以内で"
}}"""


# ──────────────────────────────────────────────
# Flow 1: ニュース → テクニカル → 判定
# ──────────────────────────────────────────────

def pick_from_news(market: str | None = None, top_n: int = 5) -> dict:
    wl = load_watchlist(market)
    watchlist_str = "\n".join(
        f"  {row['ticker']} ({row['name']})" for _, row in wl.iterrows()
    )

    # Step1: ニュース収集 & 銘柄抽出
    print("  [Step1] 市況ニュースを収集中...")
    news_items = []
    for query in ["株式市場 投資", "日本株 決算", "stock market earnings", "economic outlook"]:
        try:
            feed = feedparser.parse(GOOGLE_NEWS_URL.format(query=query))
            for e in feed.entries[:5]:
                news_items.append(f"- {e.get('title', '')}")
            if len(news_items) >= 20:
                break
        except Exception:
            continue

    news_text = "\n".join(news_items[:20])

    extract_prompt = f"""あなたは株式投資アナリストです。
以下のニュース見出しを読み、下記ウォッチリストの中から「投資チャンスがありそうな銘柄」を最大{top_n}つ選んでください。

【ニュース】
{news_text}

【ウォッチリスト】
{watchlist_str}

回答は以下のJSON形式のみで返してください（説明不要）:
{{"tickers": ["7203.T", "AAPL"]}}"""

    print("  [Step1] Claude がニュースから候補銘柄を抽出中...")
    raw = _claude(extract_prompt, max_tokens=256)
    try:
        s, e = raw.find("{"), raw.rfind("}") + 1
        tickers = json.loads(raw[s:e]).get("tickers", [])
    except Exception:
        tickers = wl["ticker"].tolist()[:top_n]

    if not tickers:
        return {"error": "ニュースから投資候補銘柄を特定できませんでした。"}
    print(f"  [Step1] 候補: {', '.join(tickers)}")

    # Step2: テクニカル分析
    print("  [Step2] テクニカル分析中...")
    tech_list = []
    for t in tickers:
        s = _technical_summary(t)
        if s:
            name = wl[wl["ticker"] == t]["name"].values
            s["name"] = name[0] if len(name) else t
            tech_list.append(s)

    news_by_ticker = {}
    for t in tickers:
        items = fetch_news(t, max_items=3)
        news_by_ticker[t] = [i["title"] for i in items] if items else ["関連ニュースなし"]

    # Step3: 最終判定
    print("  [Step3] Claude が最終判定中...")
    tech_text = "\n".join(
        f"  {s['ticker']}({s['name']}): 終値{s['close']} RSI={s['RSI14']} "
        f"MACD={s['MACD方向']} SMA20={s['SMA20比']} BB={s['BB位置']}"
        for s in tech_list
    )
    news_text2 = "\n".join(
        f"  {t}: {'; '.join(news_by_ticker.get(t, []))}" for t in tickers
    )

    judge_prompt = f"""あなたは株式投資アナリストです。
テクニカルデータとニュースを総合して投資推奨銘柄を上位{top_n}件ランキングしてください。

【テクニカルデータ】
{tech_text}

【銘柄別ニュース】
{news_text2}
{_JUDGE_FORMAT}"""

    raw = _claude(judge_prompt, max_tokens=1024)
    rankings, summary = _parse_judge(raw, tech_list)

    return {
        "flow":     "ニュース起点",
        "market":   market or "全銘柄",
        "date":     str(date.today()),
        "rankings": rankings,
        "summary":  summary,
    }


# ──────────────────────────────────────────────
# Flow 2: スクリーニング → テクニカル → 判定
# ──────────────────────────────────────────────

def pick_from_screen(market: str | None = None, top_n: int = 5) -> dict:
    # Step1: スクリーニング
    print("  [Step1] スクリーニング中...")
    df = screen(market=market, min_rsi=20, max_rsi=60)
    if df.empty:
        return {"error": "スクリーニング条件に合う銘柄が見つかりませんでした。"}
    print(f"  [Step1] {len(df)} 件ヒット: {', '.join(df['ticker'].tolist())}")

    # Step2: テクニカル詳細
    print("  [Step2] テクニカル詳細を取得中...")
    tech_list = []
    for _, row in df.iterrows():
        s = _technical_summary(row["ticker"])
        if s:
            s["name"] = row["name"]
            tech_list.append(s)

    if not tech_list:
        return {"error": "テクニカルデータの取得に失敗しました。"}

    # Step3: 最終判定
    print("  [Step3] Claude が最終判定中...")
    tech_text = "\n".join(
        f"  {s['ticker']}({s['name']}): 終値{s['close']} RSI={s['RSI14']} "
        f"MACD={s['MACD方向']} SMA20={s['SMA20比']} BB={s['BB位置']}"
        for s in tech_list
    )

    judge_prompt = f"""あなたは株式投資アナリストです。
テクニカルデータをもとに買いのチャンスがある銘柄を上位{top_n}件ランキングしてください。

【テクニカルデータ（RSI 20〜60 スクリーニング済み）】
{tech_text}

評価基準:
- RSI 30未満: 強い売られすぎ（買いチャンス高）
- RSI 30〜45: 売られすぎ傾向
- MACD 買い方向: ポジティブ
- BB 下限付近: 反発の可能性
{_JUDGE_FORMAT}"""

    raw = _claude(judge_prompt, max_tokens=1024)
    rankings, summary = _parse_judge(raw, tech_list)

    return {
        "flow":     "スクリーニング起点",
        "market":   market or "全銘柄",
        "date":     str(date.today()),
        "rankings": rankings,
        "summary":  summary,
    }
