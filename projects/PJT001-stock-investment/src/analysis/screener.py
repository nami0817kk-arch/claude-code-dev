import pandas as pd
from pathlib import Path
from src.data.fetcher import fetch_price
from src.analysis.indicators import add_indicators

WATCHLIST = Path(__file__).parent.parent.parent / "data" / "watchlist.csv"


def load_watchlist(market: str | None = None) -> pd.DataFrame:
    """watchlist.csv を読み込む。market='JP'/'US' で絞り込み可能"""
    df = pd.read_csv(WATCHLIST)
    if market:
        df = df[df["market"] == market.upper()]
    return df


def screen(
    tickers: list[str] | None = None,
    market: str | None = None,
    min_rsi: float = 0,
    max_rsi: float = 100,
    macd_signal: str | None = None,  # 'buy' / 'sell'
    below_sma20: bool = False,        # 終値が SMA20 を下回っている
    above_sma20: bool = False,        # 終値が SMA20 を上回っている
) -> pd.DataFrame:
    """
    複数条件でスクリーニングする。

    tickers を省略すると watchlist.csv 全銘柄が対象。
    market='JP' / 'US' で絞り込み可能。
    """
    if tickers is None:
        wl = load_watchlist(market)
        tickers = wl["ticker"].tolist()
        names   = dict(zip(wl["ticker"], wl["name"]))
    else:
        names = {t: t for t in tickers}

    results = []
    for ticker in tickers:
        try:
            df = fetch_price(ticker, period="3mo")
            if df.empty:
                continue
            df = add_indicators(df)
            r  = df.iloc[-1]

            close     = float(r["Close"])
            rsi       = float(r["RSI14"])
            sma20     = float(r["SMA20"]) if not pd.isna(r["SMA20"]) else None
            macd      = float(r["MACD"])
            macd_sig  = float(r["MACD_signal"])
            bb_upper  = float(r["BB_upper"]) if not pd.isna(r["BB_upper"]) else None
            bb_lower  = float(r["BB_lower"]) if not pd.isna(r["BB_lower"]) else None

            # --- フィルタ ---
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

            results.append({
                "ticker":   ticker,
                "name":     names.get(ticker, ticker),
                "終値":     round(close, 2),
                "RSI14":    round(rsi, 1),
                "SMA20":    round(sma20, 2) if sma20 else None,
                "MACD方向": "↑買い" if macd > macd_sig else "↓売り",
                "BB上限":   round(bb_upper, 2) if bb_upper else None,
                "BB下限":   round(bb_lower, 2) if bb_lower else None,
            })
        except Exception:
            continue

    if not results:
        return pd.DataFrame()
    return pd.DataFrame(results).sort_values("RSI14").reset_index(drop=True)
