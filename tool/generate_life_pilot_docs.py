from __future__ import annotations

import re
from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION_START
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
UPDATED = "2026-10-13"

DOCUMENTS = [
    {
        "source": DOCS / "USER_GUIDE_zh-TW.md",
        "output": DOCS / "Life_Pilot_使用者操作說明.docx",
        "subtitle": "功能操作、資料模式、方案額度與個人資料指南",
        "audience": "Life Pilot 一般使用者、合作廠商與管理者",
        "short": "Life Pilot 使用者操作說明",
    },
    {
        "source": DOCS / "DEVELOPER_GUIDE_zh-TW.md",
        "output": DOCS / "Life_Pilot_開發者技術文件.docx",
        "subtitle": "架構、資料安全、部署、維護與法遵技術基準",
        "audience": "Life Pilot 開發、維運、資料庫與資安人員",
        "short": "Life Pilot 開發者技術文件",
    },
    {
        "source": DOCS / "TEST_PLAN_zh-TW.md",
        "output": DOCS / "Life_Pilot_測試計畫與檢查點.docx",
        "subtitle": "功能驗收、回歸測試、資料檢查與上線 Gate",
        "audience": "Life Pilot 測試、開發、產品與上線驗收人員",
        "short": "Life Pilot 測試計畫與檢查點",
    },
]

NAVY = "17365D"
BLUE = "2F5597"
LIGHT_BLUE = "EAF1F8"
LIGHT_GRAY = "F2F2F2"
MID_GRAY = "D9E2F3"
TEXT = RGBColor(31, 31, 31)
MUTED = RGBColor(89, 89, 89)
FONT_CJK = "Microsoft JhengHei"
FONT_LATIN = "Aptos"


def set_cell_shading(cell, fill: str) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        # CT_TcPr is sequence-sensitive.  Word rejects a document when
        # shading is appended after tcMar/vAlign even though XML parsers and
        # python-docx can still read it.
        tc_pr.insert_element_before(
            shd,
            "w:noWrap",
            "w:tcMar",
            "w:textDirection",
            "w:tcFitText",
            "w:vAlign",
            "w:hideMark",
            "w:headers",
            "w:cellIns",
            "w:cellDel",
            "w:cellMerge",
            "w:tcPrChange",
        )
    shd.set(qn("w:fill"), fill)


def set_cell_border(cell, color: str = "D9D9D9", size: str = "6") -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    borders = tc_pr.first_child_found_in("w:tcBorders")
    if borders is None:
        borders = OxmlElement("w:tcBorders")
        tc_pr.insert_element_before(
            borders,
            "w:shd",
            "w:noWrap",
            "w:tcMar",
            "w:textDirection",
            "w:tcFitText",
            "w:vAlign",
            "w:hideMark",
            "w:headers",
            "w:cellIns",
            "w:cellDel",
            "w:cellMerge",
            "w:tcPrChange",
        )
    # insideH/insideV belong to table borders, not an individual cell's
    # tcBorders.  Keeping them here produces invalid WordprocessingML.
    for edge in ("top", "left", "bottom", "right"):
        tag = f"w:{edge}"
        node = borders.find(qn(tag))
        if node is None:
            node = OxmlElement(tag)
            borders.append(node)
        node.set(qn("w:val"), "single")
        node.set(qn("w:sz"), size)
        node.set(qn("w:color"), color)


def set_cell_margins(cell, top=90, start=100, bottom=90, end=100) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.insert_element_before(
            tc_mar,
            "w:textDirection",
            "w:tcFitText",
            "w:vAlign",
            "w:hideMark",
            "w:headers",
            "w:cellIns",
            "w:cellDel",
            "w:cellMerge",
            "w:tcPrChange",
        )
    # left/right are accepted by older desktop Word versions as well as
    # current versions; start/end can make strict readers reject document.xml.
    for margin, value in (("top", top), ("left", start), ("bottom", bottom), ("right", end)):
        node = tc_mar.find(qn(f"w:{margin}"))
        if node is None:
            node = OxmlElement(f"w:{margin}")
            tc_mar.append(node)
        node.set(qn("w:w"), str(value))
        node.set(qn("w:type"), "dxa")


def set_repeat_table_header(row) -> None:
    tr_pr = row._tr.get_or_add_trPr()
    tbl_header = OxmlElement("w:tblHeader")
    tbl_header.set(qn("w:val"), "true")
    tr_pr.append(tbl_header)


def add_page_number(paragraph) -> None:
    paragraph.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    run = paragraph.add_run("第 ")
    fld_char1 = OxmlElement("w:fldChar")
    fld_char1.set(qn("w:fldCharType"), "begin")
    instr_text = OxmlElement("w:instrText")
    instr_text.set(qn("xml:space"), "preserve")
    instr_text.text = "PAGE"
    fld_char2 = OxmlElement("w:fldChar")
    fld_char2.set(qn("w:fldCharType"), "end")
    run._r.extend([fld_char1, instr_text, fld_char2])
    paragraph.add_run(" 頁")


def configure_document(doc: Document, short_title: str) -> None:
    section = doc.sections[0]
    section.page_width = Inches(8.5)
    section.page_height = Inches(11)
    section.top_margin = Inches(0.68)
    section.bottom_margin = Inches(0.65)
    section.left_margin = Inches(0.72)
    section.right_margin = Inches(0.72)
    section.header_distance = Inches(0.28)
    section.footer_distance = Inches(0.28)

    normal = doc.styles["Normal"]
    normal.font.name = FONT_LATIN
    normal.font.size = Pt(10.5)
    normal.font.color.rgb = TEXT
    normal._element.rPr.rFonts.set(qn("w:eastAsia"), FONT_CJK)
    normal.paragraph_format.space_after = Pt(5)
    normal.paragraph_format.line_spacing = 1.12

    style_specs = {
        "Title": (26, True, "000000", 0, 10),
        "Heading 1": (19, True, "000000", 14, 7),
        "Heading 2": (15, True, "000000", 11, 5),
        "Heading 3": (12.5, True, "000000", 8, 4),
        "Heading 4": (11.5, True, "000000", 6, 3),
    }
    for name, (size, bold, color, before, after) in style_specs.items():
        style = doc.styles[name]
        style.font.name = FONT_LATIN
        style.font.size = Pt(size)
        style.font.bold = bold
        style.font.color.rgb = RGBColor.from_string(color)
        style._element.rPr.rFonts.set(qn("w:eastAsia"), FONT_CJK)
        style.paragraph_format.space_before = Pt(before)
        style.paragraph_format.space_after = Pt(after)
        style.paragraph_format.keep_with_next = True

    if "Code Block" not in [style.name for style in doc.styles]:
        code = doc.styles.add_style("Code Block", WD_STYLE_TYPE.PARAGRAPH)
    else:
        code = doc.styles["Code Block"]
    code.font.name = "Cascadia Mono"
    code.font.size = Pt(8.3)
    code.paragraph_format.left_indent = Inches(0.18)
    code.paragraph_format.right_indent = Inches(0.18)
    code.paragraph_format.space_before = Pt(3)
    code.paragraph_format.space_after = Pt(5)
    code.paragraph_format.keep_together = True

    header = section.header.paragraphs[0]
    header.text = short_title
    header.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    for run in header.runs:
        run.font.name = FONT_LATIN
        run._element.rPr.rFonts.set(qn("w:eastAsia"), FONT_CJK)
        run.font.size = Pt(8.5)
        run.font.color.rgb = MUTED
    add_page_number(section.footer.paragraphs[0])


def clean_inline(text: str) -> str:
    text = re.sub(r"\[([^\]]+)\]\([^\)]+\)", r"\1", text)
    text = text.replace("**", "").replace("__", "")
    return text.strip()


def add_inline(paragraph, text: str) -> None:
    pattern = re.compile(r"(`[^`]+`|\*\*[^*]+\*\*)")
    cursor = 0
    for match in pattern.finditer(text):
        if match.start() > cursor:
            paragraph.add_run(text[cursor:match.start()])
        token = match.group(0)
        if token.startswith("`"):
            run = paragraph.add_run(token[1:-1])
            run.font.name = "Cascadia Mono"
            run.font.size = Pt(9)
            run.font.color.rgb = RGBColor.from_string(BLUE)
        else:
            run = paragraph.add_run(token[2:-2])
            run.bold = True
        cursor = match.end()
    if cursor < len(text):
        paragraph.add_run(text[cursor:])
    for run in paragraph.runs:
        if run.font.name is None:
            run.font.name = FONT_LATIN
        run._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), FONT_CJK)


def add_cover(doc: Document, title: str, subtitle: str, audience: str) -> None:
    for _ in range(3):
        doc.add_paragraph()
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("LIFE PILOT")
    r.bold = True
    r.font.size = Pt(14)
    r.font.color.rgb = RGBColor.from_string(BLUE)

    p = doc.add_paragraph(style="Title")
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.add_run(title)

    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run(subtitle)
    r.font.size = Pt(14)
    r.font.color.rgb = MUTED

    doc.add_paragraph()
    table = doc.add_table(rows=3, cols=2)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = True
    values = [("文件版本", "2.0"), ("更新日期", UPDATED), ("適用對象", audience)]
    for i, (key, value) in enumerate(values):
        left, right = table.rows[i].cells
        left.text = key
        right.text = value
        set_cell_shading(left, LIGHT_BLUE)
        for cell in (left, right):
            set_cell_border(cell)
            set_cell_margins(cell, 120, 130, 120, 130)
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        left.paragraphs[0].runs[0].bold = True

    doc.add_paragraph()
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = p.add_run("本文件依目前專案功能、資料規則、隱私權政策與服務條款重新編寫。")
    r.font.size = Pt(9.5)
    r.font.color.rgb = MUTED
    p.add_run().add_break(WD_BREAK.PAGE)


def extract_headings(lines: list[str]) -> list[str]:
    return [clean_inline(line[3:]) for line in lines if line.startswith("## ")]


def add_document_intro(doc: Document, headings: list[str]) -> None:
    doc.add_heading("文件說明", level=1)
    p = doc.add_paragraph()
    add_inline(p, "本文件為完整重寫版本，內容以 2026-10-13 的 Life Pilot 專案、資料規則與操作流程為準。畫面名稱或額度若由管理者建立的版本控制，請以 App 當下顯示內容為準。")
    doc.add_heading("文件導覽", level=1)
    table = doc.add_table(rows=1, cols=2)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.rows[0].cells[0].text = "章節"
    table.rows[0].cells[1].text = "內容"
    for idx, heading in enumerate(headings, 1):
        row = table.add_row().cells
        row[0].text = str(idx)
        row[1].text = heading
    style_table(table)
    doc.add_page_break()


def style_table(table) -> None:
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = True
    set_repeat_table_header(table.rows[0])
    for r_idx, row in enumerate(table.rows):
        for cell in row.cells:
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            set_cell_border(cell)
            set_cell_margins(cell)
            if r_idx == 0:
                set_cell_shading(cell, NAVY)
            elif r_idx % 2 == 0:
                set_cell_shading(cell, "F8FAFC")
            for paragraph in cell.paragraphs:
                paragraph.paragraph_format.space_after = Pt(0)
                paragraph.paragraph_format.line_spacing = 1.0
                for run in paragraph.runs:
                    run.font.name = FONT_LATIN
                    run._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), FONT_CJK)
                    run.font.size = Pt(8.8)
                    if r_idx == 0:
                        run.bold = True
                        run.font.color.rgb = RGBColor(255, 255, 255)


def add_markdown_table(doc: Document, rows: list[list[str]]) -> None:
    if not rows:
        return
    width = max(len(row) for row in rows)
    table = doc.add_table(rows=0, cols=width)
    for row_values in rows:
        cells = table.add_row().cells
        for i in range(width):
            text = clean_inline(row_values[i]) if i < len(row_values) else ""
            cells[i].text = text
    style_table(table)


def is_separator_row(cells: list[str]) -> bool:
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", cell.strip()) for cell in cells)


def parse_table_line(line: str) -> list[str]:
    return [part.strip() for part in line.strip().strip("|").split("|")]


def add_code_block(doc: Document, code_lines: list[str]) -> None:
    p = doc.add_paragraph(style="Code Block")
    p.paragraph_format.keep_together = len(code_lines) <= 18
    p.paragraph_format.line_spacing = 1.0
    p.add_run("\n".join(code_lines) or " ")
    p_pr = p._p.get_or_add_pPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:fill"), LIGHT_GRAY)
    p_pr.append(shd)


def render_markdown(doc: Document, lines: list[str]) -> None:
    i = 0
    first_title_skipped = False
    while i < len(lines):
        raw = lines[i].rstrip()
        stripped = raw.strip()
        if not stripped:
            i += 1
            continue
        if stripped.startswith("```"):
            i += 1
            code_lines = []
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code_lines.append(lines[i].rstrip())
                i += 1
            add_code_block(doc, code_lines)
            i += 1
            continue
        if stripped.startswith("|") and "|" in stripped[1:]:
            rows: list[list[str]] = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                cells = parse_table_line(lines[i])
                if not is_separator_row(cells):
                    rows.append(cells)
                i += 1
            add_markdown_table(doc, rows)
            continue
        if stripped.startswith("# "):
            if not first_title_skipped:
                first_title_skipped = True
            else:
                doc.add_heading(clean_inline(stripped[2:]), level=1)
            i += 1
            continue
        if stripped.startswith("#### "):
            doc.add_heading(clean_inline(stripped[5:]), level=4)
            i += 1
            continue
        if stripped.startswith("### "):
            doc.add_heading(clean_inline(stripped[4:]), level=3)
            i += 1
            continue
        if stripped.startswith("## "):
            doc.add_heading(clean_inline(stripped[3:]), level=1)
            i += 1
            continue
        if re.match(r"^\d+\.\s+", stripped):
            p = doc.add_paragraph(style="List Number")
            add_inline(p, re.sub(r"^\d+\.\s+", "", stripped))
            i += 1
            continue
        if stripped.startswith("- "):
            p = doc.add_paragraph(style="List Bullet")
            add_inline(p, stripped[2:])
            i += 1
            continue
        p = doc.add_paragraph()
        p.paragraph_format.keep_together = len(stripped) < 180
        add_inline(p, stripped)
        i += 1


def generate(config: dict[str, object]) -> None:
    source = Path(config["source"])
    output = Path(config["output"])
    lines = source.read_text(encoding="utf-8").splitlines()
    title = next(clean_inline(line[2:]) for line in lines if line.startswith("# "))
    doc = Document()
    configure_document(doc, str(config["short"]))
    add_cover(doc, title, str(config["subtitle"]), str(config["audience"]))
    add_document_intro(doc, extract_headings(lines))
    render_markdown(doc, lines)

    core = doc.core_properties
    core.title = title
    core.subject = str(config["subtitle"])
    core.author = "Life Pilot"
    core.keywords = "Life Pilot, 操作說明, 技術文件, 測試計畫"
    core.comments = "完整重寫版本"
    output.parent.mkdir(parents=True, exist_ok=True)
    doc.save(output)
    print(f"generated: {output}")


if __name__ == "__main__":
    for item in DOCUMENTS:
        generate(item)
