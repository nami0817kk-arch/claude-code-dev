"""見積もり・価格設定の計算。

安く受けすぎて消耗するのを防ぐため、
「手取りで希望時給が残る価格」を逆算して提示する。
"""
import math

from . import llm

# クラウドソーシング系のシステム手数料の目安
PLATFORM_FEE = {
    "direct": 0.00,        # 直接契約
    "crowdworks": 0.22,    # クラウドワークス（〜10万円の帯）
    "lancers": 0.165,      # ランサーズ
    "coconala": 0.22,      # ココナラ
}

# 提示する 3 プランの係数と目安
PLANS = [
    ("ライト", 0.7, "範囲を絞った最小構成"),
    ("標準",   1.0, "想定どおりの内容"),
    ("しっかり", 1.5, "追加要望・優先対応込み"),
]


def round_price(value: float) -> int:
    """提示しやすいよう、桁に応じて丸める。"""
    if value < 10000:
        unit = 500
    elif value < 100000:
        unit = 1000
    else:
        unit = 5000
    return int(math.ceil(value / unit) * unit)


def estimate(hours: float, hourly: int, difficulty: int = 3, revisions: int = 1,
             rush: bool = False, expenses: int = 0, platform: str = "direct") -> dict:
    """見積もり金額を算出する。

    hours     : 実作業の想定時間
    hourly    : 手元に残したい時給
    difficulty: 難易度 1〜5（3 が標準）
    revisions : 想定修正回数
    rush      : 特急対応かどうか
    expenses  : 立て替え経費（API 利用料・素材費など）
    platform  : 手数料を差し引くプラットフォーム
    """
    difficulty = max(1, min(5, difficulty))
    diff_rate = 1.0 + (difficulty - 3) * 0.15          # 難易度で ±30%
    revision_hours = hours * 0.2 * max(0, revisions)   # 修正1回につき20%の工数
    rush_rate = 1.3 if rush else 1.0

    work_hours = (hours + revision_hours) * diff_rate
    labor = work_hours * hourly * rush_rate
    net_needed = labor + expenses                       # 手取りで確保したい額

    fee_rate = PLATFORM_FEE.get(platform, 0.0)
    gross = net_needed / (1 - fee_rate) if fee_rate < 1 else net_needed

    plans = []
    for name, factor, note in PLANS:
        # 提示額に合わせて対応範囲（=工数）も増減させる。時給を守るための建て付け。
        plan_hours = work_hours * factor
        price = round_price(gross * factor)
        fee = round(price * fee_rate)
        plans.append({
            "name": name,
            "price": price,
            "net": price - fee,
            "fee": fee,
            "hours": round(plan_hours, 1),
            "note": note,
            "effective_hourly": round((price - fee - expenses) / plan_hours) if plan_hours else 0,
        })

    return {
        "hours": round(hours, 1),
        "work_hours": round(work_hours, 1),
        "hourly": hourly,
        "difficulty": difficulty,
        "revisions": revisions,
        "rush": rush,
        "expenses": expenses,
        "platform": platform,
        "fee_rate": fee_rate,
        "floor": round_price(gross),      # これ以下では受けない下限
        "plans": plans,
    }


def print_estimate(e: dict):
    rush = "あり" if e["rush"] else "なし"
    print(f"\n{'='*70}")
    print("  見積もり")
    print(f"{'='*70}")
    print(f"  実作業 {e['hours']}h  →  修正・難易度込み {e['work_hours']}h")
    print(f"  希望時給 {e['hourly']:,}円 / 難易度 {e['difficulty']}/5 / 修正 {e['revisions']}回 / 特急 {rush}")
    if e["expenses"]:
        print(f"  経費 {e['expenses']:,}円")
    print(f"  手数料 {e['platform']}（{e['fee_rate']*100:.1f}%）")
    print(f"\n{'-'*70}")
    print(f"  {'プラン':<8}{'提示額':>12}{'手取り':>12}{'実質時給':>12}{'工数':>8}   内容")
    print(f"{'-'*70}")
    for p in e["plans"]:
        print(f"  {p['name']:<8}{p['price']:>11,}円{p['net']:>11,}円{p['effective_hourly']:>11,}円"
              f"{p['hours']:>7g}h   {p['note']}")
    print(f"{'-'*70}")
    print(f"\n  受注ライン: {e['floor']:,}円（標準の対応範囲での下限）")
    print("  ← これを下回る額しか出ない依頼は、断るか対応範囲を削って調整する")
    print(f"{'='*70}")


ADVICE_SYSTEM = """あなたは日本のフリーランス・副業ワーカー向けの価格交渉アドバイザーです。
値下げ要求への具体的な返し方まで含めて助言します。安売りを勧めてはいけません。"""

ADVICE_PROMPT = """次の見積もりについて、提示の仕方をアドバイスしてください。

案件: {work}
提示額: 標準プラン {price:,}円（実質時給 {hourly:,}円 / 想定 {hours}h）
受注ライン: {floor:,}円

## 出力形式（JSON オブジェクトのみ）
- message: クライアントに送る見積もり提示の文面（200文字程度・敬体）
- justification: 価格の根拠として伝えるべき点の配列（2〜3個）
- negotiation: 値下げを求められた時の返し方の配列（2〜3個。「値段は下げず範囲を削る」方向で）
- upsell: 追加提案できるオプションの配列（2個。各要素は item と price）
"""


def advice(e: dict, work: str) -> dict:
    std = next(p for p in e["plans"] if p["name"] == "標準")
    return llm.ask_json(
        ADVICE_PROMPT.format(
            work=work, price=std["price"], hourly=std["effective_hourly"],
            hours=e["work_hours"], floor=e["floor"],
        ),
        system=ADVICE_SYSTEM,
        max_tokens=2000,
    )


def print_advice(a: dict):
    print("\n【見積もり提示の文面】")
    print(f"  {a.get('message','')}")
    print("\n【価格の根拠として伝えること】")
    for x in a.get("justification", []):
        print(f"  ・{x}")
    print("\n【値下げを求められたら】")
    for x in a.get("negotiation", []):
        print(f"  ・{x}")
    if a.get("upsell"):
        print("\n【追加提案できるオプション】")
        for x in a["upsell"]:
            print(f"  ・{x.get('item','')}  {x.get('price','')}")
    print(f"\n{'='*70}")
