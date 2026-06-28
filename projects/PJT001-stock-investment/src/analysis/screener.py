import pandas as pd
import yfinance as yf
from pathlib import Path
from src.data.fetcher import fetch_price
from src.analysis.indicators import add_indicators

WATCHLIST = Path(__file__).parent.parent.parent / "data" / "watchlist.csv"


def load_watchlist(market: str | None = None, cap_types: list[str] | None = None) -> pd.DataFrame:
    """watchlist.csv を読み込む。market='JP'/'US'、cap_types=['small','mid'] で絞り込み可能"""
    df = pd.read_csv(WATCHLIST)
    if market:
        df = df[df["market"] == market.upper()]
    if cap_types:
        df = df[df["cap_type"].isin(cap_types)]
    return df.drop_duplicates(subset=["ticker"]).reset_index(drop=True)


def _fetch_fundamentals(ticker: str) -> dict:
    """yfinance から基本ファンダメンタル指標を取得する（slow）"""
    try:
        info = yf.Ticker(ticker).info
        return {
            "revenue_growth":    info.get("revenueGrowth"),
            "earnings_growth":   info.get("earningsGrowth"),
            "trailing_pe":       info.get("trailingPE"),
            "forward_pe":        info.get("forwardPE"),
            "operating_margins": info.get("operatingMargins"),
            "market_cap":        info.get("marketCap"),
        }
    except Exception:
        return {}


def _swing_score(rsi, macd, macd_sig, stoch_k, stoch_d, bb_upper, bb_lower, close, obv_trend) -> int:
    """スイング取引の優位性スコア（0〜10点）を計算する。高いほど良いエントリー機会。"""
    score = 0

    # RSI: 30〜50 がスイング黄金ゾーン(+2)、25〜30 の深売られすぎ(+1)
    if rsi is not None:
        if 30 <= rsi <= 50:
            score += 2
        elif rsi < 30:
            score += 1

    # MACD 買い転換 (+2)
    if macd is not None and macd_sig is not None and macd > macd_sig:
        score += 2

    # Stoch %K が売られすぎ圏(<25)で %D をゴールデンクロス(+3)、または<25 のみ(+1)
    if stoch_k is not None:
        if stoch_k < 25:
            if stoch_d is not None and stoch_k > stoch_d:
                score += 3
            else:
                score += 1
        elif stoch_k < 40 and stoch_d is not None and stoch_k > stoch_d:
            score += 1

    # BB 下限付近(下側1/3)で反発狙い(+2)
    if bb_upper is not None and bb_lower is not None and close is not None:
        band = bb_upper - bb_lower
        if band > 0:
            pos = (close - bb_lower) / band
            if pos <= 0.33:
                score += 2

    # OBV 上昇（出来高を伴う資金流入）(+1)
    if obv_trend == "上昇":
        score += 1

    return min(score, 10)


def screen(
    tickers: list[str] | None = None,
    market: str | None = None,
    min_rsi: float = 0,
    max_rsi: float = 100,
    macd_signal: str | None = None,   # 'buy' / 'sell'
    below_sma20: bool = False,
    above_sma20: bool = False,
    cap_types: list[str] | None = None,
    min_revenue_growth: float | None = None,
    max_per: float | None = None,
    require_positive_earnings: bool = False,
    swing_mode: bool = False,         # スイング取引に特化したフィルタ
) -> pd.DataFrame:
    """
    複数条件でスクリーニングする。

    swing_mode=True の場合:
      - RSI 25〜55 (売られすぎからの回復初期〜中立圏)
      - MACD買いシグナル OR RSI<35 の深売られすぎ のどちらかが必要
      - Stoch %K < 70 (過買いを除外)
      - BB 上限付近(上側1/4)を除外 (エントリー遅い)
      - swing_score 列を追加(0〜10 点)
    """
    use_fundamentals = (
        min_revenue_growth is not None
        or max_per is not None
        or require_positive_earnings
    )

    if tickers is None:
        wl = load_watchlist(market, cap_types)
        tickers = wl["ticker"].tolist()
        names   = dict(zip(wl["ticker"], wl["name"]))
        cap_map = dict(zip(wl["ticker"], wl["cap_type"]))
    else:
        names   = {t: t for t in tickers}
        cap_map = {}

    results = []
    for ticker in tickers:
        try:
            df = fetch_price(ticker, period="3mo")
            if df.empty:
                continue
            df = add_indicators(df)
            r  = df.iloc[-1]

            def _f(col):
                v = r.get(col) if hasattr(r, "get") else (r[col] if col in r.index else None)
                return float(v) if v is not None and not pd.isna(v) else None

            close    = _f("Close")
            rsi      = _f("RSI14")
            sma20    = _f("SMA20")
            macd     = _f("MACD")
            macd_sig = _f("MACD_signal")
            bb_upper = _f("BB_upper")
            bb_lower = _f("BB_lower")
            stoch_k  = _f("STOCH_K")
            stoch_d  = _f("STOCH_D")

            # OBV トレンド（直近5日）
            obv_trend = "不明"
            if "OBV" in df.columns and len(df) >= 5:
                obv_recent = df["OBV"].dropna().tail(5)
                if len(obv_recent) >= 2:
                    obv_trend = "上昇" if obv_recent.iloc[-1] > obv_recent.iloc[0] else "下降"

            # ── テクニカルフィルタ ──
            if rsi is None:
                continue
            if not (min_rsi <= rsi <= max_rsi):
                continue
            if macd_signal == "buy"  and not (macd and macd_sig and macd > macd_sig):
                continue
            if macd_signal == "sell" and not (macd and macd_sig and macd < macd_sig):
                continue
            if below_sma20 and sma20 and close and not (close < sma20):
                continue
            if above_sma20 and sma20 and close and not (close > sma20):
                continue

            # ── スイングモード専用フィルタ ──
            if swing_mode:
                # RSI: 25〜55 のみ通過
                if not (25 <= rsi <= 55):
                    continue
                # MACD買いシグナル OR 深い売られすぎ(RSI<35) のどちらかが必要
                macd_buy = macd is not None and macd_sig is not None and macd > macd_sig
                if not (macd_buy or rsi < 35):
                    continue
                # Stoch %K 過買い(>70)を除外
                if stoch_k is not None and stoch_k > 70:
                    continue
                # BB 上限付近(上側1/4)を除外 — エントリーが遅い
                if bb_upper and bb_lower and close:
                    band = bb_upper - bb_lower
                    if band > 0 and (close - bb_lower) / band > 0.75:
                        continue

            # ── ファンダメンタルフィルタ ──
            fund = {}
            if use_fundamentals:
                fund = _fetch_fundamentals(ticker)
                rev_gr  = fund.get("revenue_growth")
                earn_gr = fund.get("earnings_growth")
                per     = fund.get("trailing_pe") or fund.get("forward_pe")

                if min_revenue_growth is not None and (rev_gr is None or rev_gr < min_revenue_growth):
                    continue
                if require_positive_earnings and (earn_gr is None or earn_gr <= 0):
                    continue
                if max_per is not None and per is not None and per > max_per:
                    continue

            # スイングスコア計算
            sw_score = _swing_score(rsi, macd, macd_sig, stoch_k, stoch_d,
                                    bb_upper, bb_lower, close, obv_trend)

            results.append({
                "ticker":      ticker,
                "name":        names.get(ticker, ticker),
                "cap_type":    cap_map.get(ticker, ""),
                "終値":        round(close, 2)    if close    else None,
                "RSI14":       round(rsi, 1),
                "SMA20":       round(sma20, 2)    if sma20    else None,
                "MACD方向":    "↑買い" if (macd and macd_sig and macd > macd_sig) else "↓売り",
                "Stoch%K":     round(stoch_k, 1) if stoch_k  else None,
                "Stoch%D":     round(stoch_d, 1) if stoch_d  else None,
                "BB上限":      round(bb_upper, 2) if bb_upper else None,
                "BB下限":      round(bb_lower, 2) if bb_lower else None,
                "OBV":         obv_trend,
                "swing_score": sw_score,
                "売上成長率%": round(fund["revenue_growth"] * 100, 1)
                               if fund.get("revenue_growth") is not None else None,
                "PER":         round(fund.get("trailing_pe") or fund.get("forward_pe"), 1)
                               if (fund.get("trailing_pe") or fund.get("forward_pe")) else None,
            })
        except Exception:
            continue

    if not results:
        return pd.DataFrame()

    df_result = pd.DataFrame(results)
    # スイングモードは swing_score 降順、それ以外は RSI 昇順
    sort_col = "swing_score" if swing_mode else "RSI14"
    asc      = False if swing_mode else True
    return df_result.sort_values(sort_col, ascending=asc).reset_index(drop=True)
