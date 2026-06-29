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
import re
import os
from datetime import date
import anthropic
import pandas as pd
import feedparser
import yfinance as yf

from src.data.fetcher import fetch_price
from src.analysis.indicators import add_indicators
from src.analysis.screener import screen, load_watchlist
from src.report.news import fetch_news, fetch_market_news, fetch_youtube_only_news, GOOGLE_NEWS_URL
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


def _extract_json_obj(text: str) -> dict | None:
    """テキストからバランスブレースで最初のJSONオブジェクトを安全に抽出する"""
    # マークダウンコードブロックを除去
    text = re.sub(r"```(?:json)?\s*", "", text)
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
                    try:
                        return json.loads(text[start:i + 1])
                    except json.JSONDecodeError:
                        try:
                            return json.loads(text[start:i + 1], strict=False)
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
      "reason": "テクニカル・ファンダメンタル・市場環境を踏まえた推奨理由を1文で簡潔に",
      "news_basis": "選定の根拠となったニュース見出しを1〜2件、出典付きで記載（例: 【株探】決算上方修正を発表）"
    }}
  ],
  "summary": "市場環境と銘柄全体を踏まえた総評を2文以内で",
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


def _build_swing_tech_text(tech_list: list[dict], fund_map: dict) -> str:
    """スイング取引分析用のテキストサマリー（swing_score を先頭に表示、降順）"""
    entries = []
    for s in tech_list:
        t     = s["ticker"]
        fund  = fund_map.get(t, {})
        score = s.get("swing_score", 0)
        line = (
            f"  [{score}pt] {t}({s.get('name','')}):"
            f" 終値{s['close']} RSI={s['RSI14']} MACD={s['MACD方向']}"
            f" Stoch%K={s.get('STOCH_K')} Stoch%D={s.get('STOCH_D')}"
            f" BB={s['BB位置']} SMA20={s['SMA20比']}"
            f" ATR14={s.get('ATR14')} OBV={s.get('OBV_trend')}"
        )
        if fund:
            line += (
                f" | 売上成長={fund.get('売上成長率')}%"
                f" PER={fund.get('PER')} ROE={fund.get('ROE')}%"
            )
        entries.append((score, line))
    entries.sort(key=lambda x: x[0], reverse=True)
    return "\n".join(line for _, line in entries)


# ──────────────────────────────────────────────
# Flow 1: ニュース → テクニカル+ファンダメンタル → 判定
# ──────────────────────────────────────────────

def pick_from_news(market: str | None = None, top_n: int = 20) -> dict:
    wl = load_watchlist(market)
    watchlist_str = "\n".join(
        f"  {row['ticker']} ({row['name']})" for _, row in wl.iterrows()
    )

    # Step1: 市況ニュース収集（株探 + YouTube）& Claude が候補銘柄を抽出
    print("  [Step1] 市況ニュースを収集中（株探・YouTube）...")
    raw_news  = fetch_market_news(max_items=45)
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

    # ニュースから抽出が top_n に満たない場合はウォッチリスト全銘柄で補完
    all_tickers = wl["ticker"].tolist()
    for t in all_tickers:
        if t not in tickers:
            tickers.append(t)
        if len(tickers) >= top_n:
            break

    print(f"  [Step1] 候補 {len(tickers)} 件: {', '.join(tickers)}")

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
{_JUDGE_FORMAT_NEWS.format(top_n=top_n)}"""

    raw = _claude(judge_prompt, max_tokens=8192)
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

def pick_from_screen(
    market: str | None = None,
    top_n: int = 20,
    cap_types: list[str] | None = None,
    min_revenue_growth: float = 0.05,
    max_per: float = 80,
) -> dict:
    """
    中小型株（デフォルト: mid/small）× 好業績 × スイング取引特化スクリーニング。

    スイング取引フィルタ（数日〜2週間の値幅狙い）:
      - RSI 25〜55（売られすぎからの回復初期、オーバーボートを除外）
      - MACD買い転換 OR RSI<35 の深売られすぎ
      - Stoch%K < 70、BB上限付近を除外
      - swing_score 上位順にソート（高いほど複合シグナル一致）

    cap_types          : デフォルト ['small','mid']。None で全規模。
    min_revenue_growth : 売上成長率下限（小数）。デフォルト 0.05 = 5%。
    max_per            : PER 上限。デフォルト 80。
    """
    if cap_types is None:
        cap_types = ["small", "mid"]

    # Step1: スクリーニング（スイング + ファンダメンタル）
    print(f"  [Step1] スイングスクリーニング中 (cap:{cap_types}, 売上成長≥{min_revenue_growth*100:.0f}%)...")
    df = screen(
        market=market,
        swing_mode=True,
        cap_types=cap_types,
        min_revenue_growth=min_revenue_growth,
        max_per=max_per,
    )

    # ファンダメンタル条件を緩和してリトライ（候補が少ない場合）
    if len(df) < 5:
        print(f"  [Step1] ヒット少（{len(df)}件）→ 売上成長条件を 0% に緩和...")
        df = screen(market=market, swing_mode=True, cap_types=cap_types, max_per=max_per)

    # さらに少なければ swing_mode を維持しつつ cap_types 拡大
    if len(df) < 5:
        print(f"  [Step1] ヒット少（{len(df)}件）→ 全規模に拡大...")
        df = screen(market=market, swing_mode=True)

    if df.empty:
        return {"error": "スクリーニング条件に合う銘柄が見つかりませんでした。"}

    # ウォッチリストで補完して top_n 確保
    wl = load_watchlist(market, cap_types)
    all_wl_tickers = load_watchlist(market)["ticker"].tolist()
    screened = df["ticker"].tolist()
    for t in all_wl_tickers:
        if t not in screened:
            screened.append(t)
        if len(screened) >= top_n:
            break

    print(f"  [Step1] {len(df)} 件ヒット（補完後 {len(screened)} 件）: {', '.join(df['ticker'].tolist())}")

    # swing_score マップ（スクリーニング結果から引き継ぐ）
    score_map = dict(zip(df["ticker"], df.get("swing_score", pd.Series(dtype=int))))

    # Step2: テクニカル + ファンダメンタル詳細
    print("  [Step2] テクニカル・ファンダメンタル分析中...")
    name_map = {**dict(zip(wl["ticker"], wl["name"])),
                **dict(zip(load_watchlist(market)["ticker"], load_watchlist(market)["name"]))}
    tech_list = []
    for t in screened:
        s = _technical_summary(t)
        if s:
            s["name"]        = name_map.get(t, t)
            s["swing_score"] = score_map.get(t, 0)
            tech_list.append(s)

    if not tech_list:
        return {"error": "テクニカルデータの取得に失敗しました。"}

    fund_map = {}
    for s in tech_list:
        fund_map[s["ticker"]] = _fundamental_data(s["ticker"])

    # Step3: 市場センチメント
    print("  [Step3] 市場センチメントを確認中...")
    ctx          = get_market_context()
    ctx_text     = market_context_text(ctx)
    perf         = load_performance_summary()
    perf_section = f"\n{perf}\n" if perf else ""

    # Step4: 最終判定（スイング特化プロンプト）
    print("  [Step4] Claude がスイング判定中...")
    tech_text = _build_swing_tech_text(tech_list, fund_map)

    judge_prompt = f"""あなたはスイングトレード専門の株式アナリストです。
【戦略】数日〜2週間での値幅取りを目的とするスイング取引に最適な銘柄を選定してください。
「業績は好調だが株価が下押しされて反転シグナルが出ている中小型株」を最重要視します。

{ctx_text}
{perf_section}
【テクニカル + ファンダメンタルデータ】
swing_score: 0〜10点のスイング総合スコア（高いほど複合シグナル一致）
評価軸（優先順）:
  ① swing_score 8〜10: MACD転換+Stochゴールデンクロス+BB下限 が一致 → 最優先
  ② swing_score 5〜7: 複数シグナルの部分一致 → 上位候補
  ③ RSI 30〜50 かつ MACD買い転換: スイング黄金ゾーン（売られすぎ解消の初動）
  ④ Stoch%K が 20以下から%Dを上抜け: 短期の強いリバウンドサイン
  ⑤ BB 下限付近 + OBV 上昇: 出来高を伴った底打ち確認
  ⑥ 業績好調（売上成長>5%、ROE>10%）で下落が一時的と判断できる銘柄を優遇
  ⑦ ATR14 が適度に大きい（値幅が出る）銘柄を優遇
{tech_text}

【ランキング判断基準】
- 1位: swing_score高 + MACD転換確認済み + 業績好調 → 今すぐエントリー候補
- 2〜5位: swing_score高め + 反転シグナル出始め → 数日以内のエントリー候補
- 6〜10位: シグナル1〜2個一致、業績は良い → 押し目待ち候補
- 下位: シグナル弱いが業績で補完 or 補完銘柄

【reason 欄に必ず含めること】
・エントリータイミングの判断（例：MACD転換済み、底打ち確認待ち、等）
・スイングの値幅目標（例：SMA20まで+8%の余地）
・損切り目安（例：直近安値 or ATR×1.5 が損切りライン）

{_JUDGE_FORMAT.format(top_n=top_n)}"""

    raw = _claude(judge_prompt, max_tokens=8192)
    rankings, summary, market_outlook = _parse_judge(raw, tech_list)

    return {
        "flow":           "スクリーニング起点",
        "market":         market or "全銘柄",
        "date":           str(date.today()),
        "rankings":       rankings,
        "summary":        summary,
        "market_outlook": market_outlook,
        "vix":            ctx.get("VIX"),
        "fear_greed":     ctx.get("FearGreed"),
    }


# ──────────────────────────────────────────────
# Flow 3: YouTube動画 → テクニカル+ファンダメンタル → 判定
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

    # Step1: YouTube動画タイトル取得 & Claude が候補銘柄を抽出
    print("  [Step1] YouTube動画タイトルを収集中...")
    yt_news = fetch_youtube_only_news(max_items=15)
    if not yt_news:
        return {"error": "YouTubeニュースの取得に失敗しました。"}

    yt_lines = []
    for n in yt_news:
        line = f"- [{n['source']}] {n['title']}"
        if n.get("summary"):
            line += f": {n['summary'][:150]}"
        yt_lines.append(line)
    yt_text = "\n".join(yt_lines)

    print(f"  [Step1] {len(yt_news)} 本の動画タイトルを取得")

    extract_prompt = f"""あなたは株式投資アナリストです。
以下のYouTube動画タイトルを読み、ウォッチリストの中から「動画で取り上げられている、または関連性が高い銘柄」を最大{top_n}件選んでください。
動画タイトルに含まれるキーワード（業種・テーマ・銘柄名・銘柄コード）との関連を重視して選定してください。

【YouTube動画タイトル一覧】
{yt_text}

【ウォッチリスト】
{watchlist_str}

回答は以下の JSON のみで返してください（説明不要）:
{{"tickers": ["7203.T", "AAPL"]}}"""

    print("  [Step1] Claude がYouTube動画から候補銘柄を抽出中...")
    raw = _claude(extract_prompt, max_tokens=512)
    data = _extract_json_obj(raw)
    yt_tickers = data.get("tickers", []) if data else []  # YouTube動画から直接抽出した銘柄

    # 不足分をウォッチリストで補完（補完銘柄を別リストで管理）
    tickers = list(yt_tickers)
    supplemented = []
    all_tickers = wl["ticker"].tolist()
    for t in all_tickers:
        if t not in tickers:
            tickers.append(t)
            supplemented.append(t)
        if len(tickers) >= top_n:
            break

    yt_ticker_set = set(yt_tickers)
    print(f"  [Step1] YouTube言及: {len(yt_tickers)} 件, 補完: {len(supplemented)} 件")
    print(f"  [Step1] 候補計 {len(tickers)} 件: {', '.join(tickers)}")

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

    # YouTube言及銘柄と補完銘柄を明示
    yt_mentioned_names = [
        f"{t}({wl[wl['ticker']==t]['name'].values[0] if len(wl[wl['ticker']==t]) else t})"
        for t in yt_tickers
    ]
    supplemented_names = [
        f"{t}({wl[wl['ticker']==t]['name'].values[0] if len(wl[wl['ticker']==t]) else t})"
        for t in supplemented
    ]

    judge_prompt = f"""あなたは株式投資アナリストです。
【戦略】以下のYouTube動画（投資系チャンネル）で取り上げられているテーマ・銘柄をもとに、
テクニカル・ファンダメンタルを総合して投資推奨ランキングを作成してください。
スイング取引（数日〜2週間）を前提とします。

{ctx_text}
{perf_section}
【参考にしたYouTube動画タイトル】
{yt_text}

【銘柄の区分】
■ YouTube動画で言及・関連する銘柄（news_basis にYouTube情報を記載してよい）:
  {', '.join(yt_mentioned_names) if yt_mentioned_names else 'なし'}

■ ウォッチリストから補完した銘柄（YouTube動画での言及なし。news_basis は空欄にすること）:
  {', '.join(supplemented_names) if supplemented_names else 'なし'}

【テクニカル + ファンダメンタルデータ】
{tech_text}

【評価の優先順位】
1. YouTube動画で明示的に取り上げられた銘柄やテーマとの関連性
2. テクニカル指標（RSI売られすぎ、MACD買い転換、Stoch過売圏、BB下限）
3. ファンダメンタル（売上成長率、ROE、PER割安）
4. 市場センチメント（VIX・Fear&Greed）との整合性

【news_basis の記載ルール（厳守）】
・YouTube言及銘柄のみ: どの動画タイトルのどのテーマと関連するかを具体的に記載
・補完銘柄: news_basis は必ず空欄（""）にすること。YouTube情報を推測・捏造しないこと

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
