import pandas as pd
import ta


def add_indicators(df: pd.DataFrame) -> pd.DataFrame:
    """主要テクニカル指標を追加する"""
    close = df["Close"]

    df["SMA20"]  = ta.trend.sma_indicator(close, window=20)
    df["SMA75"]  = ta.trend.sma_indicator(close, window=75)
    df["RSI14"]  = ta.momentum.rsi(close, window=14)
    df["MACD"]   = ta.trend.macd(close)
    df["MACD_signal"] = ta.trend.macd_signal(close)

    bb = ta.volatility.BollingerBands(close)
    df["BB_upper"] = bb.bollinger_hband()
    df["BB_lower"] = bb.bollinger_lband()

    return df
