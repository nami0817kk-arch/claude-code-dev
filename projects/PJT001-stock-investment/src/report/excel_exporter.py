from pathlib import Path
from datetime import datetime
import openpyxl
from openpyxl.styles import (
    PatternFill, Font, Alignment, Border, Side
)
from openpyxl.utils import get_column_letter

OUTPUT_DIR = Path(__file__).parent.parent.parent / "data" / "reports"


def _thin_border() -> Border:
    thin = Side(style="thin", color="CCCCCC")
    return Border(left=thin, right=thin, top=thin, bottom=thin)


def export(result: dict) -> Path:
    """
    selector.pick_from_* の返り値 (dict) を Excel に保存して
    ファイルパスを返す。
    """
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    ts    = datetime.now().strftime("%Y%m%d_%H%M%S")
    flow  = "news" if "ニュース" in result.get("flow", "") else "screen"
    path  = OUTPUT_DIR / f"pick_{flow}_{ts}.xlsx"

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "投資推奨"

    # ── カラー定義 ──────────────────────────────
    C_HEADER   = "1F4E79"   # 濃紺
    C_SUBHEAD  = "2E75B6"   # 青
    C_RANK1    = "FFF2CC"   # 薄黄（1位）
    C_RANK2    = "DEEAF1"   # 薄青（2位）
    C_RANK3    = "E2EFDA"   # 薄緑（3位）
    C_DEFAULT  = "F5F5F5"   # 薄グレー

    RANK_COLORS = {1: C_RANK1, 2: C_RANK2, 3: C_RANK3}

    def fill(hex_color: str) -> PatternFill:
        return PatternFill("solid", fgColor=hex_color)

    def hfont(bold=False, color="FFFFFF", size=11) -> Font:
        return Font(bold=bold, color=color, size=size, name="游ゴシック")

    def cell(ws, row, col, value, bold=False, bg=None, fg="000000",
             align="left", size=11, wrap=False):
        c = ws.cell(row=row, column=col, value=value)
        c.font      = Font(bold=bold, color=fg, size=size, name="游ゴシック")
        c.alignment = Alignment(horizontal=align, vertical="center",
                                wrap_text=wrap)
        c.border    = _thin_border()
        if bg:
            c.fill = fill(bg)
        return c

    # ── タイトル行 ───────────────────────────────
    ws.merge_cells("A1:H1")
    title_cell = ws["A1"]
    title_cell.value     = f"投資推奨レポート　{result.get('flow','')}　{result.get('market','')}　{result.get('date','')}"
    title_cell.font      = hfont(bold=True, size=14)
    title_cell.fill      = fill(C_HEADER)
    title_cell.alignment = Alignment(horizontal="center", vertical="center")
    ws.row_dimensions[1].height = 30

    # ── ヘッダー行 ──────────────────────────────
    headers = ["順位", "銘柄コード", "銘柄名", "推奨度", "終値", "RSI14", "MACD", "SMA20比", "BB位置", "推奨理由"]
    for col, h in enumerate(headers, 1):
        c = ws.cell(row=2, column=col, value=h)
        c.font      = hfont(bold=True, size=10)
        c.fill      = fill(C_SUBHEAD)
        c.alignment = Alignment(horizontal="center", vertical="center")
        c.border    = _thin_border()
    ws.row_dimensions[2].height = 20

    # ── ランキング行 ─────────────────────────────
    for i, item in enumerate(result.get("rankings", []), start=3):
        rank   = item.get("rank", i - 2)
        bg     = RANK_COLORS.get(rank, C_DEFAULT)

        cell(ws, i, 1,  rank,                bold=True,  bg=bg, align="center")
        cell(ws, i, 2,  item.get("ticker",""),            bg=bg, align="center")
        cell(ws, i, 3,  item.get("name",""),              bg=bg)
        cell(ws, i, 4,  item.get("stars",""),             bg=bg, align="center")
        cell(ws, i, 5,  item.get("close"),                bg=bg, align="right")
        cell(ws, i, 6,  item.get("RSI14"),                bg=bg, align="center")
        cell(ws, i, 7,  item.get("MACD方向",""),          bg=bg, align="center")
        cell(ws, i, 8,  item.get("SMA20比",""),           bg=bg, align="center")
        cell(ws, i, 9,  item.get("BB位置",""),            bg=bg, align="center")
        cell(ws, i, 10, item.get("reason",""),            bg=bg, wrap=True)
        ws.row_dimensions[i].height = 45

    # ── 総評 ────────────────────────────────────
    summary_row = len(result.get("rankings", [])) + 4
    ws.merge_cells(f"A{summary_row}:J{summary_row}")
    c = ws.cell(row=summary_row, column=1, value="【総評】")
    c.font  = Font(bold=True, size=10, color="FFFFFF", name="游ゴシック")
    c.fill  = fill(C_SUBHEAD)
    c.alignment = Alignment(horizontal="left", vertical="center")
    ws.row_dimensions[summary_row].height = 18

    summary_row += 1
    ws.merge_cells(f"A{summary_row}:J{summary_row}")
    c = ws.cell(row=summary_row, column=1, value=result.get("summary", ""))
    c.font      = Font(size=10, name="游ゴシック")
    c.alignment = Alignment(horizontal="left", vertical="center", wrap_text=True)
    c.border    = _thin_border()
    ws.row_dimensions[summary_row].height = 60

    # ── 列幅調整 ────────────────────────────────
    col_widths = [6, 12, 18, 12, 10, 8, 8, 10, 10, 50]
    for col, w in enumerate(col_widths, 1):
        ws.column_dimensions[get_column_letter(col)].width = w

    ws.freeze_panes = "A3"

    wb.save(path)
    return path
