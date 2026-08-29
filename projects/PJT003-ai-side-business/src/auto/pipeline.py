"""成果物の自動生成パイプライン。

  生成 → 検品 → 修正 → 再検品

修正を無制限に回すと原価が跳ねるので、既定は1回まで。
それでも合格しない場合は「要確認」として人に上げる。設計上そこだけ人が見る。
"""
import time

from .. import llm
from . import qa

MAX_REVISIONS = 1


def generate(service, input_text: str, options: str = "") -> str:
    """サービス定義に沿って成果物を作る。"""
    prompt = service.template.format(
        input=input_text.strip(),
        options=f"## 追加の指定\n{options.strip()}" if options.strip() else "",
    )
    return llm.ask(
        prompt,
        system=service.system,
        max_tokens=service.max_tokens,
        effort="high",
        cache_system=True,   # 同じサービスを連続処理するときに原価が下がる
    )


REVISE_SYSTEM = """あなたは納品物の修正担当です。指摘された点だけを直します。

守ること:
- 指摘されていない箇所は変えない
- 修正後の完成品を全文で出力する。差分や「修正しました」等の説明は書かない"""

REVISE_PROMPT = """次の納品物を、指摘に従って修正してください。

## 元の依頼
{request}

## 現在の納品物
{output}

## 検品での指摘
{issues}

## 出力
修正後の全文（前置きなし）"""


def revise(service, text: str, request: str, issues: str) -> str:
    return llm.ask(
        REVISE_PROMPT.format(request=request[:4000], output=text, issues=issues),
        system=REVISE_SYSTEM,
        max_tokens=service.max_tokens,
        effort="high",
    )


def run(service, input_text: str, options: str = "",
        max_revisions: int = MAX_REVISIONS, use_ai_qa: bool = True,
        verbose: bool = True) -> dict:
    """生成から検品・修正までを実行し、結果一式を返す。"""
    started = time.time()
    request = f"{service.name}\n\n{input_text[:2000]}\n{options}".strip()

    with llm.meter() as usage:
        if verbose:
            print(f"  [1/3] {service.output_name}を生成中...")
        output = generate(service, input_text, options)

        if verbose:
            print(f"  [2/3] 検品中...（{len(output):,}文字）")
        result = qa.check(output, service, request, use_ai=use_ai_qa)

        revisions = 0
        while result["verdict"] != "合格" and revisions < max_revisions:
            revisions += 1
            issues = qa.issues_text(result)
            if verbose:
                print(f"  [3/3] 指摘 {len(issues.splitlines())} 件を修正中...（{revisions}回目）")
            output = revise(service, output, request, issues)
            result = qa.check(output, service, request, use_ai=use_ai_qa)

        if verbose and revisions == 0:
            print("  [3/3] 修正不要")

    return {
        "output": output,
        "qa": result,
        "revisions": revisions,
        "usage": usage.to_dict(),
        "cost_jpy": round(usage.cost_jpy(), 2),
        "elapsed_sec": round(time.time() - started, 1),
        "chars": len(output),
        "needs_human": result["verdict"] != "合格",
    }
