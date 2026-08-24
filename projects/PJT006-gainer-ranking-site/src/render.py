"""data/*.json を読み込み、Jinja2 テンプレートから output/ に静的HTMLを生成する。"""
import json
import shutil
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

_ROOT = Path(__file__).resolve().parent.parent
_TEMPLATES_DIR = _ROOT / "templates"
_DATA_DIR = _ROOT / "data"
_OUTPUT_DIR = _ROOT / "output"

_env = Environment(loader=FileSystemLoader(str(_TEMPLATES_DIR)))


def _load_all_days() -> list[dict]:
    """data/YYYY-MM-DD.json を全て読み込み、rec_date 降順（新しい順）で返す。"""
    days = []
    for path in _DATA_DIR.glob("????-??-??.json"):
        with open(path, encoding="utf-8") as f:
            days.append(json.load(f))
    days.sort(key=lambda d: d["rec_date"], reverse=True)
    return days


def build_all() -> None:
    """output/ を作り直し、当日ページ・アーカイブ・固定ページを全て生成する。"""
    if _OUTPUT_DIR.exists():
        shutil.rmtree(_OUTPUT_DIR)
    _OUTPUT_DIR.mkdir(parents=True)
    (_OUTPUT_DIR / "archive").mkdir()

    days = _load_all_days()
    if not days:
        raise RuntimeError("data/ にランキングJSONが1件もありません。先に build_site.py でデータを取得してください。")

    latest = days[0]

    # 本日（最新日）のトップページ
    tmpl = _env.get_template("index.html")
    (_OUTPUT_DIR / "index.html").write_text(
        tmpl.render(base_url="", rec_date=latest["rec_date"], rows=latest["rows"]),
        encoding="utf-8",
    )

    # 過去日ページ（archive/YYYY-MM-DD.html）
    day_tmpl = _env.get_template("day.html")
    for day in days:
        html = day_tmpl.render(base_url="../", rec_date=day["rec_date"], rows=day["rows"])
        (_OUTPUT_DIR / "archive" / f"{day['rec_date']}.html").write_text(html, encoding="utf-8")

    # アーカイブ一覧（archive/index.html）
    archive_tmpl = _env.get_template("archive.html")
    (_OUTPUT_DIR / "archive" / "index.html").write_text(
        archive_tmpl.render(base_url="../", dates=[d["rec_date"] for d in days]),
        encoding="utf-8",
    )

    # 固定ページ
    for name in ("about.html", "privacy.html"):
        tmpl = _env.get_template(name)
        (_OUTPUT_DIR / name).write_text(tmpl.render(base_url=""), encoding="utf-8")

    print(f"  output/ を生成しました（{len(days)}日分）")
