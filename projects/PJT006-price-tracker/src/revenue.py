"""収益の見積り。楽天アフィリエイトの報酬規則を、そのまま計算式にする。

重要な制約が2つあり、どちらも「どのジャンルを狙うか」を左右する。

1. 成果報酬は 1商品1個につき 1,000円が上限。
   料率2%なら 50,000円を超えた分は報酬にならない（実効料率が下がっていく）。
2. 同一ユーザーからの月間報酬は 3,000円が上限。

したがって「高いものが売れるジャンルほど得」ではない。
上限に当たる手前がいちばん効率が良い。
"""

REWARD_CAP = 1000          # 1商品1個あたりの報酬上限（円）
USER_MONTHLY_CAP = 3000    # 同一ユーザーからの月間報酬上限（円）


def reward(price: int, rate: float, cap: int = REWARD_CAP) -> int:
    """1件売れたときの報酬。上限で頭打ちになる。"""
    return min(int(price * rate), cap)


def effective_rate(price: int, rate: float, cap: int = REWARD_CAP) -> float:
    """上限を踏まえた実効料率。価格が上がるほど下がっていく。"""
    if price <= 0:
        return 0.0
    return reward(price, rate, cap) / price


def cap_price(rate: float, cap: int = REWARD_CAP) -> int:
    """報酬が上限に達する価格。これを超えると1件あたりの取り分は増えない。"""
    if rate <= 0:
        return 0
    return int(cap / rate)


def revenue_per_pv(price: int, rate: float, order_rate: float,
                   cap: int = REWARD_CAP) -> float:
    """1PVあたりの売上。order_rate は「訪問のうち注文につながる割合」。"""
    return reward(price, rate, cap) * order_rate


def break_even_pv(monthly_cost: int, price: int, rate: float,
                  order_rate: float, cap: int = REWARD_CAP) -> int:
    """固定費を賄うのに必要な月間PV。変動費が無いのでこれが唯一の分岐点になる。"""
    per_pv = revenue_per_pv(price, rate, order_rate, cap)
    if per_pv <= 0:
        return 0
    return int(monthly_cost / per_pv + 0.999)


def margin(revenue: int, monthly_cost: int) -> float:
    """利益率。変動費が無いため、売上が増えるほど 100% に近づく。"""
    if revenue <= 0:
        return 0.0
    return (revenue - monthly_cost) / revenue
