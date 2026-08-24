"""
当日の値上がり率ランキングを kabutan.jp から取得する。

PJT003-quality-gainer-tracker の src/data/ranking_fetcher.py の
_fetch_kabutan() 系ロジックを、当日取得のみに絞って移植したもの。
kabudragon（過去日backfill用）は v1 では不要なため含めない。
"""
import re
import time
from datetime import date

import requests
from bs4 import BeautifulSoup
import pandas as pd

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "ja,en;q=0.9",
}

_KABUTAN_URL = "https://kabutan.jp/warning/?mode=2_1&market={market}"
_KABUTAN_MARKETS = [1, 2, 3]  # プライム, スタンダード, グロース


def _fetch_market_html(market: int, retries: int = 3) -> str | None:
    url = _KABUTAN_URL.format(market=market)
    for attempt in range(retries):
        try:
            resp = requests.get(url, headers=_HEADERS, timeout=30)
            resp.raise_for_status()
            return resp.text
        except Exception as e:
            if attempt < retries - 1:
                time.sleep(3 * (attempt + 1))
            else:
                print(f"  [WARN] kabutan market={market} 取得失敗: {e}")
    return None


def _parse_market_html(html: str) -> pd.DataFrame:
    """
    kabutan の stock_table を解析する。
    市場により列数が異なる:
      13列 (プライム): code[0] name[1] market[2] _ _ close[5] _ 前日比[7] gain%[8] vol[9]
      12列 (スタンダード/グロース): code[0] market[1] _ _ close[4] _ 前日比[6] gain%[7] vol[8]
    """
    soup = BeautifulSoup(html, "lxml")
    tbl = soup.find("table", class_="stock_table")
    if tbl is None:
        return pd.DataFrame()

    rows = []
    for tr in tbl.find_all("tr"):
        tds = tr.find_all("td")
        n = len(tds)
        if n < 9:
            continue
        texts = [td.get_text(strip=True) for td in tds]

        try:
            code = texts[0]
            if not re.match(r"^\d{4}$", code):
                continue

            if n >= 13:
                name = texts[1]
                close = texts[5].replace(",", "")
                gain_s = texts[8]
                vol_s = texts[9].replace(",", "")
            else:
                name = code
                close = texts[4].replace(",", "")
                gain_s = texts[7]
                vol_s = texts[8].replace(",", "")

            gain = float(re.sub(r"[^0-9.\-]", "", gain_s))
            if gain <= 0:
                continue

            rows.append({
                "ticker": code + ".T",
                "code": code,
                "name": name,
                "close": float(close) if close.replace(".", "").isdigit() else None,
                "gain_pct": gain,
                "volume": int(vol_s) if vol_s.isdigit() else None,
            })
        except (IndexError, ValueError):
            continue

    return pd.DataFrame(rows) if rows else pd.DataFrame()


def _fetch_name(code: str) -> str:
    """kabutan の個別ページから日本語銘柄名を取得する。"""
    try:
        url = f"https://kabutan.jp/stock/?code={code}"
        resp = requests.get(url, headers=_HEADERS, timeout=10)
        soup = BeautifulSoup(resp.text, "lxml")
        h1 = soup.find("h1")
        if h1:
            return h1.get_text(strip=True).split("(")[0].strip()
    except Exception:
        pass
    return code


def _fill_names(df: pd.DataFrame) -> pd.DataFrame:
    """銘柄名がコード（数字4桁）になっている行を kabutan 個別ページで補完する。"""
    needs_name = df["name"].str.match(r"^\d{4}$")
    for idx, row in df[needs_name].iterrows():
        df.at[idx, "name"] = _fetch_name(row["code"])
        time.sleep(0.5)
    return df


def fetch_gainers(top_n: int = 30) -> pd.DataFrame:
    """
    kabutan.jp の3市場（プライム/スタンダード/グロース）を集約し、
    値上がり率上位 top_n 件を返す。

    Returns:
        DataFrame: ticker, code, name, close, gain_pct, volume, rec_date
    """
    print("  値上がりランキング取得中（kabutan.jp）...")
    all_rows = []
    for market in _KABUTAN_MARKETS:
        html = _fetch_market_html(market)
        if html:
            df_m = _parse_market_html(html)
            if not df_m.empty:
                all_rows.append(df_m)
        time.sleep(1)

    if not all_rows:
        return pd.DataFrame()

    df = (
        pd.concat(all_rows, ignore_index=True)
        .drop_duplicates("ticker")
        .sort_values("gain_pct", ascending=False)
        .head(top_n)
        .reset_index(drop=True)
    )

    df = _fill_names(df)
    df["rec_date"] = str(date.today())
    df.insert(0, "rank", range(1, len(df) + 1))
    return df
