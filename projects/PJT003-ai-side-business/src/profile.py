"""ユーザープロフィール管理。

副業の提案・計画はすべてこのプロフィールを土台にするため、
アイデア生成前に必ず init しておく。
"""
import re

from . import store

NAME = "profile"

# (キー, 表示名, 型, 初期値, 入力時のヒント)
FIELDS = [
    ("skills",        "スキル・得意分野", "list", [],  "カンマ区切り: 例) Excel, Python, 資料作成"),
    ("experience",    "本業・経歴",       "str",  "",  "例) 製造業の生産管理を10年"),
    ("interests",     "興味のある分野",   "list", [],  "カンマ区切り: 例) 教育, 業務効率化"),
    ("hours_per_week", "週の稼働可能時間", "int",  10,  "時間/週"),
    ("target_income", "目標月収(円)",     "int",  50000, "円/月"),
    ("budget",        "初期投資の上限(円)", "int", 30000, "円"),
    ("deadline_months", "目標達成までの期間", "int", 6,   "ヶ月"),
    ("public_face",   "顔出し・実名の可否", "str", "不可", "可 / 不可"),
    ("ng",            "やりたくないこと", "list", [],  "カンマ区切り: 例) 電話営業, 長時間の対面"),
    ("cost_mode",     "AIの課金形態",     "str",  "定額", "定額（サブスク） / 従量（API従量課金）"),
    ("monthly_fee",   "AIの月額(円)",     "int",  0,   "定額の場合の月額。従量なら0"),
]

# 定額なら1件作るごとの追加費用は発生しない。この違いは原価の考え方を根本から変える。
SUBSCRIPTION = "定額"

DEFAULTS = {key: default for key, _, _, default, _ in FIELDS}


def load() -> dict:
    """保存済みプロフィールを返す（未設定項目は初期値で埋める）。"""
    data = dict(DEFAULTS)
    data.update(store.load(NAME, {}))
    return data


def save(data: dict):
    return store.save(NAME, data)


def exists() -> bool:
    return bool(store.load(NAME, {}))


def parse_value(raw: str, kind: str, default):
    """入力文字列を型に合わせて変換する。空入力は既定値を採用。"""
    raw = (raw or "").strip()
    if not raw:
        return default
    if kind == "list":
        return [x.strip() for x in raw.replace("、", ",").split(",") if x.strip()]
    if kind == "int":
        return parse_int(raw, default)
    return raw


def parse_int(raw: str, default: int) -> int:
    """「5万」「50,000円」のような日本語まじりの入力も数値にする。"""
    text = raw.replace(",", "").replace("，", "").replace(" ", "").replace("円", "")
    m = re.fullmatch(r"(\d*(?:\.\d+)?)万(\d*)", text)
    if m:
        man = float(m.group(1) or 1) * 10000
        return int(man + int(m.group(2) or 0))
    digits = "".join(ch for ch in text if ch.isdigit())
    return int(digits) if digits else default


def interactive_init(current: dict = None) -> dict:
    """対話形式でプロフィールを入力させる。Enter で現在値を維持。"""
    current = current or load()
    print("\nAI 副業サポート  プロフィール設定")
    print("（Enter でカッコ内の現在値を維持します）\n")

    data = dict(current)
    for key, label, kind, default, hint in FIELDS:
        now = current.get(key, default)
        shown = ", ".join(now) if isinstance(now, list) else now
        raw = input(f"{label} [{shown}]\n  {hint}\n> ")
        data[key] = parse_value(raw, kind, now)
        print()
    return data


def summary_text(data: dict) -> str:
    """Claude に渡すためのプロフィール要約テキスト。"""
    def j(v):
        return "、".join(v) if isinstance(v, list) else v
    return "\n".join([
        f"- スキル: {j(data['skills']) or '未設定'}",
        f"- 本業・経歴: {data['experience'] or '未設定'}",
        f"- 興味分野: {j(data['interests']) or '未設定'}",
        f"- 週の稼働可能時間: {data['hours_per_week']} 時間",
        f"- 目標月収: {data['target_income']:,} 円",
        f"- 初期投資の上限: {data['budget']:,} 円",
        f"- 目標達成までの期間: {data['deadline_months']} ヶ月",
        f"- 顔出し・実名: {data['public_face']}",
        f"- やりたくないこと: {j(data['ng']) or '特になし'}",
    ])


def is_subscription(data: dict = None) -> bool:
    """AI の課金が定額制かどうか。原価計算の分岐に使う。"""
    data = data or load()
    return data.get("cost_mode", SUBSCRIPTION) == SUBSCRIPTION


def monthly_fee(data: dict = None) -> int:
    data = data or load()
    return data.get("monthly_fee", 0) if is_subscription(data) else 0


def print_profile(data: dict):
    print(f"\n{'='*70}")
    print("  プロフィール")
    print(f"{'='*70}")
    for key, label, kind, default, _ in FIELDS:
        val = data.get(key, default)
        if isinstance(val, list):
            val = "、".join(val) or "-"
        elif kind == "int":
            val = f"{val:,}"
        print(f"  {label:<20}: {val}")
    print(f"{'='*70}")
