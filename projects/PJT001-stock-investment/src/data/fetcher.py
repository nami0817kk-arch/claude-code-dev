import yfinance as yf
import pandas as pd
from pathlib import Path

DATA_DIR = Path(__file__).parent.parent.parent / "data" / "raw"


def fetch_price(ticker: str, period: str = "1y", interval: str = "1d") -> pd.DataFrame:
    """株価データを取得する。日本株は ticker に '.T' を付ける（例: 7203.T）"""
    df = yf.download(ticker, period=period, interval=interval, auto_adjust=True, progress=False)
    df.columns = df.columns.droplevel(1) if isinstance(df.columns, pd.MultiIndex) else df.columns
    return df


def fetch_info(ticker: str) -> dict:
    """銘柄の基本情報を取得する"""
    t = yf.Ticker(ticker)
    return t.info


def save_price(df: pd.DataFrame, ticker: str) -> Path:
    """取得した株価データを CSV に保存する"""
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    path = DATA_DIR / f"{ticker.replace('.', '_')}.csv"
    df.to_csv(path)
    return path
