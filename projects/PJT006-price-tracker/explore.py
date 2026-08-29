#!/usr/bin/env python3
"""狙うジャンルを、勘ではなくデータで決めるための調査スクリプト。

ジャンル一覧を取得し、それぞれの価格帯とレビュー数を見て候補を出す。
Actions 上で手動実行し、結果を見て config.json の genres を決める。
"""
import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from src import rakuten  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description="ジャンルを調べて候補を出す")
    ap.add_argument("--genre", default="0", help="調べる親ジャンルID（0 が最上位）")
    ap.add_argument("--sample", type=int, default=30, help="各ジャンルから見る商品数")
    ap.add_argument("--depth", type=int, default=1, help="何段掘るか")
    args = ap.parse_args()

    throttle = rakuten.Throttle()
    targets = [{"genre_id": args.genre, "name": "(指定)"}]
    for _ in range(args.depth):
        nxt = []
        for t in targets:
            nxt.extend(rakuten.genre_children(t["genre_id"], throttle))
        if not nxt:
            break
        targets = nxt

    print(f"{'ジャンルID':>10}  {'商品数':>5}  {'中央価格':>9}  {'レビュー中央':>7}  ジャンル名")
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
        mid = len(prices) // 2
        print(f"{t['genre_id']:>10}  {len(rows):>5}  {prices[mid]:>9,}  "
              f"{reviews[len(reviews) // 2]:>7}  {t['name']}")
    print("\n価格が高すぎず（数千円〜数万円）、レビュー数が多いジャンルが候補です。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
