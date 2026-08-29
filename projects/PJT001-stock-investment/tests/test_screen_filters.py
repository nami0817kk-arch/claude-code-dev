"""スクリーニングの絞り込み条件のテスト。

`screen()` が長かったので判定部分を純粋関数に切り出した。
切り出しで挙動が変わっていないことを確かめるため、
条件ごとの単体テストに加えて、`screen()` 全体をネットワーク無しで
通す試験も置いてある。
"""

import numpy as np
import pandas as pd
import pytest

from src.analysis.screener import (
    _build_row,
    _latest_indicators,
    _passes_fundamental_filters,
    _passes_swing_filters,
    _passes_technical_filters,
    screen,
)

# 既定は「どの条件でも弾かれない」中立の入力
TECH = dict(
    rsi=50, close=100, sma20=100, macd=0, macd_sig=0,
    min_rsi=0, max_rsi=100, macd_signal=None, below_sma20=False, above_sma20=False,
)


def tech(**kw) -> bool:
    return _passes_technical_filters(**{**TECH, **kw})


# --- 基本フィルタ ---------------------------------------------------------

def test_rsi_range_is_inclusive():
    assert tech(rsi=30, min_rsi=30, max_rsi=50)
    assert tech(rsi=50, min_rsi=30, max_rsi=50)
    assert not tech(rsi=29, min_rsi=30, max_rsi=50)
    assert not tech(rsi=51, min_rsi=30, max_rsi=50)


def test_macd_buy_filter():
    assert tech(macd_signal="buy", macd=2, macd_sig=1)
    assert not tech(macd_signal="buy", macd=1, macd_sig=2)
    assert not tech(macd_signal="buy", macd=None, macd_sig=None)


def test_macd_sell_filter():
    assert tech(macd_signal="sell", macd=1, macd_sig=2)
    assert not tech(macd_signal="sell", macd=2, macd_sig=1)


def test_macd_value_of_exactly_zero_fails_the_filter():
    """既存の癖を明示しておく。

    判定が `macd and macd_sig` という真偽値評価なので、
    どちらかが厳密に 0.0 だと「値が無い」のと同じ扱いになり、
    buy/sell 条件は満たさないと判断される。
    直すと選定結果が変わるため、ここでは挙動を変えずに固定する。
    """
    assert not tech(macd_signal="buy", macd=1, macd_sig=0.0)
    assert not tech(macd_signal="buy", macd=0.0, macd_sig=-1)


def test_sma20_position_filters():
    assert tech(below_sma20=True, close=90, sma20=100)
    assert not tech(below_sma20=True, close=110, sma20=100)
    assert tech(above_sma20=True, close=110, sma20=100)
    assert not tech(above_sma20=True, close=90, sma20=100)


def test_sma20_filter_is_skipped_when_the_value_is_missing():
    """指標が取れない銘柄を、条件で弾かずに通す（従来の挙動）。"""
    assert tech(below_sma20=True, sma20=None, close=110)


# --- スイングモード -------------------------------------------------------

SWING = dict(rsi=30, close=100, macd=1, macd_sig=0, stoch_k=50, bb_upper=110, bb_lower=90)


def swing(**kw) -> bool:
    return _passes_swing_filters(**{**SWING, **kw})


def test_swing_requires_rsi_between_25_and_55():
    assert swing(rsi=25) and swing(rsi=55)
    assert not swing(rsi=24)
    assert not swing(rsi=56)


def test_swing_requires_macd_buy_or_deep_oversold():
    assert swing(macd=1, macd_sig=0, rsi=50)          # MACD買い
    assert swing(macd=0, macd_sig=1, rsi=30)          # 深い売られすぎ
    assert not swing(macd=0, macd_sig=1, rsi=40)      # どちらでもない


def test_swing_excludes_overbought_stochastics():
    assert not swing(stoch_k=71)
    assert swing(stoch_k=70)
    assert swing(stoch_k=None)


def test_swing_excludes_the_top_quarter_of_the_band():
    # 下限90/上限110、上側1/4は 105 超
    assert not swing(close=106)
    assert swing(close=105)


def test_swing_flat_band_does_not_divide_by_zero():
    assert swing(bb_upper=100, bb_lower=100, close=100)


# --- ファンダメンタル -----------------------------------------------------

def test_growth_threshold():
    assert _passes_fundamental_filters({"revenue_growth": 0.2}, 0.1, None, False)
    assert not _passes_fundamental_filters({"revenue_growth": 0.05}, 0.1, None, False)


def test_missing_growth_is_treated_as_failing_the_condition():
    assert not _passes_fundamental_filters({}, 0.1, None, False)


def test_positive_earnings_requirement():
    assert _passes_fundamental_filters({"earnings_growth": 0.1}, None, None, True)
    assert not _passes_fundamental_filters({"earnings_growth": -0.1}, None, None, True)
    assert not _passes_fundamental_filters({}, None, None, True)


def test_per_cap_falls_back_to_forward_pe():
    assert _passes_fundamental_filters({"forward_pe": 10}, None, 15, False)
    assert not _passes_fundamental_filters({"forward_pe": 20}, None, 15, False)


def test_missing_per_is_not_filtered_out():
    """PER が取れない銘柄は上限で弾かない（従来の挙動）。"""
    assert _passes_fundamental_filters({}, None, 15, False)


# --- 指標の取り出し -------------------------------------------------------

def _frame(**cols) -> pd.DataFrame:
    n = len(next(iter(cols.values())))
    return pd.DataFrame(cols, index=pd.date_range("2026-01-01", periods=n))


def test_latest_indicators_reads_the_last_row():
    df = _frame(Close=[1.0, 2.0, 3.0], RSI14=[10.0, 20.0, 30.0])
    ind = _latest_indicators(df)
    assert ind.close == 3.0 and ind.rsi == 30.0
    assert ind.sma20 is None          # 列が無ければ None
    assert ind.obv_trend == "不明"    # OBV 列が無い


def test_obv_trend_uses_the_last_five_days():
    df = _frame(Close=[1.0] * 6, OBV=[1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
    assert _latest_indicators(df).obv_trend == "上昇"
    df = _frame(Close=[1.0] * 6, OBV=[6.0, 5.0, 4.0, 3.0, 2.0, 1.0])
    assert _latest_indicators(df).obv_trend == "下降"


def test_nan_indicator_becomes_none():
    df = _frame(Close=[1.0, np.nan])
    assert _latest_indicators(df).close is None


def test_build_row_shapes_the_output():
    ind = _latest_indicators(_frame(Close=[100.456], RSI14=[42.44]))
    row = _build_row("7203.T", "トヨタ", "large", ind, 7, {"revenue_growth": 0.123})
    assert row["ticker"] == "7203.T" and row["swing_score"] == 7
    assert row["終値"] == 100.46 and row["RSI14"] == 42.4
    assert row["売上成長率%"] == 12.3
    assert row["PER"] is None


# --- screen() 全体（ネットワーク無し） ------------------------------------

def _price_series(base: float, drift: float, n: int = 120) -> pd.DataFrame:
    """指標計算に足りる長さの、決定的な価格データを作る。"""
    close = np.array([base + drift * i for i in range(n)], dtype=float)
    return pd.DataFrame({
        "Open": close, "High": close * 1.01, "Low": close * 0.99,
        "Close": close, "Volume": np.full(n, 1_000_000.0),
    }, index=pd.date_range("2026-01-01", periods=n))


@pytest.fixture
def offline(monkeypatch):
    """fetch_price を差し替えて、screen() をネットワーク無しで通す。"""
    from src.analysis import screener

    frames = {"UP": _price_series(100, 1.0), "DOWN": _price_series(200, -1.0)}
    monkeypatch.setattr(screener, "fetch_price", lambda t, period="3mo": frames[t])
    return frames


def test_screen_runs_end_to_end_and_returns_expected_columns(offline):
    df = screen(tickers=["UP", "DOWN"])
    assert not df.empty
    for col in ("ticker", "RSI14", "MACD方向", "swing_score", "OBV"):
        assert col in df.columns
    assert set(df["ticker"]) <= {"UP", "DOWN"}


def test_screen_applies_the_rsi_filter(offline):
    """上昇一辺倒の銘柄は RSI が高いので、低RSI条件では残らない。"""
    assert "UP" not in set(screen(tickers=["UP", "DOWN"], max_rsi=30)["ticker"])


def test_screen_sorts_by_rsi_ascending_by_default(offline):
    df = screen(tickers=["UP", "DOWN"])
    assert list(df["RSI14"]) == sorted(df["RSI14"])


def test_screen_in_swing_mode_sorts_by_score_descending(offline):
    df = screen(tickers=["UP", "DOWN"], swing_mode=True)
    if df.empty:
        pytest.skip("この価格データではスイング条件を通る銘柄が無い")
    assert "swing_score" in df.columns
    assert list(df["swing_score"]) == sorted(df["swing_score"], reverse=True)


def test_screen_returns_an_empty_frame_when_nothing_matches(offline):
    # 単調増加/単調減少なので RSI は 100 と 0 に振り切れる。その間を指定する。
    assert screen(tickers=["UP", "DOWN"], min_rsi=40, max_rsi=60).empty


def test_screen_survives_a_failing_ticker(offline, monkeypatch, capsys):
    """1銘柄が落ちても他は処理を続け、落ちたことは記録に残す。"""
    from src.analysis import screener

    original = screener.fetch_price

    def _flaky(ticker, period="3mo"):
        if ticker == "DOWN":
            raise RuntimeError("取得失敗")
        return original(ticker, period)

    monkeypatch.setattr(screener, "fetch_price", _flaky)
    df = screen(tickers=["UP", "DOWN"])

    assert set(df["ticker"]) == {"UP"}
    assert "DOWN" in capsys.readouterr().out
