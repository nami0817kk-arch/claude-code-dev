"""営業文・提案文の生成。

最初の1件を取るところが最大の壁なので、
「そのまま送れる文面」を出すことに絞る。
"""
from . import llm, store

NAME = "proposals"

KINDS = {
    "apply":   "クラウドソーシングの提案文（案件への応募）",
    "dm":      "見込み客への直接メッセージ（SNS・メール）",
    "profile": "プロフィール文（クラウドソーシング・SNSの自己紹介）",
    "service": "サービス紹介文（ココナラ等の商品ページ）",
    "followup": "返信が無い相手への追いかけ連絡",
}

SYSTEM = """あなたは日本のクラウドソーシング・営業文のコピーライターです。

守ること:
- 相手の手間を減らす書き方をする。長い自分語りは書かない
- 実績が無い段階でも、代わりに出せるもの（サンプル・試作・返金保証）で信頼を作る
- 誇張や虚偽の実績は絶対に書かない。無いものは「これから作る」と書く
- 敬体で、装飾記号を多用しない。そのままコピーして送れる文面にする"""

PROMPT = """{kind}を作成してください。

## 送る人のプロフィール
{profile}

## 提供するサービス
{service}

## 相手・案件の情報
{context}

## 出力形式（JSON オブジェクトのみ）
- subject: 件名・書き出しの一行（無い形式の場合は空文字）
- body: 本文（そのまま送れる完成文。400文字以内）
- variants: 書き出しの別案の配列（2個）
- checklist: 送る前に確認すべきことの配列（3個）
- ng: この文面でやってはいけないことの配列（2個）
"""


def generate(kind: str, prof: dict, service: str, context: str = "") -> dict:
    from . import profile as profile_mod

    result = llm.ask_json(
        PROMPT.format(
            kind=KINDS.get(kind, KINDS["apply"]),
            profile=profile_mod.summary_text(prof),
            service=service or "未設定",
            context=context or "特に指定なし（一般的な相手を想定）",
        ),
        system=SYSTEM,
        max_tokens=3000,
    )
    result["kind"] = kind
    result["service"] = service
    result["created_at"] = store.now()

    saved = store.load(NAME, [])
    saved.append(result)
    store.save(NAME, saved[-30:])   # 直近 30 件だけ残す
    return result


def print_proposal(p: dict):
    print(f"\n{'='*70}")
    print(f"  {KINDS.get(p.get('kind'), '提案文')}")
    print(f"{'='*70}")
    if p.get("subject"):
        print(f"\n件名: {p['subject']}")
    print()
    for line in p.get("body", "").split("\n"):
        print(f"  {line}")

    if p.get("variants"):
        print("\n【書き出しの別案】")
        for v in p["variants"]:
            print(f"  ・{v}")

    print("\n【送る前の確認】")
    for c in p.get("checklist", []):
        print(f"  □ {c}")

    if p.get("ng"):
        print("\n【やってはいけないこと】")
        for n in p["ng"]:
            print(f"  × {n}")
    print(f"\n{'='*70}")
