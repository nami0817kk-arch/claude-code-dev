import anthropic


def generate_article(theme: str, keywords: list[str] | None = None) -> str:
    client = anthropic.Anthropic()

    keyword_section = ""
    if keywords:
        keyword_section = f"\nキーワード: {', '.join(keywords)}"

    prompt = f"""以下のテーマでブログ記事を書いてください。

テーマ: {theme}{keyword_section}

要件:
- Markdown形式で書く
- 見出し（#, ##, ###）を適切に使用する
- 読者が理解しやすい構成にする
- 1500〜3000文字程度
- 導入、本文（複数セクション）、まとめの構成にする"""

    full_text = ""
    with client.messages.stream(
        model="claude-opus-4-8",
        max_tokens=4096,
        thinking={"type": "adaptive"},
        messages=[{"role": "user", "content": prompt}],
    ) as stream:
        for text in stream.text_stream:
            print(text, end="", flush=True)
            full_text += text

    print()  # 改行
    return full_text
