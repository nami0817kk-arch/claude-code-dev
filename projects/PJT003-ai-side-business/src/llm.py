"""Claude API の共通ラッパー。

自動化で回すことが前提なので、次の3点を担う。

- 使用トークンの計測（1件あたりの原価を出すため。src/auto/cost.py が使う）
- 構造化出力（JSON スキーマを渡せば形式が保証される）
- API キー / ライブラリが無い場合に日本語のわかりやすいエラーを返す
"""
import json
import os
import re
from contextlib import contextmanager

# 既定は最上位モデル。費用を抑えたい場合のみ .env の CLAUDE_MODEL で下げる。
DEFAULT_MODEL = os.getenv("CLAUDE_MODEL", "claude-opus-5")
DEFAULT_MAX_TOKENS = 4000

# 1M トークンあたりの単価（USD）。Anthropic 公式 API のレート。
PRICING = {
    "claude-fable-5":  {"input": 10.00, "output": 50.00},
    "claude-opus-5":   {"input":  5.00, "output": 25.00},
    "claude-opus-4-8": {"input":  5.00, "output": 25.00},
    "claude-sonnet-5": {"input":  2.00, "output": 10.00},
    "claude-haiku-4-5": {"input": 1.00, "output":  5.00},
}
# キャッシュ読み出しは入力単価の約 1/10、キャッシュ書き込みは約 1.25 倍
CACHE_READ_RATE = 0.10
CACHE_WRITE_RATE = 1.25

USD_JPY = float(os.getenv("USD_JPY", "155"))

# 拒否時に別モデルへ自動フォールバックする beta 機能
FALLBACK_BETA = "server-side-fallback-2026-07-01"
_fallback_supported = True   # 一度 400 が返ったら以降は使わない


class LLMError(RuntimeError):
    """Claude 呼び出しに関する例外。メッセージはそのまま利用者に見せる。"""


# ---------------------------------------------------------------- 使用量計測

class Usage:
    """トークン使用量の累計と、そこから求めた原価。"""

    def __init__(self, model: str = DEFAULT_MODEL):
        self.model = model
        self.calls = 0
        self.input_tokens = 0
        self.output_tokens = 0
        self.cache_read_tokens = 0
        self.cache_write_tokens = 0

    def add(self, usage, model: str = None):
        """API レスポンスの usage を加算する。"""
        self.calls += 1
        if model:
            self.model = model
        self.input_tokens += getattr(usage, "input_tokens", 0) or 0
        self.output_tokens += getattr(usage, "output_tokens", 0) or 0
        self.cache_read_tokens += getattr(usage, "cache_read_input_tokens", 0) or 0
        self.cache_write_tokens += getattr(usage, "cache_creation_input_tokens", 0) or 0

    def merge(self, other: "Usage"):
        self.calls += other.calls
        self.input_tokens += other.input_tokens
        self.output_tokens += other.output_tokens
        self.cache_read_tokens += other.cache_read_tokens
        self.cache_write_tokens += other.cache_write_tokens
        return self

    @property
    def total_tokens(self) -> int:
        return (self.input_tokens + self.output_tokens
                + self.cache_read_tokens + self.cache_write_tokens)

    def cost_usd(self) -> float:
        rate = PRICING.get(self.model, PRICING["claude-opus-5"])
        return (
            self.input_tokens * rate["input"]
            + self.cache_read_tokens * rate["input"] * CACHE_READ_RATE
            + self.cache_write_tokens * rate["input"] * CACHE_WRITE_RATE
            + self.output_tokens * rate["output"]
        ) / 1_000_000

    def cost_jpy(self) -> float:
        return self.cost_usd() * USD_JPY

    def to_dict(self) -> dict:
        return {
            "model": self.model,
            "calls": self.calls,
            "input_tokens": self.input_tokens,
            "output_tokens": self.output_tokens,
            "cache_read_tokens": self.cache_read_tokens,
            "cache_write_tokens": self.cache_write_tokens,
            "cost_jpy": round(self.cost_jpy(), 2),
        }

    @classmethod
    def from_dict(cls, data: dict) -> "Usage":
        u = cls(data.get("model", DEFAULT_MODEL))
        u.calls = data.get("calls", 0)
        u.input_tokens = data.get("input_tokens", 0)
        u.output_tokens = data.get("output_tokens", 0)
        u.cache_read_tokens = data.get("cache_read_tokens", 0)
        u.cache_write_tokens = data.get("cache_write_tokens", 0)
        return u


_meter = None   # 計測中の Usage（None なら計測しない）


@contextmanager
def meter(model: str = None):
    """このブロック内の API 呼び出しのトークン使用量を集計する。

        with llm.meter() as usage:
            llm.ask("...")
        print(usage.cost_jpy())
    """
    global _meter
    previous = _meter
    current = Usage(model or DEFAULT_MODEL)
    _meter = current
    try:
        yield current
    finally:
        _meter = previous
        if previous is not None:
            previous.merge(current)


# ---------------------------------------------------------------- API 呼び出し

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

    if not os.getenv("ANTHROPIC_API_KEY"):
        raise LLMError(
            "ANTHROPIC_API_KEY が設定されていません。.env.example を .env にコピーしてキーを記入してください。"
        )
    return anthropic.Anthropic()


def _build_params(prompt, system, max_tokens, model, effort, schema, cache_system):
    """messages.create に渡すパラメータを組み立てる。"""
    params = {
        "model": model or DEFAULT_MODEL,
        "max_tokens": max_tokens,
        "messages": [{"role": "user", "content": prompt}],
        # 4.6 以降は budget_tokens ではなく adaptive を使う
        "thinking": {"type": "adaptive"},
        "output_config": {"effort": effort},
    }
    if system:
        if cache_system:
            # 同じ system を何件も処理するので、プレフィックスをキャッシュして原価を下げる
            params["system"] = [{"type": "text", "text": system,
                                 "cache_control": {"type": "ephemeral"}}]
        else:
            params["system"] = system
    if schema:
        params["output_config"]["format"] = {"type": "json_schema", "schema": schema}
    return params


def _create(client, params):
    """拒否時フォールバック付きで呼ぶ。beta が使えない環境では通常呼び出しに落とす。"""
    global _fallback_supported
    import anthropic

    if _fallback_supported:
        try:
            return client.beta.messages.create(
                betas=[FALLBACK_BETA], fallbacks="default", **params)
        except anthropic.BadRequestError:
            # beta 非対応・パラメータ不許可の環境。以降は通常呼び出しに切り替える。
            _fallback_supported = False
        except (AttributeError, TypeError):
            _fallback_supported = False
    return client.messages.create(**params)


def ask(prompt: str, system: str = "", max_tokens: int = DEFAULT_MAX_TOKENS,
        model: str = None, effort: str = "high", schema: dict = None,
        cache_system: bool = False) -> str:
    """Claude に問い合わせてテキストを返す。使用量は meter() 中なら自動で加算される。

    effort : low / medium / high / xhigh / max（思考の深さと費用のバランス）
    schema : JSON スキーマ。渡すと出力形式が保証される
    """
    # _client() を先に呼ぶ。ライブラリ/キーが無い場合はここで日本語のエラーになる
    client = _client()
    import anthropic

    params = _build_params(prompt, system, max_tokens, model, effort, schema, cache_system)

    try:
        res = _create(client, params)
    except anthropic.AuthenticationError as e:
        raise LLMError("ANTHROPIC_API_KEY が正しくありません。.env を確認してください。") from e
    except anthropic.RateLimitError as e:
        raise LLMError("APIのレート制限に達しました。しばらく待ってから再実行してください。") from e
    except anthropic.APIConnectionError as e:
        raise LLMError("Claude API に接続できませんでした。ネットワークを確認してください。") from e
    except anthropic.APIStatusError as e:
        raise LLMError(f"Claude API がエラーを返しました（{e.status_code}）: {e.message}") from e

    if _meter is not None and getattr(res, "usage", None) is not None:
        _meter.add(res.usage, model=getattr(res, "model", None))

    if getattr(res, "stop_reason", None) == "refusal":
        detail = getattr(res, "stop_details", None)
        reason = getattr(detail, "explanation", "") if detail else ""
        raise LLMError(f"Claude が応答を拒否しました。依頼内容を見直してください。{reason}")

    text = "".join(b.text for b in res.content if b.type == "text").strip()
    if not text:
        raise LLMError("Claude から空の応答が返りました。もう一度実行してみてください。")
    return text


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
             model: str = None, effort: str = "high", schema: dict = None,
             cache_system: bool = False):
    """JSON を返させ、パース済みのオブジェクトを返す。

    schema を渡した場合は API 側で形式が保証されるので、パースはほぼ確実に成功する。
    """
    if not schema:
        system = (system + "\n\n" if system else "") + \
            "出力は必ず有効な JSON のみとし、前後に説明文やコードフェンスを付けないこと。"
    return extract_json(ask(prompt, system=system, max_tokens=max_tokens, model=model,
                           effort=effort, schema=schema, cache_system=cache_system))
