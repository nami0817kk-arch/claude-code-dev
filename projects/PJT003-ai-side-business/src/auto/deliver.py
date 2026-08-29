"""納品ファイルの出力。"""
import re
from pathlib import Path

DELIVER_DIR = Path(__file__).resolve().parent.parent.parent / "deliverables"


def safe_name(text: str, limit: int = 30) -> str:
    """ファイル名に使える形にする。"""
    text = re.sub(r'[\\/:*?"<>|\s]+', "_", (text or "").strip())
    return text[:limit].strip("_") or "無題"


def write(job: dict, content: str, extension: str = "md") -> Path:
    """納品物をファイルに書き出し、パスを返す。"""
    DELIVER_DIR.mkdir(parents=True, exist_ok=True)
    name = (f"{job.get('created_at', '')[:10]}_{job.get('id', 0):03d}_"
            f"{safe_name(job.get('client') or '案件')}_"
            f"{safe_name(job.get('title') or job.get('service', ''))}.{extension}")
    path = DELIVER_DIR / name
    path.write_text(content, encoding="utf-8")
    return path


def cover_note(job: dict, result: dict, service) -> str:
    """納品時に添える一文（そのままメールに貼れる形）。"""
    lines = [
        f"{job.get('client') or 'ご担当者'} 様",
        "",
        f"お世話になっております。ご依頼いただいた{service.name}が完成しましたのでお送りします。",
        "",
        f"■ 納品物: {service.output_name}（{result['chars']:,}文字）",
    ]
    if result["needs_human"]:
        lines += ["", "※ 一部【要確認】と記載した箇所があります。"
                        "情報をいただければ反映のうえ再納品いたします。"]
    lines += [
        "",
        "ご確認のうえ、修正のご希望がありましたらお知らせください。",
        "よろしくお願いいたします。",
    ]
    return "\n".join(lines)
