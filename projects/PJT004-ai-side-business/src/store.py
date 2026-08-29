"""JSON ファイルによるデータ永続化。

data/ 配下に profile.json / ideas.json / tasks.json / revenue.json を置く。
DB を使わないのは「まず動かして続ける」ことを優先するため。
"""
import json
from datetime import datetime
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent.parent / "data"


def _path(name: str) -> Path:
    return DATA_DIR / f"{name}.json"


def load(name: str, default=None):
    """data/<name>.json を読み込む。無ければ default を返す。"""
    path = _path(name)
    if not path.exists():
        return default if default is not None else {}
    try:
        with path.open(encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError:
        # 壊れたファイルで落とさない。退避してから初期値を返す。
        backup = path.with_suffix(f".broken-{datetime.now():%Y%m%d%H%M%S}.json")
        path.rename(backup)
        return default if default is not None else {}


def save(name: str, data) -> Path:
    """data/<name>.json に書き出す。"""
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    path = _path(name)
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    return path


def today() -> str:
    return datetime.now().strftime("%Y-%m-%d")


def now() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M")
