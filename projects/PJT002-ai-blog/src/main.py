import os
import sys

if sys.stdin.encoding != "utf-8":
    sys.stdin.reconfigure(encoding="utf-8")
if sys.stdout.encoding != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

from datetime import datetime
from pathlib import Path

from dotenv import load_dotenv

_project_root = Path(__file__).parent.parent
load_dotenv(_project_root / ".env")

if not os.getenv("ANTHROPIC_API_KEY"):
    print("エラー: ANTHROPIC_API_KEY が設定されていません。.env ファイルを確認してください。")
    sys.exit(1)

from generator import generate_article


def main():
    print("=== AIブログ記事ジェネレーター ===\n")

    theme = input("テーマを入力してください: ").strip()
    if not theme:
        print("テーマが入力されていません。")
        sys.exit(1)

    keywords_input = input("キーワードをカンマ区切りで入力してください（省略可）: ").strip()
    keywords = [k.strip() for k in keywords_input.split(",") if k.strip()] if keywords_input else None

    print("\n記事を生成中...\n")
    print("-" * 50)

    article = generate_article(theme, keywords)

    print("-" * 50)

    output_dir = Path(__file__).parent.parent / "output"
    output_dir.mkdir(exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    safe_theme = "".join(c if c.isalnum() or c in "-_" else "_" for c in theme)[:30]
    filename = f"{timestamp}_{safe_theme}.md"
    filepath = output_dir / filename

    filepath.write_text(article, encoding="utf-8")
    print(f"\n記事を保存しました: {filepath}")


if __name__ == "__main__":
    main()
