from pathlib import Path
from typing import NamedTuple

import pandas as pd
import yfinance as yf
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


class Indicators(NamedTuple):
    """最新行から取り出した指標一式。並び順は screen() の展開に合わせている。"""

    close: float | None
    rsi: float | None
    sma20: float | None
    macd: float | None
    macd_sig: float | None
    bb_upper: float | None
    bb_lower: float | None
    stoch_k: float | None
    stoch_d: float | None
    obv_trend: str


def _latest_indicators(df: pd.DataFrame) -> Indicators:
    """指標付きの価格データから、最新行の値と OBV トレンドを取り出す。"""
    r = df.iloc[-1]

    def _f(col):
        v = r.get(col) if hasattr(r, "get") else (r[col] if col in r.index else None)
        return float(v) if v is not None and not pd.isna(v) else None

    # OBV トレンド（直近5日）
    obv_trend = "不明"
    if "OBV" in df.columns and len(df) >= 5:
        obv_recent = df["OBV"].dropna().tail(5)
        if len(obv_recent) >= 2:
            obv_trend = "上昇" if obv_recent.iloc[-1] > obv_recent.iloc[0] else "下降"

    return Indicators(
        close=_f("Close"), rsi=_f("RSI14"), sma20=_f("SMA20"),
        macd=_f("MACD"), macd_sig=_f("MACD_signal"),
        bb_upper=_f("BB_upper"), bb_lower=_f("BB_lower"),
        stoch_k=_f("STOCH_K"), stoch_d=_f("STOCH_D"),
        obv_trend=obv_trend,
    )


def _build_row(ticker: str, name: str, cap_type: str,
               ind: Indicators, sw_score: int, fund: dict) -> dict:
    """スクリーニング結果1行分の表示用データを組み立てる。"""
    per = fund.get("trailing_pe") or fund.get("forward_pe")
    macd_up = ind.macd and ind.macd_sig and ind.macd > ind.macd_sig
    return {
        "ticker":      ticker,
        "name":        name,
        "cap_type":    cap_type,
        "終値":        round(ind.close, 2)    if ind.close    else None,
        "RSI14":       round(ind.rsi, 1),
        "SMA20":       round(ind.sma20, 2)    if ind.sma20    else None,
        "MACD方向":    "↑買い" if macd_up else "↓売り",
        "Stoch%K":     round(ind.stoch_k, 1) if ind.stoch_k  else None,
        "Stoch%D":     round(ind.stoch_d, 1) if ind.stoch_d  else None,
        "BB上限":      round(ind.bb_upper, 2) if ind.bb_upper else None,
        "BB下限":      round(ind.bb_lower, 2) if ind.bb_lower else None,
        "OBV":         ind.obv_trend,
        "swing_score": sw_score,
        "売上成長率%": round(fund["revenue_growth"] * 100, 1)
                       if fund.get("revenue_growth") is not None else None,
        "PER":         round(per, 1) if per else None,
    }


def _passes_fundamental_filters(
    fund: dict,
    min_revenue_growth: float | None,
    max_per: float | None,
    require_positive_earnings: bool,
) -> bool:
    """ファンダメンタル条件を満たすか。取得済みの指標だけで決まる。

    指標が取れなかった場合、成長率と黒字は「条件を満たさない」扱いにし、
    PER は「上限で弾かない」扱いにする（元の挙動を維持）。
    """
    rev_gr = fund.get("revenue_growth")
    earn_gr = fund.get("earnings_growth")
    per = fund.get("trailing_pe") or fund.get("forward_pe")

    if min_revenue_growth is not None and (rev_gr is None or rev_gr < min_revenue_growth):
        return False
    if require_positive_earnings and (earn_gr is None or earn_gr <= 0):
        return False
    if max_per is not None and per is not None and per > max_per:
        return False
    return True


def _passes_technical_filters(
    rsi: float,
    close: float | None,
    sma20: float | None,
    macd: float | None,
    macd_sig: float | None,
    min_rsi: float,
    max_rsi: float,
    macd_signal: str | None,
    below_sma20: bool,
    above_sma20: bool,
) -> bool:
    """呼び出し側が指定した基本条件を満たすか。指標の値だけで決まる。"""
    if not (min_rsi <= rsi <= max_rsi):
        return False
    if macd_signal == "buy" and not (macd and macd_sig and macd > macd_sig):
        return False
    if macd_signal == "sell" and not (macd and macd_sig and macd < macd_sig):
        return False
    if below_sma20 and sma20 and close and not (close < sma20):
        return False
    if above_sma20 and sma20 and close and not (close > sma20):
        return False
    return True


def _passes_swing_filters(
    rsi: float,
    close: float | None,
    macd: float | None,
    macd_sig: float | None,
    stoch_k: float | None,
    bb_upper: float | None,
    bb_lower: float | None,
) -> bool:
    """スイング取引向けの追加条件。

    RSI 25〜55 の回復初期〜中立圏に限り、MACD 買いシグナルか
    深い売られすぎ(RSI<35)のどちらかを要求する。過買い(Stoch %K>70)と
    BB 上側1/4（エントリーが遅い）は除外する。
    """
    if not (25 <= rsi <= 55):
        return False
    macd_buy = macd is not None and macd_sig is not None and macd > macd_sig
    if not (macd_buy or rsi < 35):
        return False
    if stoch_k is not None and stoch_k > 70:
        return False
    if bb_upper and bb_lower and close:
        band = bb_upper - bb_lower
        if band > 0 and (close - bb_lower) / band > 0.75:
            return False
    return True


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
            ind = _latest_indicators(df)
            (close, rsi, sma20, macd, macd_sig,
             bb_upper, bb_lower, stoch_k, stoch_d, obv_trend) = ind

            # ── テクニカルフィルタ ──
            if rsi is None:
                continue
            if not _passes_technical_filters(
                rsi, close, sma20, macd, macd_sig,
                min_rsi, max_rsi, macd_signal, below_sma20, above_sma20,
            ):
                continue

            # ── スイングモード専用フィルタ ──
            if swing_mode and not _passes_swing_filters(
                rsi, close, macd, macd_sig, stoch_k, bb_upper, bb_lower
            ):
                continue

            # ── ファンダメンタルフィルタ ──
            fund = {}
            if use_fundamentals:
                fund = _fetch_fundamentals(ticker)
                if not _passes_fundamental_filters(
                    fund, min_revenue_growth, max_per, require_positive_earnings
                ):
                    continue

            # スイングスコア計算
            sw_score = _swing_score(rsi, macd, macd_sig, stoch_k, stoch_d,
                                    bb_upper, bb_lower, close, obv_trend)

            results.append(_build_row(
                ticker, names.get(ticker, ticker), cap_map.get(ticker, ""),
                ind, sw_score, fund,
            ))
        except Exception as e:
            # 1銘柄の失敗で全体を止めない。ただし、どの銘柄が
            # スクリーニング対象から漏れたのかは分かるようにしておく。
            print(f"  [WARN] {ticker}: スクリーニングに失敗しました: {e}")
            continue

    if not results:
        return pd.DataFrame()

    df_result = pd.DataFrame(results)
    # スイングモードは swing_score 降順、それ以外は RSI 昇順
    sort_col = "swing_score" if swing_mode else "RSI14"
    asc      = False if swing_mode else True
    return df_result.sort_values(sort_col, ascending=asc).reset_index(drop=True)
