"""ウォッチリスト読み込みのテスト。

market / cap_type の絞り込みを間違えると、対象外の銘柄を
黙ってスクリーニングにかけてしまう。
"""

import pandas as pd
import pytest

from src.analysis import screener


@pytest.fixture
def watchlist(tmp_path, monkeypatch):
    csv = tmp_path / "watchlist.csv"
    pd.DataFrame([
        {"ticker": "7203.T", "name": "トヨタ自動車", "market": "JP", "cap_type": "large"},
        {"ticker": "3990.T", "name": "UUUM", "market": "JP", "cap_type": "small"},
        {"ticker": "AAPL", "name": "Apple", "market": "US", "cap_type": "large"},
        {"ticker": "7203.T", "name": "トヨタ自動車", "market": "JP", "cap_type": "large"},  # 重複
    ]).to_csv(csv, index=False)
    monkeypatch.setattr(screener, "WATCHLIST", csv)
    return csv


def test_duplicates_are_removed(watchlist):
    assert list(screener.load_watchlist()["ticker"]) == ["7203.T", "3990.T", "AAPL"]


def test_market_filter_is_case_insensitive(watchlist):
    assert list(screener.load_watchlist(market="jp")["ticker"]) == ["7203.T", "3990.T"]
    assert list(screener.load_watchlist(market="US")["ticker"]) == ["AAPL"]


def test_cap_type_filter(watchlist):
    assert list(screener.load_watchlist(cap_types=["small"])["ticker"]) == ["3990.T"]


def test_filters_combine(watchlist):
    assert list(screener.load_watchlist(market="JP", cap_types=["large"])["ticker"]) == ["7203.T"]


def test_index_is_reset_so_row_numbers_are_contiguous(watchlist):
    assert list(screener.load_watchlist(market="US").index) == [0]
