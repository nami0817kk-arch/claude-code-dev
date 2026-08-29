#!/usr/bin/env python3
"""狙うジャンルを、勘ではなくデータで決めるための調査スクリプト。

ジャンル一覧を取得し、それぞれの「1件売れたときの報酬」で並べる。

価格の高いジャンルほど得だとは限らない。報酬には 1商品あたり1,000円の上限があり、
料率2%なら 50,000円を超えた分は報酬にならないため、上限に当たる手前がいちばん効率が良い。
Actions 上で手動実行し、結果を見て config.json の genres を決める。
"""
import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from src import rakuten, revenue, store  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description="ジャンルを調べて候補を出す")
    ap.add_argument("--genre", default="0", help="調べる親ジャンルID（0 が最上位）")
    ap.add_argument("--sample", type=int, default=30, help="各ジャンルから見る商品数")
    ap.add_argument("--depth", type=int, default=1, help="何段掘るか")
    args = ap.parse_args()

    site = store.load_json(ROOT / "config.json", {})
    rate = site.get("commission_rate", 0.02)
    cost = site.get("monthly_cost", 15000)
    order_rate = site.get("assumed_order_rate", 0.005)
    print(f"料率 {rate:.0%} / 報酬上限 {revenue.REWARD_CAP:,}円 "
          f"（{revenue.cap_price(rate):,}円を超えると1件あたりの取り分は増えません）")
    print(f"固定費 {cost:,}円 / 想定注文率 {order_rate:.1%} で必要PVを試算します\n")

    throttle = rakuten.Throttle()
    targets = [{"genre_id": args.genre, "name": "(指定)"}]
    for _ in range(args.depth):
        nxt = []
        for t in targets:
            nxt.extend(rakuten.genre_children(t["genre_id"], throttle))
        if not nxt:
            break
        targets = nxt

    print(f"{'ジャンルID':>10} {'中央価格':>9} {'1件報酬':>7} "
          f"{'実効料率':>6} {'必要PV/月':>9} {'レビュー':>6}  ジャンル名")
    rows_out = []
    for t in targets:
        try:
            rows = rakuten.search_genre(t["genre_id"], args.sample, throttle)
        except Exception as exc:
            print(f"{t['genre_id']:>10}  取得失敗: {exc}")
            continue
        if not rows:
            continue
        prices = sorted(r["price"] for r in rows)
        reviews = sorted(r["review_count"] for r in rows)
        mid = prices[len(prices) // 2]
        review_mid = reviews[len(reviews) // 2]
        rows_out.append((revenue.reward(mid, rate), review_mid, t, mid,
                         revenue.break_even_pv(cost, mid, rate, order_rate)))

    # 期待報酬の大きい順。同額なら買われている（レビューが多い）ほうを上に。
    for pay, review_mid, t, mid, need in sorted(rows_out, key=lambda r: (-r[0], -r[1])):
        mark = " ←上限で頭打ち" if pay >= revenue.REWARD_CAP else ""
        print(f"{t['genre_id']:>10} {mid:>9,} {pay:>7,} "
              f"{revenue.effective_rate(mid, rate):>6.2%} {need:>9,} "
              f"{review_mid:>6}  {t['name']}{mark}")

    print("\n見方: 1件報酬が大きく、必要PVが小さく、レビューが多いジャンルが候補です。")
    print("「←上限で頭打ち」は高額すぎるジャンルです。売るのは難しいのに取り分は増えません。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
