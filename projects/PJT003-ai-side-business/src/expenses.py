"""経費の記録。

副業は、収益が立つ前に必ず支出が先に出る。
その額と期間を把握していないと、「いくら回収すればいいのか」も
「いつ見切るのか」も判断できない。

プロジェクトに紐づく原価は pjt record --cost に、
それ以外の共通経費（ツール利用料・ドメイン・サーバー）はここに記録する。
"""
from datetime import datetime

from . import store

NAME = "expenses"

CATEGORIES = {
    "tool": "ツール利用料",
    "infra": "サーバー・ドメイン",
    "ads": "広告費",
    "other": "その他",
}


def load() -> list:
    return store.load(NAME, [])


def save(records: list):
    return store.save(NAME, records)


def next_month(month: str) -> str:
    y, m = int(month[:4]), int(month[5:7])
    return f"{y + 1:04d}-01" if m == 12 else f"{y:04d}-{m + 1:02d}"


def add(amount: int, item: str, category: str = "tool", month: str = "",
        note: str = "") -> dict:
    """1ヶ月分の経費を記録する。同じ月・同じ項目なら上書きする。"""
    month = month or store.today()[:7]
    records = load()

    existing = next((r for r in records
                     if r["month"] == month and r["item"] == item), None)
    if existing:
        existing.update(amount=int(amount), category=category, note=note)
        record = existing
    else:
        record = {
            "id": max((r["id"] for r in records), default=0) + 1,
            "month": month,
            "item": item,
            "category": category,
            "amount": int(amount),
            "note": note,
        }
        records.append(record)

    records.sort(key=lambda r: (r["month"], r["item"]))
    save(records)
    return record


def add_monthly(amount: int, item: str, category: str = "tool",
                start: str = "", end: str = "", note: str = "") -> list:
    """毎月かかる固定費を、開始月から対象月までまとめて記録する。

    利用料のような継続課金を毎月手で入れるのは続かないので、
    「いつから使っているか」だけ指定すれば埋まるようにする。
    """
    start = start or store.today()[:7]
    end = end or store.today()[:7]
    if start > end:
        start, end = end, start

    added, month = [], start
    while month <= end:
        added.append(add(amount, item, category=category, month=month, note=note))
        month = next_month(month)
    return added


def remove(expense_id: int) -> bool:
    records = load()
    rest = [r for r in records if r["id"] != int(expense_id)]
    if len(rest) == len(records):
        return False
    save(rest)
    return True


def by_month(records: list = None) -> dict:
    records = load() if records is None else records
    months = {}
    for r in records:
        months[r["month"]] = months.get(r["month"], 0) + r["amount"]
    return dict(sorted(months.items()))


def by_item(records: list = None) -> dict:
    """項目ごとの累計と、月あたりの平均。"""
    records = load() if records is None else records
    items = {}
    for r in records:
        entry = items.setdefault(r["item"], {"total": 0, "months": 0,
                                             "category": r["category"]})
        entry["total"] += r["amount"]
        entry["months"] += 1
    for entry in items.values():
        entry["monthly"] = round(entry["total"] / entry["months"]) if entry["months"] else 0
    return dict(sorted(items.items(), key=lambda kv: -kv[1]["total"]))


def total(records: list = None) -> int:
    records = load() if records is None else records
    return sum(r["amount"] for r in records)


def this_month(records: list = None) -> int:
    records = load() if records is None else records
    month = store.today()[:7]
    return sum(r["amount"] for r in records if r["month"] == month)


def monthly_run_rate(records: list = None) -> int:
    """直近月の支出額。これが毎月出ていく額の目安になる。"""
    months = by_month(records)
    return list(months.values())[-1] if months else 0


def months_elapsed(records: list = None) -> int:
    """支出が始まってから何ヶ月たったか。"""
    months = by_month(records)
    return len(months)


def print_expenses():
    records = load()
    if not records:
        print("経費の記録がありません。")
        print('  例) python main.py expense add 3000 --item "Claude利用料" --from 2026-05')
        return

    months = by_month(records)
    items = by_item(records)

    print(f"\n{'='*70}")
    print("  経費")
    print(f"{'='*70}")
    print(f"  {'項目':<22}{'累計':>12}{'月あたり':>12}{'期間':>8}")
    print(f"{'-'*70}")
    for name, e in items.items():
        print(f"  {name[:20]:<22}{e['total']:>11,}円{e['monthly']:>11,}円"
              f"{e['months']:>7}ヶ月")
    print(f"{'-'*70}")
    print(f"  累計 {total(records):,}円 / {len(months)}ヶ月")
    print(f"  直近月の支出 {monthly_run_rate(records):,}円")

    print(f"\n  {'年月':<9}{'支出':>12}")
    for month, amount in months.items():
        print(f"  {month:<9}{amount:>11,}円")
    print(f"{'='*70}")
