#!/usr/bin/env python3
"""記録済みのデータから静的サイトを生成する。ネットワークへは一切アクセスしない。"""
import argparse
import shutil
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from src import analyze, pages, store, theme  # noqa: E402

JST = timezone(timedelta(hours=9))


def today() -> str:
    return datetime.now(JST).strftime("%Y-%m-%d")


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def sitemap(site: dict, urls: list[str], updated: str) -> str:
    base = site["base_url"].rstrip("/")
    entries = "".join(
        f"\n  <url><loc>{theme.esc(base + u)}</loc><lastmod>{updated}</lastmod></url>"
        for u in urls)
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
            f'{entries}\n</urlset>\n')


def robots(site: dict) -> str:
    return f"User-agent: *\nAllow: /\n\nSitemap: {site['base_url'].rstrip('/')}/sitemap.xml\n"


def build(root: Path, out: Path) -> dict:
    site = store.load_json(root / "config.json", {})
    data = root / "data"
    items = store.load_json(data / "items.json", {})
    summary = store.load_json(data / "summary.json", {})

    rows = analyze.evaluate_all(summary, items,
                                site.get("drop_threshold", 0.05),
                                site.get("near_low_threshold", 0.02))
    updated = today()

    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    shutil.copy(ROOT / "src" / "style.css", out / "style.css")

    base = site["base_url"].rstrip("/")
    dropped = analyze.drops(rows)
    low = analyze.lows(rows)

    write(out / "index.html", theme.listing(
        "今日の値下がり",
        "毎日記録している楽天市場の価格から、前回より安くなった商品を並べています。",
        dropped, site, base + "/", updated, prefix="",
        empty="今日の記録では、判定できるほどの値下がりはありませんでした。"))

    write(out / "lows" / "index.html", theme.listing(
        "最安値圏の商品",
        "当サイトが記録している期間の最安値と同じか、それに近い価格の商品です。",
        low, site, base + "/lows/", updated, prefix="../",
        empty="価格の記録日数がまだ足りません。判定には最低7日分が必要です。"))

    urls = ["/", "/lows/"]
    for page in pages.PAGES:
        write(out / page["slug"] / "index.html", pages.render(page, site, updated))
        urls.append(f'/{page["slug"]}/')

    for row in rows:
        s = theme.slug(row["item_code"])
        write(out / "item" / s / "index.html", theme.item_page(row, site, updated))
        urls.append(f"/item/{s}/")

    write(out / "sitemap.xml", sitemap(site, urls, updated))
    write(out / "robots.txt", robots(site))

    return {"items": len(rows), "drops": len(dropped), "lows": len(low),
            "pages": len(urls), "updated": updated}


def warnings(root: Path) -> list[str]:
    site = store.load_json(root / "config.json", {})
    out = []
    missing = [k for k in ("owner", "contact_email") if not site.get(k)]
    if missing:
        out.append(f"config.json の未設定: {', '.join(missing)}"
                   "（アフィリエイトを行うサイトには運営者情報の表示が必要です）")
    if not site.get("genres"):
        out.append("config.json の genres が空です。explore.py で対象ジャンルを決めてください。")
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="記録済みデータから静的サイトを生成する")
    ap.add_argument("--out", default=str(ROOT / "dist"))
    args = ap.parse_args()

    stats = build(ROOT, Path(args.out))
    print(f"生成しました: 商品{stats['items']}件 / 値下がり{stats['drops']}件 / "
          f"最安値圏{stats['lows']}件 / 全{stats['pages']}ページ（{stats['updated']}）")
    for w in warnings(ROOT):
        print(f"  警告: {w}")
    if stats["items"] == 0:
        print("  警告: 商品データがありません。先に fetch.py を実行してください。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
