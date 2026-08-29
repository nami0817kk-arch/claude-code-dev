"""価格の記録と集計。

APIは「今日の価格」しか返さない。毎日それを保存し続けることで、
他が持っていない価格履歴になる。この蓄積がこのサイトの唯一の資産なので、
保存処理は「同じ日に二回動かしても壊れない」ことを最優先にする。
"""
import csv
import gzip
import json
from pathlib import Path

SNAPSHOT_FIELDS = ["date", "item_code", "price", "review_count", "review_average"]


def snapshot_path(data_dir: Path, day: str) -> Path:
    return data_dir / "snapshots" / f"{day}.csv.gz"


def write_snapshot(data_dir: Path, day: str, items: list[dict]) -> Path:
    """その日の価格を1ファイルに書く。既にあれば上書きする（再実行しても二重に増えない）。"""
    path = snapshot_path(data_dir, day)
    path.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(path, "wt", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=SNAPSHOT_FIELDS)
        writer.writeheader()
        for item in items:
            writer.writerow({
                "date": day,
                "item_code": item["item_code"],
                "price": item["price"],
                "review_count": item.get("review_count", 0),
                "review_average": item.get("review_average", 0),
            })
    return path


def read_snapshot(data_dir: Path, day: str) -> list[dict]:
    path = snapshot_path(data_dir, day)
    if not path.exists():
        return []
    with gzip.open(path, "rt", encoding="utf-8", newline="") as fh:
        return [
            {"date": r["date"], "item_code": r["item_code"], "price": int(r["price"])}
            for r in csv.DictReader(fh) if r.get("price")
        ]


def load_json(path: Path, default):
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError):
        return default


def save_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=1, sort_keys=True),
                    encoding="utf-8")


def update_summary(summary: dict, items: list[dict], day: str, tail_days: int) -> dict:
    """その日の価格を履歴に足し込む。

    同じ日を二度渡しても結果が変わらないようにする（Actions の再実行や
    手動実行が重なっても履歴が歪まないため）。
    """
    out = dict(summary)
    for item in items:
        code, price = item["item_code"], int(item["price"])
        rec = dict(out.get(code) or {})
        tail = [list(p) for p in rec.get("tail") or []]

        if tail and tail[-1][0] == day:
            tail[-1] = [day, price]
            recompute = True
        else:
            tail.append([day, price])
            recompute = False
        tail = tail[-tail_days:]

        if recompute or "min" not in rec:
            # その日を上書きした場合、過去の最安値が今日の値だった可能性があるので
            # 保持している範囲から取り直す。
            prices = [p for _, p in tail]
            rec["min"] = min(prices)
            rec["max"] = max(prices)
            rec["min_date"] = next(d for d, p in tail if p == rec["min"])
        else:
            if price < rec["min"]:
                rec["min"], rec["min_date"] = price, day
            if price > rec["max"]:
                rec["max"] = price

        rec["prev"] = rec.get("last")
        rec["prev_date"] = rec.get("last_date")
        if rec.get("last_date") == day:
            # 同日再実行。prev は元のまま維持する。
            rec["prev"] = (out.get(code) or {}).get("prev")
            rec["prev_date"] = (out.get(code) or {}).get("prev_date")
        rec["last"], rec["last_date"] = price, day
        rec["days"] = len(tail)
        rec["tail"] = tail
        out[code] = rec
    return out
