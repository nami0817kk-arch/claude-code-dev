"""
自動株選定モジュール

pick_from_news  : ニュース → テクニカル+ファンダメンタル → Claude 判定
pick_from_screen: スクリーニング → テクニカル+ファンダメンタル → Claude 判定

両関数とも dict を返す:
{
  "flow": str, "market": str, "date": str,
  "rankings": [{"rank","ticker","name","stars","confidence","reason", ...}],
  "summary": str, "market_outlook": str
}
"""
import json
import os
from datetime import date
import anthropic
import pandas as pd
import feedparser
import yfinance as yf

from src.data.fetcher import fetch_price
from src.analysis.indicators import add_indicators
from src.analysis.screener import screen, load_watchlist
from src.report.news import fetch_news, GOOGLE_NEWS_URL
from src.report.db_manager import load_performance_summary
from src.data.market_sentiment import get_market_context, market_context_text

MODEL = "claude-sonnet-4-6"


def _claude(prompt: str, max_tokens: int = 2048) -> str:
    client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
    msg = client.messages.create(
        model=MODEL,
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
        r  = df.iloc[-1]

        def _f(col):
            return float(r[col]) if col in r.index and not pd.isna(r[col]) else None

        close    = _f("Close")
        sma20    = _f("SMA20")
        rsi      = _f("RSI14")
        macd     = _f("MACD")
        macd_sig = _f("MACD_signal")
        bb_upper = _f("BB_upper")
        bb_lower = _f("BB_lower")
        stoch_k  = _f("STOCH_K")
        stoch_d  = _f("STOCH_D")
        atr14    = _f("ATR14")

        # OBV トレンド（直近5日）
        obv_trend = "不明"
        if "OBV" in df.columns and len(df) >= 5:
            obv_recent = df["OBV"].dropna().tail(5)
            if len(obv_recent) >= 2:
                obv_trend = "上昇" if obv_recent.iloc[-1] > obv_recent.iloc[0] else "下降"

        return {
            "ticker":   ticker,
            "close":    round(close, 2)    if close    else None,
            "RSI14":    round(rsi, 1)      if rsi      else None,
            "MACD方向": "買い" if (macd and macd_sig and macd > macd_sig) else "売り",
            "SMA20比":  f"{'上' if sma20 and close and close > sma20 else '下'}回り",
            "BB位置":   _bb_position(close, bb_upper, bb_lower),
            "STOCH_K":  round(stoch_k, 1)  if stoch_k  else None,
            "STOCH_D":  round(stoch_d, 1)  if stoch_d  else None,
            "ATR14":    round(atr14, 2)    if atr14    else None,
            "OBV_trend": obv_trend,
        }
    except Exception:
        return None


def _fundamental_data(ticker: str) -> dict:
    """yfinance から PER・ROE・売上成長率・配当利回りを取得する"""
    try:
        info = yf.Ticker(ticker).info
        per      = info.get("trailingPE")
        pbr      = info.get("priceToBook")
        roe      = info.get("returnOnEquity")
        rev_gr   = info.get("revenueGrowth")
        div_yield = info.get("dividendYield")
        return {
            "PER":     round(per, 1)           if per      else None,
            "PBR":     round(pbr, 1)           if pbr      else None,
            "ROE":     round(roe * 100, 1)     if roe      else None,
            "売上成長率": round(rev_gr * 100, 1) if rev_gr   else None,
            "配当利回り": round(div_yield * 100, 2) if div_yield else None,
        }
    except Exception:
        return {}


def _bb_position(close, upper, lower) -> str:
    if close is None or upper is None or lower is None:
        return "不明"
    band = upper - lower
    if band == 0:
        return "中央付近"
    pos = (close - lower) / band
    if pos >= 0.8:
        return "上限付近"
    if pos <= 0.2:
        return "下限付近"
    return "中央付近"


def _parse_judge(raw: str, tech_list: list[dict]) -> tuple[list[dict], str, str]:
    """Claude の JSON 応答をパースして (rankings, summary, market_outlook) を返す"""
    try:
        start = raw.find("{")
        end   = raw.rfind("}") + 1
        data  = json.loads(raw[start:end])
        rankings       = data.get("rankings", [])
        summary        = data.get("summary", "")
        market_outlook = data.get("market_outlook", "")
        tech_map = {t["ticker"]: t for t in tech_list}
        for item in rankings:
            t = tech_map.get(item.get("ticker", ""), {})
            item.setdefault("close",     t.get("close"))
            item.setdefault("RSI14",     t.get("RSI14"))
            item.setdefault("MACD方向",  t.get("MACD方向"))
            item.setdefault("SMA20比",   t.get("SMA20比"))
            item.setdefault("BB位置",    t.get("BB位置"))
            item.setdefault("STOCH_K",   t.get("STOCH_K"))
            item.setdefault("confidence", None)
        return rankings, summary, market_outlook
    except Exception:
        return [], raw, ""


_JUDGE_FORMAT = """
回答は必ず以下の JSON 形式のみで返してください（マークダウン・説明不要）:
{{
  "rankings": [
    {{
      "rank": 1,
      "ticker": "7203.T",
      "name": "トヨタ自動車",
      "stars": "★★★★★",
      "confidence": 85,
      "reason": "テクニカル・ファンダメンタル・市場環境を踏まえた推奨理由を2文で"
    }}
  ],
  "summary": "市場環境と銘柄全体を踏まえた総評を3文以内で",
  "market_outlook": "現在の市場環境における注意点を1文で"
}}"""


def _build_tech_text(tech_list: list[dict], fund_map: dict) -> str:
    lines = []
    for s in tech_list:
        t    = s["ticker"]
        fund = fund_map.get(t, {})
        line = (
            f"  {t}({s.get('name','')}):"
            f" 終値{s['close']} RSI={s['RSI14']} MACD={s['MACD方向']}"
            f" SMA20={s['SMA20比']} BB={s['BB位置']}"
            f" Stoch%K={s.get('STOCH_K')} OBV={s.get('OBV_trend')}"
        )
        if fund:
            line += (
                f" | PER={fund.get('PER')} ROE={fund.get('ROE')}%"
                f" 売上成長={fund.get('売上成長率')}% 配当={fund.get('配当利回り')}%"
            )
        lines.append(line)
    return "\n".join(lines)


# ──────────────────────────────────────────────
# Flow 1: ニュース → テクニカル+ファンダメンタル → 判定
# ──────────────────────────────────────────────

def pick_from_news(market: str | None = None, top_n: int = 20) -> dict:
    wl = load_watchlist(market)
    watchlist_str = "\n".join(
        f"  {row['ticker']} ({row['name']})" for _, row in wl.iterrows()
    )

    # Step1: 市況ニュース収集 & Claude が候補銘柄を抽出
    print("  [Step1] 市況ニュースを収集中...")
    news_items = []
    for query in ["株式市場 投資 決算", "日本株 業績", "stock market earnings outlook", "economic forecast"]:
        try:
            feed = feedparser.parse(GOOGLE_NEWS_URL.format(query=query))
            import re
            for e in feed.entries[:6]:
                summary = re.sub(r"<[^>]+>", "", e.get("summary", ""))[:300]
                news_items.append(f"- {e.get('title','')}: {summary}")
            if len(news_items) >= 24:
                break
        except Exception:
            continue

    news_text = "\n".join(news_items[:24])

    extract_prompt = f"""あなたは機関投資家レベルの株式アナリストです。
以下のニュースを読み、ウォッチリストの中から「投資チャンスがありそうな銘柄」を最大{top_n}つ選んでください。
ニュースの内容（業績・金利・為替・セクタートレンド）との関連性を重視して選定してください。

【ニュース】
{news_text}

【ウォッチリスト】
{watchlist_str}

回答は以下の JSON のみで返してください（説明不要）:
{{"tickers": ["7203.T", "AAPL"]}}"""

    print("  [Step1] Claude がニュースから候補銘柄を抽出中...")
    raw = _claude(extract_prompt, max_tokens=512)
    try:
        s, e = raw.find("{"), raw.rfind("}") + 1
        tickers = json.loads(raw[s:e]).get("tickers", [])
    except Exception:
        tickers = wl["ticker"].tolist()[:top_n]

    if not tickers:
        return {"error": "ニュースから投資候補銘柄を特定できませんでした。"}
    print(f"  [Step1] 候補: {', '.join(tickers)}")

    # Step2: テクニカル + ファンダメンタル分析
    print("  [Step2] テクニカル・ファンダメンタル分析中...")
    tech_list = []
    for t in tickers:
        s = _technical_summary(t)
        if s:
            name = wl[wl["ticker"] == t]["name"].values
            s["name"] = name[0] if len(name) else t
            tech_list.append(s)

    fund_map = {}
    for t in tickers:
        fund_map[t] = _fundamental_data(t)

    news_by_ticker = {}
    for t in tickers:
        items = fetch_news(t, max_items=5)
        news_by_ticker[t] = [f"{i['title']} / {i['summary'][:100]}" for i in items] if items else ["関連ニュースなし"]

    # Step3: 市場センチメント取得
    print("  [Step3] 市場センチメントを確認中...")
    ctx      = get_market_context()
    ctx_text = market_context_text(ctx)
    perf     = load_performance_summary()
    perf_section = f"\n{perf}\n" if perf else ""

    # Step4: 最終判定
    print("  [Step4] Claude が総合判定中...")
    tech_text  = _build_tech_text(tech_list, fund_map)
    news_text2 = "\n".join(
        f"  {t}: {'; '.join(news_by_ticker.get(t, []))}" for t in tickers
    )

    judge_prompt = f"""あなたは機関投資家レベルの株式アナリストです。
テクニカル・ファンダメンタル・ニュース・市場環境を総合して、投資推奨銘柄を上位{top_n}件ランキングしてください。

{ctx_text}
{perf_section}
【テクニカル + ファンダメンタルデータ】
評価軸: RSI<30=強い売られすぎ、MACD買い=ポジティブ、BB下限=反発期待、Stoch%K<20=過売、OBV上昇=資金流入
       PER低=割安、ROE>10%=良好、売上成長率>5%=成長株
{tech_text}

【銘柄別ニュース（タイトル/概要）】
{news_text2}

【評価の優先順位】
1. テクニカル指標の複合シグナル（RSI+MACD+Stoch+BB）
2. ファンダメンタル（PER割安 × 成長性 × 配当）
3. ニュースのポジティブ/ネガティブ度
4. 市場センチメントとの整合性
5. 過去実績データで成績の良い条件パターン
{_JUDGE_FORMAT}"""

    raw = _claude(judge_prompt, max_tokens=2048)
    rankings, summary, market_outlook = _parse_judge(raw, tech_list)

    return {
        "flow":          "ニュース起点",
        "market":        market or "全銘柄",
        "date":          str(date.today()),
        "rankings":      rankings,
        "summary":       summary,
        "market_outlook": market_outlook,
        "vix":           ctx.get("VIX"),
        "fear_greed":    ctx.get("FearGreed"),
    }


# ──────────────────────────────────────────────
# Flow 2: スクリーニング → テクニカル+ファンダメンタル → 判定
# ──────────────────────────────────────────────

def pick_from_screen(market: str | None = None, top_n: int = 20) -> dict:
    # Step1: スクリーニング
    print("  [Step1] スクリーニング中...")
    df = screen(market=market, min_rsi=20, max_rsi=60)
    if df.empty:
        return {"error": "スクリーニング条件に合う銘柄が見つかりませんでした。"}
    print(f"  [Step1] {len(df)} 件ヒット: {', '.join(df['ticker'].tolist())}")

    # Step2: テクニカル + ファンダメンタル詳細
    print("  [Step2] テクニカル・ファンダメンタル分析中...")
    tech_list = []
    for _, row in df.iterrows():
        s = _technical_summary(row["ticker"])
        if s:
            s["name"] = row["name"]
            tech_list.append(s)

    if not tech_list:
        return {"error": "テクニカルデータの取得に失敗しました。"}

    fund_map = {}
    for s in tech_list:
        fund_map[s["ticker"]] = _fundamental_data(s["ticker"])

    # Step3: 市場センチメント
    print("  [Step3] 市場センチメントを確認中...")
    ctx      = get_market_context()
    ctx_text = market_context_text(ctx)
    perf     = load_performance_summary()
    perf_section = f"\n{perf}\n" if perf else ""

    # Step4: 最終判定
    print("  [Step4] Claude が総合判定中...")
    tech_text = _build_tech_text(tech_list, fund_map)

    judge_prompt = f"""あなたは機関投資家レベルの株式アナリストです。
RSI 20〜60 のスクリーニングを通過した銘柄を、テクニカル・ファンダメンタル・市場環境で総合評価し、
買いチャンスのある銘柄を上位{top_n}件ランキングしてください。

{ctx_text}
{perf_section}
【テクニカル + ファンダメンタルデータ（RSI 20〜60 スクリーニング済み）】
評価軸: RSI<30=強い売られすぎ(高評価)、MACD買い=ポジティブ、BB下限=反発期待、
       Stoch%K<20=過売で反発近い、OBV上昇=資金流入サイン
       PER低=割安、ROE>10%=良好、売上成長率>5%=成長株
{tech_text}

【評価の優先順位】
1. 複数テクニカル指標の一致（RSI+MACD+Stoch+OBV）
2. ファンダメンタルの裏付け（PER割安 × 高ROE × 成長性）
3. リスク管理（ATR14が低い＝安定性高い）
4. 市場センチメント（VIX・Fear&Greed）との整合性
5. 過去実績データで成績の良い条件パターン
{_JUDGE_FORMAT}"""

    raw = _claude(judge_prompt, max_tokens=2048)
    rankings, summary, market_outlook = _parse_judge(raw, tech_list)

    return {
        "flow":          "スクリーニング起点",
        "market":        market or "全銘柄",
        "date":          str(date.today()),
        "rankings":      rankings,
        "summary":       summary,
        "market_outlook": market_outlook,
        "vix":           ctx.get("VIX"),
        "fear_greed":    ctx.get("FearGreed"),
    }
