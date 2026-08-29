"""スイングスコアの採点ロジックのテスト。

`_swing_score` は「どの銘柄を買い候補として出すか」を決めている中心部分。
しきい値を1つ書き換えるだけで結果が変わるのに、動かしてみても
それが意図した変更なのか事故なのか見分けがつかない。ここを固定しておく。

各条件の配点（合計10点上限）:
  RSI 30〜50 で +2 / RSI<30 で +1
  MACD が signal を上回る       +2
  Stoch %K<25 かつ %D をクロス  +3（%K<25 のみなら +1、%K<40 のクロスは +1）
  BB の下側1/3にいる            +2
  OBV 上昇                      +1
"""

import pytest

from src.analysis.screener import _swing_score

# どの条件も満たさない中立の入力。ここから1つずつ条件を足して差分を見る。
NEUTRAL = dict(
    rsi=60, macd=0, macd_sig=1, stoch_k=80, stoch_d=90,
    bb_upper=110, bb_lower=90, close=105, obv_trend="下降",
)


def score(**overrides) -> int:
    return _swing_score(**{**NEUTRAL, **overrides})


def test_neutral_input_scores_zero():
    assert score() == 0


# --- RSI -----------------------------------------------------------------

@pytest.mark.parametrize("rsi, expected", [
    (30, 2),    # 黄金ゾーンの下端（境界を含む）
    (40, 2),
    (50, 2),    # 黄金ゾーンの上端（境界を含む）
    (29.9, 1),  # 深売られすぎ
    (10, 1),
    (51, 0),    # ゾーンを外れる
    (None, 0),  # 指標が欠けていても落ちない
])
def test_rsi_band(rsi, expected):
    assert score(rsi=rsi) == expected


# --- MACD ----------------------------------------------------------------

def test_macd_above_signal_scores():
    assert score(macd=1, macd_sig=0) == 2


def test_macd_below_signal_scores_nothing():
    assert score(macd=0, macd_sig=1) == 0


def test_macd_missing_values_are_safe():
    assert score(macd=None, macd_sig=None) == 0
    assert score(macd=1, macd_sig=None) == 0


# --- ストキャスティクス ---------------------------------------------------

def test_oversold_golden_cross_is_the_strongest_signal():
    assert score(stoch_k=20, stoch_d=10) == 3


def test_oversold_without_a_cross_scores_less():
    assert score(stoch_k=20, stoch_d=30) == 1


def test_cross_in_the_middle_band_scores_one():
    assert score(stoch_k=35, stoch_d=30) == 1


def test_cross_above_the_middle_band_scores_nothing():
    assert score(stoch_k=45, stoch_d=30) == 0


def test_stoch_missing_value_is_safe():
    assert score(stoch_k=None) == 0
    assert score(stoch_k=20, stoch_d=None) == 1


# --- ボリンジャーバンド ---------------------------------------------------

def test_lower_third_of_the_band_scores():
    # 下限90/上限110、下側1/3は 96.6 まで
    assert score(bb_lower=90, bb_upper=110, close=95) == 2


def test_above_the_lower_third_scores_nothing():
    assert score(bb_lower=90, bb_upper=110, close=100) == 0


def test_flat_band_does_not_divide_by_zero():
    assert score(bb_lower=100, bb_upper=100, close=100) == 0


def test_missing_band_is_safe():
    assert score(bb_upper=None, bb_lower=None) == 0


# --- OBV -----------------------------------------------------------------

def test_rising_obv_scores_one():
    assert score(obv_trend="上昇") == 1


def test_other_obv_trends_score_nothing():
    assert score(obv_trend="下降") == 0
    assert score(obv_trend=None) == 0


# --- 合算 -----------------------------------------------------------------

def test_scores_accumulate_across_conditions():
    # RSI(+2) と MACD(+2) だけを満たす
    assert score(rsi=40, macd=1, macd_sig=0) == 4


def test_score_is_capped_at_ten():
    best = _swing_score(
        rsi=40, macd=1, macd_sig=0, stoch_k=20, stoch_d=10,
        bb_upper=110, bb_lower=90, close=91, obv_trend="上昇",
    )
    # 2+2+3+2+1 = 10。上限を超えないこと。
    assert best == 10


def test_score_never_goes_negative():
    assert score(rsi=100, macd=-5, macd_sig=5) >= 0
