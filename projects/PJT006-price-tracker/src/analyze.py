"""価格履歴から「買い時か」を機械的に判定する。

判定はすべて四則演算で行い、実行時に AI は使わない。
理由は2つ。定額のサブスク以外に従量課金を発生させないため、
そして「事実の提示」に留めることで、根拠のない推奨を書かないため。
"""

# 履歴がこの日数に満たない商品について「過去最安値」を名乗らない。
# 初日は当然すべてが最安値になるが、それは情報ではないため。
MIN_DAYS_FOR_LOW = 7


def evaluate(rec: dict, drop_threshold: float, near_low_threshold: float) -> dict:
    """1商品の履歴レコードを判定結果に変える。"""
    price = rec.get("last")
    low = rec.get("min")
    if not price or not low:
        return {}

    days = int(rec.get("days") or 0)
    prev = rec.get("prev")
    drop_pct = (prev - price) / prev if prev and prev > price else 0.0
    rise_pct = (price - prev) / prev if prev and price > prev else 0.0
    vs_low_pct = (price - low) / low if low else 0.0
    high = rec.get("max") or price
    off_high_pct = (high - price) / high if high else 0.0

    trustworthy = days >= MIN_DAYS_FOR_LOW
    at_low = trustworthy and price <= low
    near_low = trustworthy and 0 < vs_low_pct <= near_low_threshold
    dropped = drop_pct >= drop_threshold

    if at_low:
        label = "記録した中で最安"
    elif near_low:
        label = "最安値に近い"
    elif dropped:
        label = "値下がり"
    elif not trustworthy:
        label = "記録中"
    else:
        label = "横ばい"

    return {
        "price": price, "low": low, "high": high, "days": days,
        "prev": prev, "drop_pct": drop_pct, "rise_pct": rise_pct,
        "vs_low_pct": vs_low_pct, "off_high_pct": off_high_pct,
        "at_low": at_low, "near_low": near_low, "dropped": dropped,
        "trustworthy": trustworthy, "label": label,
        "low_date": rec.get("min_date"), "tail": rec.get("tail") or [],
    }


def evaluate_all(summary: dict, items: dict, drop_threshold: float,
                 near_low_threshold: float) -> list[dict]:
    """商品マスタと履歴を突き合わせ、判定済みの一覧にする。

    履歴にしか無い商品（販売終了などで今日取得できなかったもの）は、
    価格が今日のものだと誤解されるため出さない。
    """
    out = []
    for code, meta in items.items():
        rec = summary.get(code)
        if not rec:
            continue
        verdict = evaluate(rec, drop_threshold, near_low_threshold)
        if not verdict:
            continue
        out.append({**meta, **verdict, "item_code": code})
    return out


def drops(rows: list[dict], limit: int = 100) -> list[dict]:
    """前回より安くなったものを、下げ幅の大きい順に。"""
    hit = [r for r in rows if r["dropped"]]
    hit.sort(key=lambda r: (-r["drop_pct"], r["price"]))
    return hit[:limit]


def lows(rows: list[dict], limit: int = 100) -> list[dict]:
    """記録した中で最安、またはそれに近いもの。"""
    hit = [r for r in rows if r["at_low"] or r["near_low"]]
    hit.sort(key=lambda r: (r["vs_low_pct"], -r["days"]))
    return hit[:limit]
