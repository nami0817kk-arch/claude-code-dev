"""
自動株選定モジュール

pick_from_news   : ニュース → ファンダメンタル → Claude 判定
pick_from_youtube: YouTube動画 → テクニカル+ファンダメンタル → Claude 判定

両関数とも dict を返す:
{
  "flow": str, "market": str, "date": str,
  "rankings": [{"rank","ticker","name","stars","confidence","reason", ...}],
  "summary": str, "market_outlook": str
}
"""
import json
import re
import os
from datetime import date, datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
import anthropic
import pandas as pd
import feedparser
import yfinance as yf

from src.data.fetcher import fetch_price
from src.analysis.indicators import add_indicators
from src.analysis.screener import load_watchlist
from src.report.news import fetch_news, fetch_market_news, fetch_kabutan_news, fetch_yahoo_finance_news, fetch_youtube_only_news, fetch_youtube_with_transcripts, fetch_article_body, GOOGLE_NEWS_URL
from src.report.db_manager import load_performance_summary
from src.data.market_sentiment import get_market_context, market_context_text

MODEL = "claude-haiku-4-5-20251001"


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

        # 最終行のCloseがNaN（当日の未確定バー）の場合は直前の有効値を使う
        if "Close" in df.columns:
            _close_series = df["Close"].dropna()
            close = float(_close_series.iloc[-1]) if not _close_series.empty else None
        else:
            close = None
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


_REC_LABEL = {1: "強く買い", 2: "買い", 3: "中立", 4: "売り", 5: "強く売り"}


def _fundamental_data(ticker: str) -> dict:
    """yfinance からファンダメンタル・アナリスト評価・決算日を取得する"""
    try:
        info = yf.Ticker(ticker).info
        per       = info.get("trailingPE")
        pbr       = info.get("priceToBook")
        roe       = info.get("returnOnEquity")
        rev_gr    = info.get("revenueGrowth")
        div_yield = info.get("dividendYield")

        # アナリスト目標株価
        close = (info.get("currentPrice")
                 or info.get("regularMarketPrice")
                 or info.get("previousClose"))
        target_mean  = info.get("targetMeanPrice")
        num_analysts = info.get("numberOfAnalystOpinions")
        rec_raw      = info.get("recommendationMean")
        upside = None
        if target_mean and close and close > 0:
            upside = round((target_mean / close - 1) * 100, 1)

        # 決算予定日（直近30日以内のみ表示）
        earnings_str = None
        try:
            ts = info.get("earningsTimestamp") or info.get("earningsTimestampStart")
            if ts and ts > 0:
                d = datetime.fromtimestamp(ts).date()
                days = (d - date.today()).days
                if -3 <= days <= 30:
                    earnings_str = f"{d.strftime('%m/%d')}({days:+d}日)"
        except Exception:
            pass

        return {
            "close":       close,
            "PER":        round(per, 1)            if per        else None,
            "PBR":        round(pbr, 1)            if pbr        else None,
            "ROE":        round(roe * 100, 1)      if roe        else None,
            "売上成長率":  round(rev_gr * 100, 1)  if rev_gr     else None,
            "配当利回り":  round(div_yield, 2) if div_yield else None,
            "目標株価":    round(target_mean, 1)   if target_mean else None,
            "目標乖離率":  upside,
            "アナリスト数": num_analysts,
            "推奨":        _REC_LABEL.get(round(rec_raw) if rec_raw else 0),
            "決算予定":    earnings_str,
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


def _fix_unescaped_quotes(text: str) -> str:
    """JSON文字列値内の未エスケープ二重引用符を修正するステートマシン"""
    result = []
    in_string = False
    i = 0
    while i < len(text):
        c = text[i]
        if not in_string:
            result.append(c)
            if c == '"':
                in_string = True
        else:
            if c == '\\':
                result.append(c)
                i += 1
                if i < len(text):
                    result.append(text[i])
            elif c == '"':
                # 後続文字（空白除く）が : , } ] なら文字列終端
                rest = text[i + 1:i + 20].lstrip()
                if rest and rest[0] in ':,}]\n':
                    in_string = False
                    result.append(c)
                else:
                    # 未エスケープ引用符 → エスケープして継続
                    result.append('\\"')
            else:
                result.append(c)
        i += 1
    return ''.join(result)


def _extract_json_obj(text: str) -> dict | None:
    """テキストからバランスブレースで最初のJSONオブジェクトを安全に抽出する"""
    # マークダウンコードブロックを除去
    text = re.sub(r"```(?:json)?", "", text).strip()
    # 直接パース試行
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    # 未エスケープ引用符を修正して再試行
    try:
        return json.loads(_fix_unescaped_quotes(text))
    except json.JSONDecodeError:
        pass
    # バランスブレースで抽出
    start = text.find("{")
    if start < 0:
        return None
    depth = 0
    in_string = False
    escape_next = False
    for i, ch in enumerate(text[start:], start):
        if escape_next:
            escape_next = False
            continue
        if ch == "\\" and in_string:
            escape_next = True
            continue
        if ch == '"':
            in_string = not in_string
            continue
        if not in_string:
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    chunk = text[start:i + 1]
                    try:
                        return json.loads(chunk)
                    except json.JSONDecodeError:
                        try:
                            return json.loads(_fix_unescaped_quotes(chunk))
                        except json.JSONDecodeError:
                            return None
    return None


def _parse_judge(raw: str, tech_list: list[dict]) -> tuple[list[dict], str, str]:
    """Claude の JSON 応答をパースして (rankings, summary, market_outlook) を返す"""
    data = _extract_json_obj(raw)
    if data is None:
        return [], raw, ""
    rankings       = data.get("rankings", [])
    summary        = data.get("summary", "")
    market_outlook = data.get("market_outlook", "")
    tech_map = {t["ticker"]: t for t in tech_list}
    for item in rankings:
        t = tech_map.get(item.get("ticker", ""), {})
        item.setdefault("close",      t.get("close"))
        item.setdefault("RSI14",      t.get("RSI14"))
        item.setdefault("MACD方向",   t.get("MACD方向"))
        item.setdefault("SMA20比",    t.get("SMA20比"))
        item.setdefault("BB位置",     t.get("BB位置"))
        item.setdefault("STOCH_K",    t.get("STOCH_K"))
        item.setdefault("confidence", None)
        item.setdefault("news_basis", None)
    return rankings, summary, market_outlook


_JUDGE_FORMAT = """
【重要】rankings は必ず{top_n}件すべて出力してください。候補が多い場合も{top_n}位まで全件記載してください。
回答は以下の JSON 形式のみで返してください（マークダウン・説明不要）:
{{
  "rankings": [
    {{
      "rank": 1,
      "ticker": "7203.T",
      "name": "トヨタ自動車",
      "stars": "★★★★★",
      "confidence": 85,
      "reason": "テクニカル・ファンダメンタル・市場環境を踏まえた推奨理由を1文で簡潔に"
    }}
  ],
  "summary": "市場環境と銘柄全体を踏まえた総評を2文以内で",
  "market_outlook": "現在の市場環境における注意点を1文で"
}}"""

_JUDGE_FORMAT_NEWS = """
【重要】rankings は必ず{top_n}件すべて出力してください。候補が多い場合も{top_n}位まで全件記載してください。
回答は以下の JSON 形式のみで返してください（マークダウン・説明不要）:
{{
  "rankings": [
    {{
      "rank": 1,
      "ticker": "7203.T",
      "name": "トヨタ自動車",
      "stars": "★★★★★",
      "confidence": 85,
      "reason": "ニュース・ファンダメンタル・市場環境を踏まえた推奨理由を1文で簡潔に",
      "news_basis": "提供データ内の実際のニュース見出しのみ記載。関連ニュースがない銘柄は必ず空欄\"\"にすること。推測・要約・捏造禁止"
    }}
  ],
  "summary": "市場環境と銘柄全体を踏まえた総評を2文以内で",
  "market_outlook": "現在の市場環境における注意点を1文で"
}}"""


def _build_fund_text(tickers: list[str], fund_map: dict, wl) -> str:
    """ニュース起点用：ファンダメンタルデータのみのテキストサマリー"""
    lines = []
    for t in tickers:
        fund = fund_map.get(t, {})
        name = wl[wl["ticker"] == t]["name"].values
        name = name[0] if len(name) else t
        close = fund.get("close")
        line = f"  {t}({name}): 株価={close}"
        if fund:
            line += (
                f" PER={fund.get('PER')} ROE={fund.get('ROE')}%"
                f" 売上成長={fund.get('売上成長率')}% 配当={fund.get('配当利回り')}%"
            )
            line += _analyst_suffix(fund)
        lines.append(line)
    return "\n".join(lines)


def _analyst_suffix(fund: dict) -> str:
    """アナリスト目標株価・推奨・決算予定の文字列を返す"""
    parts = []
    if fund.get("目標乖離率") is not None:
        sign = "+" if fund["目標乖離率"] >= 0 else ""
        n = fund.get("アナリスト数") or 0
        parts.append(f"目標株価乖離={sign}{fund['目標乖離率']}%({n}人)")
    if fund.get("推奨"):
        parts.append(f"アナリスト推奨={fund['推奨']}")
    if fund.get("決算予定"):
        parts.append(f"⚠決算={fund['決算予定']}")
    return ("  [" + " ".join(parts) + "]") if parts else ""


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
            line += _analyst_suffix(fund)
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

    # Step1: 市況ニュース収集（株探 + Yahoo!ファイナンス）& Claude が候補銘柄を抽出
    print("  [Step1] 市況ニュースを収集中（株探 + Yahoo!ファイナンス）...")
    raw_news  = fetch_kabutan_news(max_items=20) + fetch_yahoo_finance_news(max_items=20)
    news_items = [f"- [{n['source']}] {n['title']}: {n['summary']}" for n in raw_news]
    news_text  = "\n".join(news_items)

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
        tickers = []

    print(f"  [Step1] 候補 {len(tickers)} 件: {', '.join(tickers)}")

    # Step2: ファンダメンタル分析（テクニカル計算なし）
    print("  [Step2] ファンダメンタル分析中...")
    fund_map = {}
    for t in tickers:
        fund_map[t] = _fundamental_data(t)

    # ニュース記事本文を並列フェッチ
    print("  [Step2] ニュース記事本文を取得中（並列）...")
    raw_news_map: dict[str, list[dict]] = {}
    for t in tickers:
        raw_news_map[t] = fetch_news(t, max_items=3)

    # 記事本文を並列取得（タイムアウト30秒）
    url_to_body: dict[str, str] = {}
    all_urls = [
        (t, item["link"])
        for t, items in raw_news_map.items()
        for item in items
        if item.get("link")
    ]
    with ThreadPoolExecutor(max_workers=8) as ex:
        future_to_url = {ex.submit(fetch_article_body, url): (t, url) for t, url in all_urls}
        for fut in as_completed(future_to_url, timeout=30):
            _, url = future_to_url[fut]
            try:
                url_to_body[url] = fut.result()
            except Exception:
                pass

    news_by_ticker: dict[str, list[str]] = {}
    for t in tickers:
        items = raw_news_map.get(t, [])
        if not items:
            news_by_ticker[t] = ["関連ニュースなし"]
            continue
        parts = []
        for item in items:
            body = url_to_body.get(item.get("link", ""), "")
            text = f"[{item['source']}] {item['title']}"
            if body:
                text += f"【本文】{body[:300]}"
            elif item.get("summary"):
                text += f"【概要】{item['summary'][:150]}"
            parts.append(text)
        news_by_ticker[t] = parts

    # Step3: 市場センチメント取得
    print("  [Step3] 市場センチメントを確認中...")
    ctx      = get_market_context()
    ctx_text = market_context_text(ctx)
    perf     = load_performance_summary()
    perf_section = f"\n{perf}\n" if perf else ""

    # Step4: 最終判定
    print("  [Step4] Claude が総合判定中...")
    fund_text  = _build_fund_text(tickers, fund_map, wl)
    news_text2 = "\n".join(
        f"  {t}: {'; '.join(news_by_ticker.get(t, []))}" for t in tickers
    )

    judge_prompt = f"""あなたは機関投資家レベルの株式アナリストです。
ファンダメンタル・ニュース・市場環境を総合して、投資推奨銘柄を上位{top_n}件ランキングしてください。

{ctx_text}
{perf_section}
【ファンダメンタルデータ】
評価軸: PER低=割安、ROE>10%=良好、売上成長率>5%=成長株、目標株価乖離が大きい=上値余地あり
{fund_text}

【銘柄別ニュース（タイトル/本文概要）】
※ 「関連ニュースなし」の銘柄は news_basis を必ず空欄にすること
{news_text2}

【評価の優先順位】
1. ニュースのポジティブ/ネガティブ度（業績・新製品・提携・規制）
2. ファンダメンタル（PER割安 × 成長性 × アナリスト推奨）
3. 市場センチメントとの整合性
4. 過去実績データで成績の良い条件パターン

【news_basis の記載ルール（厳守）】
・上記【銘柄別ニュース】に記載された実際のニュース見出しのみ引用すること
・「関連ニュースなし」の銘柄は news_basis を空欄（""）にすること
・ニュースの推測・要約・補足・捏造は一切禁止
・文字列値の中にダブルクォート（"）を絶対に使用しないこと。「」を使うこと
{_JUDGE_FORMAT_NEWS.format(top_n=top_n)}"""

    raw = _claude(judge_prompt, max_tokens=8192)
    rankings, summary, market_outlook = _parse_judge(raw, [])
    # close を fund_map から補完
    for item in rankings:
        if item.get("close") is None:
            item["close"] = fund_map.get(item.get("ticker", ""), {}).get("close")

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
# Flow 2: YouTube動画 → テクニカル+ファンダメンタル → 判定
# ──────────────────────────────────────────────

def pick_from_youtube(market: str | None = None, top_n: int = 15) -> dict:
    """
    YouTubeチャンネル（株リアルライブ・投深ハイスクール）の最新動画タイトルのみを
    情報源として銘柄を選定し、テクニカル+ファンダメンタルで評価してランキングする。
    """
    wl = load_watchlist(market)
    watchlist_str = "\n".join(
        f"  {row['ticker']} ({row['name']})" for _, row in wl.iterrows()
    )

    # Step1: YouTube動画取得（24時間以内 + 文字起こし付き）& Claude が候補銘柄を抽出
    print("  [Step1] YouTube動画を収集中（24時間以内・文字起こし付き）...")
    yt_news = fetch_youtube_with_transcripts(max_videos=top_n)
    if not yt_news:
        print("  [Step1] 24時間以内の動画なし → 通常取得にフォールバック")
        yt_news = fetch_youtube_only_news(max_items=15)
    if not yt_news:
        return {"error": "YouTubeニュースの取得に失敗しました。"}

    yt_lines = []
    for n in yt_news:
        line = f"- [{n['source']}] {n['title']}"
        tr = n.get("transcript", "")
        if tr:
            line += f"\n  【文字起こし】{tr[:400]}"
        elif n.get("summary"):
            line += f": {n['summary'][:150]}"
        yt_lines.append(line)
    yt_text = "\n".join(yt_lines)

    print(f"  [Step1] {len(yt_news)} 本の動画を取得（文字起こしあり: {sum(1 for n in yt_news if n.get('transcript'))} 本）")

    extract_prompt = f"""あなたは株式投資アナリストです。
以下のYouTube動画タイトル・文字起こしを読み、ウォッチリストの中から「動画で取り上げられている、または関連性が高い銘柄」を最大{top_n}件選んでください。
動画タイトルや文字起こしに含まれるキーワード（業種・テーマ・銘柄名・銘柄コード）との関連を重視して選定してください。

【YouTube動画（タイトル + 文字起こし）】
{yt_text}

【ウォッチリスト】
{watchlist_str}

回答は以下の JSON のみで返してください（説明不要）:
{{"tickers": ["7203.T", "AAPL"]}}"""

    print("  [Step1] Claude がYouTube動画から候補銘柄を抽出中...")
    raw = _claude(extract_prompt, max_tokens=512)
    data = _extract_json_obj(raw)
    tickers = data.get("tickers", []) if data else []  # YouTube動画から直接抽出した銘柄
    yt_ticker_set = set(tickers)
    print(f"  [Step1] YouTube言及: {len(tickers)} 件: {', '.join(tickers)}")

    # Step2: テクニカル + ファンダメンタル分析
    print("  [Step2] テクニカル・ファンダメンタル分析中...")
    tech_list = []
    for t in tickers:
        s = _technical_summary(t)
        if s:
            name = wl[wl["ticker"] == t]["name"].values
            s["name"] = name[0] if len(name) else t
            s["yt_mentioned"] = t in yt_ticker_set  # YouTube言及フラグ
            tech_list.append(s)

    fund_map = {}
    for t in tickers:
        fund_map[t] = _fundamental_data(t)

    # Step3: 市場センチメント
    print("  [Step3] 市場センチメントを確認中...")
    ctx          = get_market_context()
    ctx_text     = market_context_text(ctx)
    perf         = load_performance_summary()
    perf_section = f"\n{perf}\n" if perf else ""

    # Step4: 最終判定（YouTube起点専用プロンプト）
    print("  [Step4] Claude がYouTube動画起点で総合判定中...")
    tech_text = _build_tech_text(tech_list, fund_map)

    yt_mentioned_names = [
        f"{t}({wl[wl['ticker']==t]['name'].values[0] if len(wl[wl['ticker']==t]) else t})"
        for t in tickers
    ]

    judge_prompt = f"""あなたは株式投資アナリストです。
【戦略】以下のYouTube動画（投資系チャンネル）で取り上げられているテーマ・銘柄をもとに、
テクニカル・ファンダメンタルを総合して投資推奨ランキングを作成してください。
スイング取引（数日〜2週間）を前提とします。

{ctx_text}
{perf_section}
【参考にしたYouTube動画（タイトル + 文字起こし）】
{yt_text}

【対象銘柄（全てYouTube動画で言及・関連する銘柄）】
  {', '.join(yt_mentioned_names)}

【テクニカル + ファンダメンタルデータ】
{tech_text}

【評価の優先順位】
1. YouTube動画で明示的に取り上げられた銘柄やテーマとの関連性
2. テクニカル指標（RSI売られすぎ、MACD買い転換、Stoch過売圏、BB下限）
3. ファンダメンタル（売上成長率、ROE、PER割安）
4. 市場センチメント（VIX・Fear&Greed）との整合性

【news_basis の記載ルール（厳守）】
・上記【参考にしたYouTube動画】から該当する動画タイトルまたは文字起こし内の発言をそのまま引用すること
・動画タイトル・文字起こしに明示されていない推測・捏造は一切禁止
・文字列値の中にダブルクォート（"）を絶対に使用しないこと。「」を使うこと
・「〜として言及される見込み」「〜と関連すると考えられる」等の推測表現は禁止
・提供された動画タイトル以外の情報を作らないこと

【reason 欄に必ず含めること】
・テクニカルのエントリータイミング
・スイング目標（SMA20や直近高値まで何%）と損切り目安

{_JUDGE_FORMAT_NEWS.format(top_n=top_n)}"""

    raw = _claude(judge_prompt, max_tokens=8192)
    rankings, summary, market_outlook = _parse_judge(raw, tech_list)

    return {
        "flow":           "YouTube起点",
        "market":         market or "全銘柄",
        "date":           str(date.today()),
        "rankings":       rankings,
        "summary":        summary,
        "market_outlook": market_outlook,
        "vix":            ctx.get("VIX"),
        "fear_greed":     ctx.get("FearGreed"),
    }
