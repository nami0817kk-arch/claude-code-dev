#!/usr/bin/env python3
"""毎日1回、楽天から価格を取得して記録する。GitHub Actions から実行する。

この環境（Claude の実行コンテナ）からは楽天へ到達できないため、
ここでの動作確認は --dry-run と単体テストで行い、実通信は Actions 上で行う。
"""
import argparse
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from src import rakuten, store  # noqa: E402

JST = timezone(timedelta(hours=9))


def main() -> int:
    ap = argparse.ArgumentParser(description="楽天から価格を取得して記録する")
    ap.add_argument("--dry-run", action="store_true",
                    help="通信せず、設定と保存先だけ確認する")
    ap.add_argument("--day", default=datetime.now(JST).strftime("%Y-%m-%d"))
    args = ap.parse_args()

    site = store.load_json(ROOT / "config.json", {})
    genres = site.get("genres") or []
    data = ROOT / "data"

    if not genres:
        print("config.json の genres が空です。explore.py で対象ジャンルを決めてください。")
        return 1

    if args.dry_run:
        print(f"対象ジャンル {len(genres)}件 / 1ジャンルあたり{site.get('hits_per_genre', 90)}件")
        print(f"想定リクエスト数: 約{len(genres) * (site.get('hits_per_genre', 90) // 30 + 1)}回"
              f"（1秒1回の制限のため所要 約{len(genres) * 4}秒）")
        print(f"保存先: {store.snapshot_path(data, args.day)}")
        return 0

    throttle = rakuten.Throttle()
    items = store.load_json(data / "items.json", {})
    fetched, failed = [], []

    for genre in genres:
        gid = str(genre["genre_id"] if isinstance(genre, dict) else genre)
        try:
            rows = rakuten.search_genre(gid, site.get("hits_per_genre", 90), throttle)
        except Exception as exc:  # 1ジャンル失敗しても他は記録する
            failed.append(f"{gid}: {exc}")
            continue
        print(f"  ジャンル {gid}: {len(rows)}件")
        fetched.extend(rows)
        for row in rows:
            # 価格は履歴側で持つので、マスタには変化しにくい情報だけ残す
            items[row["item_code"]] = {
                "name": row["name"], "shop": row["shop"], "url": row["url"],
                "image": row["image"], "genre_id": row["genre_id"] or gid,
            }

    if not fetched:
        print("1件も取得できませんでした。" + ("; ".join(failed) if failed else ""))
        return 1

    # 同じ商品が複数ジャンルで返ることがあるため、商品コードで一意にする
    unique = {row["item_code"]: row for row in fetched}
    rows = list(unique.values())

    store.write_snapshot(data, args.day, rows)
    summary = store.update_summary(
        store.load_json(data / "summary.json", {}), rows, args.day,
        site.get("history_tail_days", 90))
    store.save_json(data / "summary.json", summary)
    store.save_json(data / "items.json", items)

    without_affiliate = sum(1 for r in rows if not r["is_affiliate"])
    print(f"{args.day}: {len(rows)}件を記録（累計 {len(summary)}商品）")
    if without_affiliate:
        print(f"  警告: {without_affiliate}件がアフィリエイトリンクなし。"
              "RAKUTEN_AFFILIATE_ID が未設定だと収益が発生しません。")
    for f in failed:
        print(f"  失敗: {f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
