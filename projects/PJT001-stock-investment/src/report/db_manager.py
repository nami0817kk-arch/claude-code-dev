"""
推奨履歴データベース管理 (SQLite)

data/db/investment.db に推奨記録を蓄積し、
実行ごとに現在価格・損益率を自動更新する。
"""
import sqlite3
from datetime import datetime, date
from pathlib import Path
import yfinance as yf
import pandas as pd

DB_PATH = Path(__file__).parent.parent.parent / "data" / "db" / "investment.db"

CREATE_TABLE = """
CREATE TABLE IF NOT EXISTS recommendations (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    推奨日       TEXT NOT NULL,
    推奨時刻     TEXT NOT NULL,
    フロー       TEXT,
    銘柄コード   TEXT NOT NULL,
    銘柄名       TEXT,
    推奨順位     INTEGER,
    推奨度       TEXT,
    推奨時終値   REAL,
    現在価格     REAL,
    損益率       REAL,
    最終更新     TEXT,
    RSI14        REAL,
    MACD方向     TEXT,
    SMA20比      TEXT,
    BB位置       TEXT
)
"""


def _connect() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(DB_PATH)
    con.execute(CREATE_TABLE)
    con.commit()
    return con


def save_recommendations(result: dict, _wb=None):
    """推奨結果を DB に INSERT する（_wb 引数は互換性のため無視）"""
    now = datetime.now()
    rows = []
    for item in result.get("rankings", []):
        rows.append((
            str(date.today()),
            now.strftime("%H:%M"),
            result.get("flow", ""),
            item.get("ticker", ""),
            item.get("name", ""),
            item.get("rank"),
            item.get("stars", ""),
            item.get("close"),
            None,   # 現在価格
            None,   # 損益率
            None,   # 最終更新
            item.get("RSI14"),
            item.get("MACD方向", ""),
            item.get("SMA20比", ""),
            item.get("BB位置", ""),
        ))

    with _connect() as con:
        con.executemany("""
            INSERT INTO recommendations
              (推奨日, 推奨時刻, フロー, 銘柄コード, 銘柄名,
               推奨順位, 推奨度, 推奨時終値,
               現在価格, 損益率, 最終更新,
               RSI14, MACD方向, SMA20比, BB位置)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """, rows)


def update_prices(_wb=None):
    """DB 内の全レコードの現在価格・損益率を一括更新する"""
    with _connect() as con:
        tickers = [r[0] for r in con.execute(
            "SELECT DISTINCT 銘柄コード FROM recommendations WHERE 推奨時終値 IS NOT NULL"
        ).fetchall()]

    if not tickers:
        return

    prices = {}
    for t in tickers:
        try:
            prices[t] = round(float(yf.Ticker(t).fast_info.last_price), 2)
        except Exception:
            pass

    today = str(date.today())
    with _connect() as con:
        for ticker, current in prices.items():
            con.execute("""
                UPDATE recommendations
                SET 現在価格 = ?,
                    損益率   = CASE
                                 WHEN 推奨時終値 IS NOT NULL AND 推奨時終値 > 0
                                 THEN ROUND((? - 推奨時終値) / 推奨時終値 * 100, 2)
                                 ELSE NULL
                               END,
                    最終更新 = ?
                WHERE 銘柄コード = ?
            """, (current, current, today, ticker))


def load_performance_summary() -> str:
    """
    過去推奨の実績サマリーを文字列で返す。
    Claude のプロンプトに組み込んで推奨精度を向上させる。
    """
    if not DB_PATH.exists():
        return ""
    try:
        with _connect() as con:
            df = pd.read_sql_query(
                "SELECT * FROM recommendations WHERE 損益率 IS NOT NULL", con
            )

        if df.empty:
            return ""

        df["損益率"] = pd.to_numeric(df["損益率"], errors="coerce")
        df["RSI14"]  = pd.to_numeric(df["RSI14"],  errors="coerce")

        total = len(df)
        wins  = (df["損益率"] > 0).sum()
        avg   = df["損益率"].mean()

        lines = [f"【過去推奨の実績】（{total}件 / 損益更新済み）"]
        lines.append(
            f"  全体: 勝率 {wins}/{total} ({wins/total*100:.0f}%)  平均損益 {avg:+.1f}%"
        )

        for macd in ["買い", "売り"]:
            sub = df[df["MACD方向"] == macd]
            if len(sub) >= 2:
                lines.append(f"  MACD={macd}: 平均 {sub['損益率'].mean():+.1f}% ({len(sub)}件)")

        for label, cond in [
            ("RSI<35",    df["RSI14"] < 35),
            ("RSI35-50", (df["RSI14"] >= 35) & (df["RSI14"] < 50)),
        ]:
            sub = df[cond]
            if len(sub) >= 2:
                lines.append(f"  {label}: 平均 {sub['損益率'].mean():+.1f}% ({len(sub)}件)")

        for bb in ["下限付近", "中央付近", "上限付近"]:
            sub = df[df["BB位置"] == bb]
            if len(sub) >= 2:
                lines.append(f"  BB={bb}: 平均 {sub['損益率'].mean():+.1f}% ({len(sub)}件)")

        return "\n".join(lines)

    except Exception:
        return ""


def query(sql: str) -> pd.DataFrame:
    """任意のSELECT文を実行して DataFrame を返す（デバッグ用）"""
    with _connect() as con:
        return pd.read_sql_query(sql, con)
