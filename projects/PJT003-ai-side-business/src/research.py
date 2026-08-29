"""選んだアイデアの市場調査・実現性検証。

「やる前に確かめること」を先に潰すためのモジュール。
"""
from . import llm, store

NAME = "research"

SYSTEM = """あなたは日本の小規模ビジネスの立ち上げ支援に詳しい事業コンサルタントです。
楽観的な見通しではなく、実際に売れるかどうかを厳しく検証します。
根拠のない断定はせず、確かめようのない数字は「要検証」と明示してください。"""

PROMPT = """次の副業アイデアについて、市場調査と実現性の検証を行ってください。

## 相談者のプロフィール
{profile}

## 検証するアイデア
名称: {name}
種別: {category}
内容: {summary}
ターゲット: {target}
収益モデル: {revenue_model}
想定単価: {price_range}

## 出力形式（JSON オブジェクトのみ）
- demand: 需要の実態（誰が今どう困っていて、いま金を払っているか。100文字程度）
- personas: 顧客像の配列（2〜3個。各要素は who / pain / budget / where のキーを持つ。where は「その人に会える具体的な場所」）
- competitors: 競合の配列（2〜4個。各要素は name / price / strength / weakness のキーを持つ）
- differentiation: この人ならではの差別化ポイント（配列・2〜3個）
- price_advice: 適正価格の考え方と、最初に提示すべき価格（100文字程度）
- channels: 最初の顧客を取る集客経路の配列（3〜4個。各要素は channel / action / cost のキーを持つ）
- validation: 1週間でできる検証手順の配列（3〜5ステップ。各要素は文字列）
- kill_criteria: 撤退・方針転換の判断基準（「◯週間で△が無ければ見直す」の形。1文）
- legal: 日本での法務・税務・本業の副業規定に関する注意点の配列（2〜3個）
- verdict: 総合判定（"進める" / "条件付きで進める" / "見送り推奨" のいずれか）
- verdict_reason: 判定の理由（80文字程度）
"""


def run(idea: dict, prof: dict) -> dict:
    from . import profile as profile_mod

    result = llm.ask_json(
        PROMPT.format(
            profile=profile_mod.summary_text(prof),
            name=idea.get("name", ""),
            category=idea.get("category", ""),
            summary=idea.get("summary", ""),
            target=idea.get("target", ""),
            revenue_model=idea.get("revenue_model", ""),
            price_range=idea.get("price_range", ""),
        ),
        system=SYSTEM,
        max_tokens=6000,
    )
    result["idea_id"] = idea.get("id")
    result["idea_name"] = idea.get("name")
    result["researched_at"] = store.now()

    saved = store.load(NAME, {})
    saved[str(idea.get("id"))] = result
    store.save(NAME, saved)
    return result


def load(idea_id) -> dict:
    return store.load(NAME, {}).get(str(idea_id))


def print_research(r: dict):
    print(f"\n{'='*70}")
    print(f"  市場調査  [{r.get('idea_id')}] {r.get('idea_name')}")
    print(f"{'='*70}")
    print(f"\n【判定】{r.get('verdict','-')}  — {r.get('verdict_reason','')}")

    print("\n【需要の実態】")
    print(f"  {r.get('demand','')}")

    print("\n【顧客像】")
    for p in r.get("personas", []):
        print(f"  ・{p.get('who','')}")
        print(f"      困りごと: {p.get('pain','')}")
        print(f"      予算    : {p.get('budget','')}")
        print(f"      会える場所: {p.get('where','')}")

    print("\n【競合】")
    for c in r.get("competitors", []):
        print(f"  ・{c.get('name','')}  {c.get('price','')}")
        print(f"      強み: {c.get('strength','')}")
        print(f"      弱み: {c.get('weakness','')}  ← ここを突く")

    print("\n【差別化】")
    for d in r.get("differentiation", []):
        print(f"  ・{d}")

    print("\n【価格】")
    print(f"  {r.get('price_advice','')}")

    print("\n【集客経路】")
    for c in r.get("channels", []):
        print(f"  ・{c.get('channel','')}: {c.get('action','')}  （費用: {c.get('cost','')}）")

    print("\n【1週間の検証手順】")
    for i, v in enumerate(r.get("validation", []), 1):
        print(f"  {i}. {v}")

    print(f"\n【撤退基準】\n  {r.get('kill_criteria','')}")

    print("\n【法務・税務の注意】")
    for l in r.get("legal", []):
        print(f"  ・{l}")
    print(f"\n{'='*70}")
