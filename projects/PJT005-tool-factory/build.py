"""tools/ に置いたツール定義から、公開できる静的サイトを dist/ に出力する。

  python build.py            全ツールをビルド
  python build.py --serve    ビルドしてローカルで確認する

出力はそのまま GitHub Pages などに置ける（サーバー処理は不要）。
"""
import argparse
import importlib
import json
import pkgutil
import shutil
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DIST = ROOT / "dist"

sys.path.insert(0, str(ROOT))

from theme import base  # noqa: E402
from tools._spec import Tool  # noqa: E402


def load_site() -> dict:
    with (ROOT / "site.json").open(encoding="utf-8") as f:
        site = json.load(f)
    for key in ("name", "description", "base_url"):
        if not site.get(key):
            raise SystemExit(f"site.json の {key} を設定してください")
    return site


def load_tools() -> list:
    """tools/ 配下のモジュールから Tool を集める。"""
    import tools as package

    found = []
    for info in pkgutil.iter_modules(package.__path__):
        if info.name.startswith("_"):
            continue
        module = importlib.import_module(f"tools.{info.name}")
        for value in vars(module).values():
            if isinstance(value, Tool):
                found.append(value)

    slugs = [t.slug for t in found]
    duplicated = {s for s in slugs if slugs.count(s) > 1}
    if duplicated:
        raise SystemExit(f"slug が重複しています: {duplicated}")

    found.sort(key=lambda t: (t.category, t.slug))
    return found


def write(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def sitemap(site: dict, all_tools: list) -> str:
    base_url = site["base_url"].rstrip("/")
    today = datetime.now().strftime("%Y-%m-%d")
    urls = [(base_url + "/", today)]
    urls += [(base_url + t.url_path, t.updated or today) for t in all_tools]
    body = "".join(
        f"  <url><loc>{loc}</loc><lastmod>{mod}</lastmod></url>\n"
        for loc, mod in urls)
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
            f"{body}</urlset>\n")


def robots(site: dict) -> str:
    return ("User-agent: *\nAllow: /\n\n"
            f"Sitemap: {site['base_url'].rstrip('/')}/sitemap.xml\n")


def build() -> dict:
    site = load_site()
    all_tools = load_tools()

    if DIST.exists():
        shutil.rmtree(DIST)
    DIST.mkdir(parents=True)

    for tool in all_tools:
        write(DIST / tool.slug / "index.html",
              base.render_tool(tool, site, all_tools))

    write(DIST / "index.html", base.render_index(site, all_tools))
    write(DIST / "sitemap.xml", sitemap(site, all_tools))
    write(DIST / "robots.txt", robots(site))
    # GitHub Pages が _ 始まりのパスを無視しないようにする
    write(DIST / ".nojekyll", "")

    shutil.copy(ROOT / "theme" / "style.css", DIST / "style.css")
    shutil.copy(ROOT / "theme" / "app.js", DIST / "app.js")

    return {"tools": all_tools, "site": site}


def main():
    parser = argparse.ArgumentParser(description="ツールサイトをビルドする")
    parser.add_argument("--serve", action="store_true",
                        help="ビルド後にローカルサーバーで確認する")
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()

    result = build()
    tools = result["tools"]

    print(f"\n{'='*62}")
    print(f"  ビルド完了  {len(tools)} ツール → {DIST}")
    print(f"{'='*62}")
    current = None
    for t in tools:
        if t.category != current:
            current = t.category
            print(f"\n■ {current}")
        mark = "PR" if t.has_affiliate else "  "
        print(f"  [{mark}] {t.url_path:<24} {t.title}")
    without = [t for t in tools if not t.has_affiliate]
    print(f"\n{'-'*62}")
    if without:
        print(f"  収益導線が未設定のツールが {len(without)} 件あります:")
        for t in without:
            print(f"    - {t.slug}")
        print("  広告だけでは分岐点に届きません。作る前に導線を決めてください。")
    else:
        print("  全ツールに収益導線とPR表記が入っています。")
    print(f"{'='*62}")

    if args.serve:
        import http.server
        import socketserver
        import os
        os.chdir(DIST)
        handler = http.server.SimpleHTTPRequestHandler
        with socketserver.TCPServer(("", args.port), handler) as httpd:
            print(f"\n  http://localhost:{args.port}/ で確認できます（Ctrl+C で終了）")
            httpd.serve_forever()


if __name__ == "__main__":
    main()
