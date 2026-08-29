"""Claude API の共通ラッパー。

- API キー / ライブラリが無い場合は日本語のわかりやすいエラーにする
- JSON を返させる用途が多いので ask_json() でパースまで面倒を見る
"""
import json
import os
import re

DEFAULT_MODEL = os.getenv("CLAUDE_MODEL", "claude-sonnet-5")
DEFAULT_MAX_TOKENS = 4000


class LLMError(RuntimeError):
    """Claude 呼び出しに関する例外。メッセージはそのまま利用者に見せる。"""


def available() -> bool:
    """Claude を呼べる状態かどうか（キーとライブラリの両方が揃っているか）。"""
    if not os.getenv("ANTHROPIC_API_KEY"):
        return False
    try:
        import anthropic  # noqa: F401
    except ImportError:
        return False
    return True


def _client():
    try:
        import anthropic
    except ImportError as e:
        raise LLMError(
            "anthropic ライブラリが見つかりません。`pip install -r requirements.txt` を実行してください。"
        ) from e

    key = os.getenv("ANTHROPIC_API_KEY")
    if not key:
        raise LLMError(
            "ANTHROPIC_API_KEY が設定されていません。.env.example を .env にコピーしてキーを記入してください。"
        )
    return anthropic.Anthropic(api_key=key)


def ask(prompt: str, system: str = "", max_tokens: int = DEFAULT_MAX_TOKENS,
        model: str = None) -> str:
    """Claude に問い合わせてテキストを返す。"""
    client = _client()
    kwargs = {
        "model": model or DEFAULT_MODEL,
        "max_tokens": max_tokens,
        "messages": [{"role": "user", "content": prompt}],
    }
    if system:
        kwargs["system"] = system

    try:
        res = client.messages.create(**kwargs)
    except Exception as e:  # API 側のエラーは種類を問わず日本語で包む
        raise LLMError(f"Claude API 呼び出しに失敗しました: {e}") from e

    return "".join(block.text for block in res.content if block.type == "text").strip()


def extract_json(text: str):
    """Claude の返答から JSON 部分だけを取り出してパースする。"""
    # ```json ... ``` のコードフェンスを剥がす
    fence = re.search(r"```(?:json)?\s*(.+?)\s*```", text, re.DOTALL)
    if fence:
        text = fence.group(1)

    text = text.strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # 前後に説明文が付いている場合、最初の { or [ から最後の } or ] までを試す
    for open_ch, close_ch in (("{", "}"), ("[", "]")):
        start, end = text.find(open_ch), text.rfind(close_ch)
        if start != -1 and end > start:
            try:
                return json.loads(text[start:end + 1])
            except json.JSONDecodeError:
                continue

    raise LLMError("Claude の返答を JSON として解釈できませんでした。もう一度実行してみてください。")


def ask_json(prompt: str, system: str = "", max_tokens: int = DEFAULT_MAX_TOKENS,
             model: str = None):
    """JSON を返させる前提で問い合わせ、パース済みのオブジェクトを返す。"""
    system = (system + "\n\n" if system else "") + \
        "出力は必ず有効な JSON のみとし、前後に説明文やコードフェンスを付けないこと。"
    return extract_json(ask(prompt, system=system, max_tokens=max_tokens, model=model))
