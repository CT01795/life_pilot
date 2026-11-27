"""Validate authored Word packages and render Word-exported PDFs for visual QA.

PDFs and images stay outside the repository. This does not execute app tests.
"""
import json
import re
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree

import pypdfium2 as pdfium
from PIL import Image, ImageDraw
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[1]
QA = Path("D:/LifePilot_document_qa/20261016/final")
NAMES = ["Life_Pilot_使用者操作說明", "Life_Pilot_開發者技術文件", "Life_Pilot_測試計畫與檢查點"]


def main():
    report = []
    for short, name in zip(["user", "developer", "test"], NAMES):
        docx_path = ROOT / "docs" / f"{name}.docx"
        with ZipFile(docx_path) as archive:
            assert archive.testzip() is None
            for entry in archive.namelist():
                if entry.endswith(".xml"):
                    ElementTree.fromstring(archive.read(entry))
        pdf_path = QA / f"{name}.pdf"
        pdf = pdfium.PdfDocument(pdf_path)
        text_pages = [page.extract_text() or "" for page in PdfReader(pdf_path).pages]
        assert len(pdf) == len(text_pages)
        output = QA / short
        output.mkdir(exist_ok=True)
        page_manifest = []
        for i in range(len(pdf)):
            page = pdf[i]
            bitmap = page.render(scale=4 / 3)
            rendered = bitmap.to_pil().convert("RGB")
            rendered.save(output / f"page-{i + 1:03d}.png")
            page_manifest.append(dict(page=i + 1, characters=len(text_pages[i]),
                                      width=rendered.width, height=rendered.height))
            bitmap.close()
            page.close()
        # Two pages are placed side by side at their original rendered size;
        # no downscaling is applied to the inspection spreads.
        for i in range(0, len(pdf), 2):
            paths = [output / f"page-{j + 1:03d}.png" for j in range(i, min(i + 2, len(pdf)))]
            pages = [Image.open(path).convert("RGB") for path in paths]
            canvas = Image.new("RGB", (sum(p.width for p in pages) + 12, max(p.height for p in pages) + 28), "#dddddd")
            draw = ImageDraw.Draw(canvas)
            x = 0
            for j, page in enumerate(pages):
                draw.text((x + 10, 5), f"{short} page {i + j + 1}", fill="black")
                canvas.paste(page, (x, 28))
                x += page.width + 12
            canvas.save(output / f"spread-{i // 2 + 1:03d}.png")
        extracted = "\n".join(text_pages)
        item = dict(document=name, pages=len(pdf), pdf_characters=len(extracted),
                    blank_pages=[p["page"] for p in page_manifest if p["characters"] < 10],
                    page_manifest=page_manifest)
        if short == "test":
            case_ids = re.findall(r"案例編號\s+([A-Z]+-\d{3})", extracted)
            assert len(case_ids) == len(set(case_ids)) == 256, len(case_ids)
            item["unique_manual_cases"] = len(case_ids)
        report.append(item)
        pdf.close()
        print(f"{short}: {item['pages']} pages; blank pages={item['blank_pages']}")
    (QA / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
