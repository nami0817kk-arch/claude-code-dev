import yfinance as yf
import pandas as pd
from typing import Sequence


def screen(tickers: Sequence[str], min_rsi: float = 30, max_rsi: float = 70) -> pd.DataFrame:
    """
    RSI が min_rsi〜max_rsi の範囲にある銘柄をスクリーニングする。
    tickers: ['7203.T', 'AAPL', ...] のようなリスト
    """
    from src.data.fetcher import fetch_price
    from src.analysis.indicators import add_indicators

    results = []
    for ticker in tickers:
        try:
            df = fetch_price(ticker, period="3mo")
            df = add_indicators(df)
            latest = df.iloc[-1]
            rsi = latest.get("RSI14")
            if rsi is not None and min_rsi <= rsi <= max_rsi:
                results.append({
                    "ticker": ticker,
                    "close":  round(float(latest["Close"]), 2),
                    "RSI14":  round(float(rsi), 1),
                    "SMA20":  round(float(latest["SMA20"]), 2),
                })
        except Exception:
            continue

    return pd.DataFrame(results)
