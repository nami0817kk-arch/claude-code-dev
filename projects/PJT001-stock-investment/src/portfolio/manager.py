import pandas as pd
from pathlib import Path
from datetime import date

PORTFOLIO_FILE = Path(__file__).parent.parent.parent / "data" / "portfolio.csv"

COLUMNS = ["ticker", "name", "shares", "buy_price", "buy_date", "currency"]


def load() -> pd.DataFrame:
    if PORTFOLIO_FILE.exists():
        return pd.read_csv(PORTFOLIO_FILE)
    return pd.DataFrame(columns=COLUMNS)


def save(df: pd.DataFrame) -> None:
    PORTFOLIO_FILE.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(PORTFOLIO_FILE, index=False)


def add(ticker: str, name: str, shares: float, buy_price: float,
        currency: str = "JPY", buy_date: str | None = None) -> pd.DataFrame:
    df = load()
    new_row = {
        "ticker":    ticker,
        "name":      name,
        "shares":    shares,
        "buy_price": buy_price,
        "buy_date":  buy_date or str(date.today()),
        "currency":  currency,
    }
    df = pd.concat([df, pd.DataFrame([new_row])], ignore_index=True)
    save(df)
    return df


def summary() -> pd.DataFrame:
    """保有銘柄の現在価格・損益を計算して返す"""
    import yfinance as yf

    df = load()
    if df.empty:
        return df

    records = []
    for _, row in df.iterrows():
        try:
            info = yf.Ticker(row["ticker"]).fast_info
            current = info.last_price
            cost    = row["shares"] * row["buy_price"]
            value   = row["shares"] * current
            pnl     = value - cost
            pnl_pct = pnl / cost * 100
            records.append({**row.to_dict(),
                             "current_price": round(current, 2),
                             "cost":          round(cost, 2),
                             "value":         round(value, 2),
                             "pnl":           round(pnl, 2),
                             "pnl_%":         round(pnl_pct, 2)})
        except Exception:
            records.append(row.to_dict())

    return pd.DataFrame(records)
