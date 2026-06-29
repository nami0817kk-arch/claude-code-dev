"""
推奨履歴データベース管理 (Microsoft Access .accdb)

data/db/investment.accdb に推奨記録を蓄積する。
Access から直接ファイルを開いて確認できる。
"""
import pyodbc
from datetime import datetime, date
from pathlib import Path
import yfinance as yf
import pandas as pd

DB_PATH = Path(__file__).parent.parent.parent / "data" / "db" / "investment.accdb"

_CREATE_TABLE = """
CREATE TABLE recommendations (
    id           COUNTER PRIMARY KEY,
    [推奨日]     TEXT(20),
    [推奨時刻]   TEXT(10),
    [フロー]     TEXT(50),
    [銘柄コード] TEXT(20),
    [銘柄名]     TEXT(100),
    [推奨順位]   INTEGER,
    [推奨度]     TEXT(20),
    [推奨時終値] DOUBLE,
    [現在価格]   DOUBLE,
    [損益率]     DOUBLE,
    [最終更新]   TEXT(20),
    [RSI14]      DOUBLE,
    [MACD方向]   TEXT(10),
    [SMA20比]    TEXT(10),
    [BB位置]     TEXT(20)
)
"""


def _conn_str() -> str:
    return (
        r"Driver={Microsoft Access Driver (*.mdb, *.accdb)};"
        f"DBQ={DB_PATH};"
    )


def _create_db():
    """新規 .accdb ファイルを ADOX で作成してテーブルを初期化する"""
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    import win32com.client
    catalog = win32com.client.Dispatch("ADOX.Catalog")
    catalog.Create(
        f"Provider=Microsoft.ACE.OLEDB.12.0;Data Source={DB_PATH};"
    )
    del catalog
    con = pyodbc.connect(_conn_str(), autocommit=True)
    con.execute(_CREATE_TABLE)
    con.close()


def _connect() -> pyodbc.Connection:
    if not DB_PATH.exists():
        _create_db()
    return pyodbc.connect(_conn_str())


def save_recommendations(result: dict, _wb=None):
    """推奨結果を DB に INSERT する"""
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
            None,
            None,
            None,
            item.get("RSI14"),
            item.get("MACD方向", ""),
            item.get("SMA20比", ""),
            item.get("BB位置", ""),
        ))

    sql = """
        INSERT INTO recommendations
          ([推奨日],[推奨時刻],[フロー],[銘柄コード],[銘柄名],
           [推奨順位],[推奨度],[推奨時終値],
           [現在価格],[損益率],[最終更新],
           [RSI14],[MACD方向],[SMA20比],[BB位置])
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
    """
    if not rows:
        return
    with _connect() as con:
        cur = con.cursor()
        cur.executemany(sql, rows)
        con.commit()


def update_prices(_wb=None):
    """DB 内の全レコードの現在価格・損益率を一括更新する"""
    con = _connect()
    cur = con.cursor()
    cur.execute("SELECT DISTINCT [銘柄コード] FROM recommendations WHERE [推奨時終値] IS NOT NULL")
    tickers = [r[0] for r in cur.fetchall()]
    con.close()

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
        cur = con.cursor()
        for ticker, current in prices.items():
            cur.execute("""
                UPDATE recommendations
                SET [現在価格] = ?,
                    [損益率]   = IIF([推奨時終値] > 0,
                                    ROUND((? - [推奨時終値]) / [推奨時終値] * 100, 2),
                                    NULL),
                    [最終更新] = ?
                WHERE [銘柄コード] = ?
            """, (current, current, today, ticker))
        con.commit()


def load_performance_summary() -> str:
    """
    過去推奨の実績サマリーを文字列で返す。
    Claude プロンプトに組み込んで推奨精度を向上させる。
    """
    if not DB_PATH.exists():
        return ""
    try:
        con = _connect()
        df = pd.read_sql(
            "SELECT * FROM recommendations WHERE [損益率] IS NOT NULL", con
        )
        con.close()

        if df.empty:
            return ""

        df["損益率"] = pd.to_numeric(df["損益率"], errors="coerce")
        df["RSI14"]  = pd.to_numeric(df["RSI14"],  errors="coerce")

        total = len(df)
        wins  = (df["損益率"] > 0).sum()
        avg   = df["損益率"].mean()

        lines = [f"【過去推奨の実績】（{total}件）"]
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
    """任意の SELECT を実行して DataFrame を返す（デバッグ用）"""
    con = _connect()
    df  = pd.read_sql(sql, con)
    con.close()
    return df
