"""
サイト全体のビルドエントリポイント。

1. 当日の値上がりランキングを取得
2. data/YYYY-MM-DD.json ＋ data/latest.json に保存
3. output/ に静的HTMLを生成

市場休場日等でランキングが0件の場合は、既存データを壊さないよう
何もせずに正常終了する（呼び出し元のCIはこの場合コミット・デプロイをスキップする）。
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from fetcher import fetch_gainers
import render

_DATA_DIR = Path(__file__).resolve().parent.parent / "data"


def _save_today(df) -> str | None:
    if df.empty:
        print("  本日分のランキングを取得できませんでした（休場日、または取得失敗）。スキップします。")
        return None

    rec_date = df["rec_date"].iloc[0]
    rows = df[["rank", "code", "name", "close", "gain_pct", "volume"]].to_dict(orient="records")
    payload = {"rec_date": rec_date, "rows": rows}

    _DATA_DIR.mkdir(parents=True, exist_ok=True)
    day_path = _DATA_DIR / f"{rec_date}.json"
    day_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    (_DATA_DIR / "latest.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"  {day_path} に保存しました（{len(rows)}件）")
    return rec_date


def main() -> None:
    df = fetch_gainers(top_n=30)
    rec_date = _save_today(df)

    if rec_date is None and not any(_DATA_DIR.glob("????-??-??.json")):
        # 初回実行で1件もデータが無ければビルドしようがない
        print("  data/ に既存データも無いため、サイトのビルドを中止します。")
        return

    render.build_all()


if __name__ == "__main__":
    main()
