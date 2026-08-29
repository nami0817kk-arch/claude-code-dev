"""納品前の品質チェック。

自動化の弱点は「誰も見ないまま納品されること」なので、
機械チェック（確実）と AI レビュー（観点）の二段で止める。
"""
import re

from .. import llm
from . import services

PASS_SCORE = 80   # この点数未満なら修正に回す


def mechanical(text: str, service) -> list:
    """AI を使わずに判定できる不備を返す。ここは絶対に見逃さない。"""
    issues = []
    length = len(text)

    if length < service.min_chars:
        issues.append(f"文字数不足: {length:,}文字（基準 {service.min_chars:,}文字以上）")
    if length > service.max_chars:
        issues.append(f"文字数超過: {length:,}文字（基準 {service.max_chars:,}文字以下）")

    for word in service.required:
        if word not in text:
            issues.append(f"必須項目が欠落: 「{word}」が見つからない")

    for word in services.FORBIDDEN:
        if word in text:
            issues.append(f"表現の問題: 「{word}」は景品表示法上のリスクがある")

    # AI が付けがちな前置き・言い訳を検出する
    for pattern, label in [
        (r"^(以下|こちら)が", "前置きが残っている（納品物は本文から始める）"),
        (r"(承知しました|かしこまりました)", "返事が本文に混ざっている"),
        (r"\[?(ここに|○○を記入|XXX|TODO)\]?", "プレースホルダが残っている"),
        (r"申し訳(ありません|ございません)", "謝罪文が本文に混ざっている"),
    ]:
        if re.search(pattern, text, re.MULTILINE):
            issues.append(label)

    return issues


SYSTEM = """あなたは納品物の検品担当者です。制作者ではなく、受け取る側の目で見ます。

守ること:
- 良い点を探さない。直すべき点だけを挙げる
- 「もう少し詳しく」のような曖昧な指摘はせず、どこをどう直すかまで書く
- 依頼内容を満たしていない場合は、それを最優先で指摘する"""

REVIEW_SCHEMA = {
    "type": "object",
    "properties": {
        "score": {"type": "integer", "minimum": 0, "maximum": 100},
        "issues": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "point": {"type": "string"},
                    "problem": {"type": "string"},
                    "fix": {"type": "string"},
                    "severity": {"type": "string", "enum": ["高", "中", "低"]},
                },
                "required": ["point", "problem", "fix", "severity"],
                "additionalProperties": False,
            },
        },
        "verdict": {"type": "string", "enum": ["合格", "要修正"]},
        "comment": {"type": "string"},
    },
    "required": ["score", "issues", "verdict", "comment"],
    "additionalProperties": False,
}

PROMPT = """次の納品物を検品してください。

## 依頼内容
{request}

## 納品物
{output}

## 採点の観点
{points}

## 判定基準
- score: 0〜100点。そのまま客に出せる状態なら80点以上
- issues: 直すべき点。severity は 高（このままでは出せない）/ 中（直したい）/ 低（好みの範囲）
- verdict: 80点以上かつ severity「高」が無ければ 合格、それ以外は 要修正"""


def review(text: str, service, request: str) -> dict:
    """AI に検品させ、点数と指摘を返す。"""
    result = llm.ask_json(
        PROMPT.format(
            request=request[:4000],
            output=text[:12000],
            points="\n".join(f"- {p}" for p in service.qa_points),
        ),
        system=SYSTEM,
        schema=REVIEW_SCHEMA,
        effort="medium",     # 検品は生成ほど深く考えなくてよい
        max_tokens=3000,
    )
    return result


def check(text: str, service, request: str, use_ai: bool = True) -> dict:
    """機械チェックと AI レビューを合わせた最終判定。"""
    mech = mechanical(text, service)
    result = {"mechanical": mech, "score": 100, "issues": [],
              "verdict": "合格", "comment": ""}

    if use_ai:
        try:
            ai = review(text, service, request)
            result.update(ai)
        except llm.LLMError as e:
            # レビューが失敗しても機械チェックの結果は活かす
            result["comment"] = f"AIレビューをスキップしました（{e}）"

    # 機械チェックに引っかかったら、AI が何点を付けようと不合格
    if mech:
        result["verdict"] = "要修正"
        result["score"] = min(result["score"], 60)

    return result


def issues_text(result: dict) -> str:
    """修正指示としてプロンプトに埋め込める形にまとめる。"""
    lines = [f"- {m}" for m in result.get("mechanical", [])]
    for i in result.get("issues", []):
        if i.get("severity") in ("高", "中"):
            lines.append(f"- [{i.get('severity')}] {i.get('point')}: "
                         f"{i.get('problem')} → {i.get('fix')}")
    return "\n".join(lines)


def print_qa(result: dict):
    mark = "合格" if result.get("verdict") == "合格" else "要修正"
    print(f"  品質チェック: {mark}  {result.get('score', 0)}点")
    for m in result.get("mechanical", []):
        print(f"    × {m}")
    for i in result.get("issues", []):
        print(f"    [{i.get('severity','-')}] {i.get('point','')}: {i.get('problem','')}")
    if result.get("comment"):
        print(f"    所見: {result['comment']}")
