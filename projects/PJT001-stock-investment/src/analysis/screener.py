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
            "revenue_growth":    info.get("revenueGrowth"),       # 小数 e.g. 0.12
            "earnings_growth":   info.get("earningsGrowth"),      # 小数 e.g. 0.08
            "trailing_pe":       info.get("trailingPE"),
            "forward_pe":        info.get("forwardPE"),
            "operating_margins": info.get("operatingMargins"),
            "market_cap":        info.get("marketCap"),
        }
    except Exception:
        return {}


def screen(
    tickers: list[str] | None = None,
    market: str | None = None,
    min_rsi: float = 0,
    max_rsi: float = 100,
    macd_signal: str | None = None,   # 'buy' / 'sell'
    below_sma20: bool = False,
    above_sma20: bool = False,
    cap_types: list[str] | None = None,           # e.g. ['small', 'mid']
    min_revenue_growth: float | None = None,      # e.g. 0.05 (5%)
    max_per: float | None = None,                 # e.g. 60
    require_positive_earnings: bool = False,      # 利益成長が黒字
) -> pd.DataFrame:
    """
    複数条件でスクリーニングする。

    tickers を省略すると watchlist.csv が対象（cap_types で絞り込み可能）。
    market='JP'/'US' で絞り込み可能。
    fundamental フィルタ（min_revenue_growth 等）は技術指標通過後に適用。
    """
    use_fundamentals = (
        min_revenue_growth is not None
        or max_per is not None
        or require_positive_earnings
    )

    if tickers is None:
        wl = load_watchlist(market, cap_types)
        tickers = wl["ticker"].tolist()
        names    = dict(zip(wl["ticker"], wl["name"]))
        cap_map  = dict(zip(wl["ticker"], wl["cap_type"]))
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

            close    = float(r["Close"])
            rsi      = float(r["RSI14"])
            sma20    = float(r["SMA20"])    if not pd.isna(r["SMA20"])    else None
            macd     = float(r["MACD"])
            macd_sig = float(r["MACD_signal"])
            bb_upper = float(r["BB_upper"]) if not pd.isna(r["BB_upper"]) else None
            bb_lower = float(r["BB_lower"]) if not pd.isna(r["BB_lower"]) else None

            # ── テクニカルフィルタ ──
            if not (min_rsi <= rsi <= max_rsi):
                continue
            if macd_signal == "buy"  and not (macd > macd_sig):
                continue
            if macd_signal == "sell" and not (macd < macd_sig):
                continue
            if below_sma20 and sma20 and not (close < sma20):
                continue
            if above_sma20 and sma20 and not (close > sma20):
                continue

            # ── ファンダメンタルフィルタ（テクニカル通過後のみ実行） ──
            fund = {}
            if use_fundamentals:
                fund = _fetch_fundamentals(ticker)
                rev_gr = fund.get("revenue_growth")
                earn_gr = fund.get("earnings_growth")
                per     = fund.get("trailing_pe") or fund.get("forward_pe")

                if min_revenue_growth is not None and (rev_gr is None or rev_gr < min_revenue_growth):
                    continue
                if require_positive_earnings and (earn_gr is None or earn_gr <= 0):
                    continue
                if max_per is not None and per is not None and per > max_per:
                    continue

            results.append({
                "ticker":     ticker,
                "name":       names.get(ticker, ticker),
                "cap_type":   cap_map.get(ticker, ""),
                "終値":       round(close, 2),
                "RSI14":      round(rsi, 1),
                "SMA20":      round(sma20, 2)    if sma20    else None,
                "MACD方向":   "↑買い" if macd > macd_sig else "↓売り",
                "BB上限":     round(bb_upper, 2) if bb_upper else None,
                "BB下限":     round(bb_lower, 2) if bb_lower else None,
                "売上成長率%": round(fund["revenue_growth"] * 100, 1)
                               if fund.get("revenue_growth") is not None else None,
                "PER":        round(fund.get("trailing_pe") or fund.get("forward_pe"), 1)
                               if (fund.get("trailing_pe") or fund.get("forward_pe")) else None,
            })
        except Exception:
            continue

    if not results:
        return pd.DataFrame()
    return pd.DataFrame(results).sort_values("RSI14").reset_index(drop=True)
