from __future__ import annotations

from pathlib import Path

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs"
DATE = "2026 年 9 月 29 日"
FONT = "Microsoft JhengHei"
NAVY = "24496B"
PALE = "EAF2F8"
GRAY = "F2F4F6"


def font(run, size=None, bold=None, color=None):
    run.font.name = FONT
    run._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), FONT)
    if size:
        run.font.size = Pt(size)
    if bold is not None:
        run.bold = bold
    if color:
        run.font.color.rgb = RGBColor(*color)


def fill(cell, value):
    props = cell._tc.get_or_add_tcPr()
    node = props.find(qn("w:shd"))
    if node is None:
        node = OxmlElement("w:shd")
        props.append(node)
    node.set(qn("w:fill"), value)


def margins(cell):
    props = cell._tc.get_or_add_tcPr()
    node = props.first_child_found_in("w:tcMar")
    if node is None:
        node = OxmlElement("w:tcMar")
        props.append(node)
    for name in ("top", "left", "bottom", "right"):
        item = OxmlElement(f"w:{name}")
        item.set(qn("w:w"), "100")
        item.set(qn("w:type"), "dxa")
        node.append(item)


def page_number(paragraph):
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = paragraph.add_run("第 ")
    begin = OxmlElement("w:fldChar")
    begin.set(qn("w:fldCharType"), "begin")
    text = OxmlElement("w:instrText")
    text.set(qn("xml:space"), "preserve")
    text.text = " PAGE "
    separate = OxmlElement("w:fldChar")
    separate.set(qn("w:fldCharType"), "separate")
    value = OxmlElement("w:t")
    value.text = "1"
    end = OxmlElement("w:fldChar")
    end.set(qn("w:fldCharType"), "end")
    run._r.extend([begin, text, separate, value, end])
    run2 = paragraph.add_run(" 頁")
    font(run, 9)
    font(run2, 9)


def setup(doc, short_title):
    section = doc.sections[0]
    section.page_width = Inches(8.27)
    section.page_height = Inches(11.69)
    section.top_margin = Inches(0.65)
    section.bottom_margin = Inches(0.65)
    section.left_margin = Inches(0.72)
    section.right_margin = Inches(0.72)
    for style_name, size in (("Normal", 10.5), ("Title", 25), ("Heading 1", 17), ("Heading 2", 13.5), ("Heading 3", 11.5)):
        style = doc.styles[style_name]
        style.font.name = FONT
        style._element.get_or_add_rPr().rFonts.set(qn("w:eastAsia"), FONT)
        style.font.size = Pt(size)
        style.paragraph_format.space_after = Pt(5)
        style.paragraph_format.line_spacing = 1.15
        if style_name != "Normal":
            style.font.bold = True
            style.font.color.rgb = RGBColor(36, 73, 107)
            style.paragraph_format.keep_with_next = True
    header = section.header.paragraphs[0]
    header.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    font(header.add_run(short_title), 8.5, color=(90, 90, 90))
    page_number(section.footer.paragraphs[0])


def cover(doc, title, subtitle):
    doc.add_paragraph("LIFE PILOT", style="Title")
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    font(p.add_run(title), 22, True, (36, 73, 107))
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    font(p.add_run(subtitle), 12, False, (80, 80, 80))
    doc.add_paragraph()
    table = doc.add_table(rows=3, cols=2)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.style = "Table Grid"
    for row, values in zip(table.rows, (("版本", "1.0"), ("更新日期", DATE), ("適用平台", "Android、iOS、Web、Windows、macOS"))):
        for cell, text in zip(row.cells, values):
            cell.text = text
            margins(cell)
        fill(row.cells[0], PALE)
    doc.add_page_break()


def contents(doc, items):
    doc.add_heading("文件導覽", level=1)
    for index, item in enumerate(items, 1):
        doc.add_paragraph(f"{index}. {item}")
    doc.add_page_break()


def bullets(doc, items):
    for item in items:
        doc.add_paragraph(item, style="List Bullet")


def steps(doc, items):
    for index, item in enumerate(items, 1):
        paragraph = doc.add_paragraph()
        paragraph.paragraph_format.left_indent = Inches(0.24)
        paragraph.paragraph_format.first_line_indent = Inches(-0.24)
        paragraph.add_run(f"{index}. {item}")


def table(doc, headers, rows, widths=None):
    result = doc.add_table(rows=1, cols=len(headers))
    result.style = "Table Grid"
    result.alignment = WD_TABLE_ALIGNMENT.CENTER
    for cell, text in zip(result.rows[0].cells, headers):
        cell.text = str(text)
        fill(cell, NAVY)
        cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        for run in cell.paragraphs[0].runs:
            font(run, 9.5, True, (255, 255, 255))
        margins(cell)
    header_props = result.rows[0]._tr.get_or_add_trPr()
    repeat = OxmlElement("w:tblHeader")
    repeat.set(qn("w:val"), "true")
    header_props.append(repeat)
    for r_index, values in enumerate(rows):
        row = result.add_row()
        row_props = row._tr.get_or_add_trPr()
        no_split = OxmlElement("w:cantSplit")
        no_split.set(qn("w:val"), "true")
        row_props.append(no_split)
        cells = row.cells
        for cell, text in zip(cells, values):
            cell.text = str(text)
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.TOP
            margins(cell)
            for run in cell.paragraphs[0].runs:
                font(run, 9)
        if r_index % 2:
            for cell in cells:
                fill(cell, GRAY)
    if widths:
        for row in result.rows:
            for cell, width in zip(row.cells, widths):
                cell.width = Inches(width)
    doc.add_paragraph()
    return result


def note(doc, title, text):
    t = doc.add_table(rows=1, cols=1)
    t.style = "Table Grid"
    cell = t.cell(0, 0)
    fill(cell, PALE)
    p = cell.paragraphs[0]
    font(p.add_run(f"{title}｜"), 10, True, (36, 73, 107))
    font(p.add_run(text), 10)
    margins(cell)
    doc.add_paragraph()


def user_guide():
    doc = Document()
    setup(doc, "Life Pilot 使用者操作說明")
    chapters = ["開始使用", "首頁", "行事曆與共用行事曆", "推薦活動與景點", "回憶走廊", "記帳與積分", "遊戲", "資料儲存位置", "方案與訂閱", "資料匯出與帳號刪除", "常見問題"]
    cover(doc, "使用者操作說明", "從登入、日常紀錄到本機／雲端資料管理的完整指南")
    contents(doc, chapters)

    doc.add_heading("1. 開始使用", level=1)
    doc.add_heading("1.1 登入與註冊", level=2)
    steps(doc, ["開啟 Life Pilot，選擇登入或註冊。", "輸入 Email 與密碼；註冊時閱讀並同意服務條款與隱私權政策。", "登入完成後，系統會讀取此帳號先前選擇的資料儲存位置。", "若忘記密碼，使用重設密碼信件中的連結返回 App 或 Web 完成設定。"]) 
    note(doc, "帳號切換", "登出後，前一個帳號的首頁、行事曆、記帳、積分與快取會清除；新帳號不會看到前一個帳號的資料。")
    doc.add_heading("1.2 功能權限", level=2)
    table(doc, ["使用者類型", "預設可用功能", "額外功能"], [
        ("一般使用者", "首頁、行事曆、推薦活動、推薦景點、回憶走廊、記帳", "積分、遊戲、AI、股票、Business Plan、意見回饋須由管理者授權"),
        ("管理者", "所有一般功能", "可使用全部模組與『模組授權』頁"),
    ], [1.2, 3.1, 2.5])
    bullets(doc, ["未授權的模組不會出現在功能選單。", "首頁也不會查詢或顯示未授權的積分內容。", "方案說明不會列出尚未授權的積分或遊戲額度。", "管理者更新權限後，使用者重新登入或重新載入即可套用。"]) 

    doc.add_heading("2. 首頁", level=1)
    table(doc, ["區塊", "用途", "操作"], [
        ("今日生活摘要", "集中查看近日行程、今日收支，以及已授權時的積分", "點摘要可展開對應區塊"),
        ("近日行程", "查看近期未完成行程與時間衝突", "完成後可同時建立回憶、收入、支出與積分"),
        ("推薦活動／景點", "快速探索並加入單日行程", "勾選後先確認日期與時間再加入"),
        ("記帳／積分", "快速新增或前往已選帳戶明細", "選擇器可切換帳戶；看更多進入明細"),
    ])
    note(doc, "日期與時間", "推薦活動或景點加入行事曆時，系統以裝置當地日期建立單日行程，不會因 UTC 時差變成前一天。若加入今天，來源開始時間晚於目前時間就保留來源時間，否則預設為目前時間；使用者仍可在確認視窗調整。")

    doc.add_heading("3. 行事曆與共用行事曆", level=1)
    doc.add_heading("3.1 新增與管理行程", level=2)
    steps(doc, ["切換到行事曆並選擇日期。", "新增活動名稱、國家、城市、地點、日期、時間、描述與提醒。", "若與今天或明天尚未完成的活動重疊，確認警告後再決定是否儲存。", "編輯日期或時間後，手機通知會重新排程；完成的事件不再提醒。", "刪除事件會同步清除相關提醒。"]) 
    doc.add_heading("3.2 分享行事曆", level=2)
    steps(doc, ["在共用行事曆的邀請區塊輸入對方 Email。", "展開事件選擇區塊，搜尋並勾選要分享的未來或過去事件，也可全部選擇。", "送出後等待對方接受；重複邀請、額度已滿會顯示明確原因。", "接收者接受後，可在自己的行事曆同時看到雙方資料；顏色會區分擁有者。", "分享者可逐筆取消事件或全部停止分享；接收者也可停止查看。拒絕或停止後會釋放分享額度。"]) 
    note(doc, "本機模式", "共用行事曆只適用雲端模式。本機模式下分享功能會停用，切到本機前會取消既有分享，避免資料不一致。")

    doc.add_heading("4. 推薦活動與景點", level=1)
    bullets(doc, ["清單可依城市與關鍵字篩選；若目前城市沒有關鍵字結果，系統可切換到符合資料的城市。", "可在清單／地圖統計模式間切換；點城市名稱或數字會回到該城市清單。", "活動依喜歡、一般、不喜歡分組，再依日期、時間、國家、城市與地點排序。", "只有存在細項時才開啟預覽；沒有細項時直接使用卡片資訊。", "加入行事曆前可調整日期與時間，活動與景點皆建立為單日行程。", "圖片只有在有資料時顯示，縮圖採延遲載入，降低初始等待。"]) 

    doc.add_heading("5. 回憶走廊", level=1)
    bullets(doc, ["預設載入近 30 天；點『載入更多』每次再往前 30 天。", "可用時間軸、城市與地圖統計查看足跡。", "回憶若有當日細項才開啟預覽。", "從行程建立回憶時，只帶入所選日期的 subEvents。", "記帳與積分快捷入口會進入與該回憶關聯的帳戶明細。", "未來日期的回憶仍會顯示，不會因尚未發生而被隱藏。"]) 

    doc.add_page_break()
    doc.add_heading("6. 記帳與積分", level=1)
    table(doc, ["項目", "記帳", "積分"], [
        ("一級分類", "食、衣、住、行、育、樂、保留項、未分類", "德、智、體、群、美、保留項、未分類"),
        ("二級分類", "可自行輸入，也可留白", "可自行輸入，也可留白"),
        ("日期時間", "新增與編輯皆可選日期、時、分", "新增與編輯皆可選日期、時、分"),
        ("小數", "最多 4 位小數並顯示千分位", "整數點數並顯示千分位"),
        ("載入範圍", "個人近 30 天；旅程顯示全部；保留項永遠載入", "近 30 天；無資料時顯示最新一筆；保留項永遠載入"),
    ])
    bullets(doc, ["刪除明細後，今日小計與總金額／總積分會立即重算。", "含『餘』的舊記帳資料已改為保留項，不再依文字關鍵字判斷。", "首頁已選帳戶時，『看更多』直接進入該帳戶明細；點帳戶選擇器仍可換帳戶。"]) 

    doc.add_heading("7. 遊戲", level=1)
    bullets(doc, ["遊戲需管理者授權才會出現在功能選單。", "雲端模式可依選擇使用管理者題庫或自己的題庫；本機模式只使用本機題庫。", "可用題目總數未達遊戲最低題數時不能開始，畫面會提示需要的題數。", "自建題庫支援搜尋、分類、啟用、停用、編輯與刪除。", "雲端答題紀錄依方案保留 30 天或 1 年；本機答題紀錄不限量且不套用保留天數。"]) 

    doc.add_heading("8. 資料儲存位置", level=1)
    table(doc, ["模式", "特性", "注意事項"], [
        ("雲端", "跨裝置登入可見；可用分享功能", "依方案額度限制；到期可能進入唯讀與寬限期"),
        ("此裝置", "資料保存在手機、平板、電腦或瀏覽器；本機資料量不限", "換裝置、清除網站資料或瀏覽器資料後不會自動出現；需有效本機方案才能新增"),
    ])
    steps(doc, ["開啟『儲存位置』。", "選擇目標模式並閱讀差異、刪除來源資料的提醒。", "系統先檢查目標方案額度；超額會取消整批搬移且保留原資料。", "確認後才搬移；成功後會刪除來源模式資料並關閉設定畫面。", "搬移失敗時會顯示具體資料表或欄位原因，未成功資料不會刪除。"]) 

    doc.add_heading("9. 方案與訂閱", level=1)
    bullets(doc, ["畫面最上方顯示目前儲存模式對應的方案與實際額度。", "只有已授權模組才會出現在方案額度說明。", "雲端免費版與雲端付費版本分開顯示；本機版本顯示自己的版本、生效日與每季費用。", "舊版尚未到期又加購新版時，畫面會同時列出舊版與新增額度。", "雲端 Plus 到期後降為免費版；超額資料有 30 天搬移或續訂寬限。", "本機方案到期後資料仍可查看，但不能新增；續訂後恢復寫入。"]) 

    doc.add_heading("10. 資料匯出與帳號刪除", level=1)
    bullets(doc, ["資料匯出會下載 Excel，頁簽與欄位依當時畫面語言顯示。", "匯出內容正向表列為：行事曆、回憶走廊、記帳、積分；不因日期截斷。", "申請刪除帳號只會通知管理者，不會立即刪除。", "申請中可取消；管理者確認後才刪除帳號與相關資料。", "『查看與清理資料』用於配額整理；『刪除帳號』則連同登入身分一併處理。"]) 

    doc.add_heading("11. 常見問題", level=1)
    table(doc, ["問題", "處理方式"], [
        ("看不到積分、遊戲或股票", "這些是額外模組，請由管理者在模組授權頁開放後重新登入。"),
        ("加入景點後日期變成前一天", "新版已依裝置當地日期建立；更新 App 後重新建立該行程。"),
        ("本機資料在另一台裝置看不到", "本機資料不跨裝置同步；請在原裝置操作，或在額度內切回雲端。"),
        ("行事曆分享額度沒有釋放", "重新開啟分享視窗；拒絕、停止查看或停止分享後應立即釋放。"),
        ("頁面持續載入", "先確認網路與登入狀態；本機模式仍需登入驗證，必要時重新啟動 App。"),
    ])
    return doc


def developer_guide():
    doc = Document()
    setup(doc, "Life Pilot 開發者技術文件")
    chapters = ["系統總覽", "專案結構", "身分與模組授權", "本機與雲端資料", "行事曆與提醒", "推薦與地理資料", "記帳積分遊戲", "訂閱額度", "效能與生命週期", "多國語系", "Supabase", "建置與發布", "維運檢查"]
    cover(doc, "開發者技術文件", "Flutter、Supabase、本機儲存、權限與資料生命週期")
    contents(doc, chapters)

    doc.add_heading("1. 系統總覽", level=1)
    table(doc, ["層次", "技術", "責任"], [
        ("UI", "Flutter / Material", "響應式頁面、四語系、Android／iOS／Web／Desktop"),
        ("狀態", "Provider / ChangeNotifier", "帳號隔離、請求世代、防止 dispose 後通知"),
        ("雲端", "Supabase Auth / Postgres / RPC / RLS", "登入、共用資料、配額、管理功能"),
        ("本機", "IndexedDB / Sembast 相容層", "裝置模式資料、離線持久化、搬移暫存"),
        ("外部服務", "Python API / OpenWeather / 爬蟲", "股票、地理編碼、天氣、推薦內容"),
    ])
    note(doc, "核心原則", "所有讀寫都必須同時考慮帳號、儲存模式、模組授權、訂閱狀態與元件生命週期。")

    doc.add_heading("2. 專案結構", level=1)
    table(doc, ["路徑", "內容"], [
        ("lib/apps", "主頁控制器、功能選單、設定、模組授權"),
        ("lib/auth", "登入、註冊、Recovery URL、訂閱與儲存模式狀態"),
        ("lib/calendar", "月曆、共用行事曆、通知排程"),
        ("lib/pages/home", "首頁聚合查詢、快取、推薦卡、完成行程工作流"),
        ("lib/event / memory_trace", "推薦活動、景點、回憶、地圖統計"),
        ("lib/accounting / point_record", "帳戶、明細、分類、分頁"),
        ("lib/game", "題庫、答題紀錄、可玩性檢查"),
        ("lib/local_storage", "本機資料、搬移、清除與 Web 相容處理"),
        ("lib/subscription", "版本、額度、管理者調整、清理"),
        ("tool", "文件產生與需手動執行的 Supabase SQL"),
    ])

    doc.add_heading("3. 身分與模組授權", level=1)
    doc.add_heading("3.1 權限模型", level=2)
    table(doc, ["層級", "PageType", "規則"], [
        ("基本", "home、personalEvent、recommendEvent、recommendPlaces、memoryTrace、accountRecords", "所有已登入使用者"),
        ("可授權", "pointsRecord、game、ai、stock、businessPlan、feedbackAdmin", "管理者預設全開；一般使用者需 user_module 有效紀錄"),
        ("管理專用", "moduleAuthorization", "僅系統管理者"),
    ])
    bullets(doc, ["ControllerPageMain 是唯一可見頁面來源；changePage 也再次拒絕未授權頁面。", "ServiceModule 查詢 enabled=true 且 stop_at 未到期的模組。", "切換帳號時先清空 moduleKeys 與頁面快取，再非同步載入新帳號權限。", "首頁以 canAccess(pointsRecord) 決定是否查詢、顯示與允許寫入積分。", "方案頁用相同判斷過濾 point_record_detail 與 game_questions 額度。", "PageFeedbackAdmin 自身仍做第二層頁面防護；資料庫再以 RLS／RPC 防護。"]) 
    doc.add_heading("3.2 管理者授權流程", level=2)
    steps(doc, ["先在 Supabase 執行 tool/supabase_module_authorization.sql。未執行時，管理頁會明確提示尚未部署，不會只顯示一般讀取失敗。", "管理者進入『模組授權』，以 Email 查詢。", "勾選額外模組並儲存；RPC 會先驗證管理者、使用者與白名單。", "使用者重新登入後 ControllerPageMain 載入 user_module。", "新增可授權模組時，同步更新 PageType、grantablePageKeys、SQL 白名單、頁面自身防護與測試。"])

    doc.add_heading("4. 本機與雲端資料", level=1)
    bullets(doc, ["preferredStorage 決定每個 service 走 LocalDataStore 或 Supabase。", "雲端轉本機：export_my_cloud_data_for_local → 寫入本機 → delete_cloud_records_after_local_copy。", "本機轉雲端：先整批檢查配額；任何資源超額即整批取消，不刪本機。", "成功切換後清理來源模式資料，並失效首頁、行事曆、帳戶與回憶快取。", "Web 使用 IndexedDB；不要依賴舊版 idb_shim 的 notification/cursor 型別事件。", "本機資料不限筆數，但有效本機方案控制是否可新增；資料不會因到期自動刪除。"]) 

    doc.add_heading("5. 行事曆與提醒", level=1)
    bullets(doc, ["CalendarEvent 的日期由 timestamptz 轉成本地時間後再做 DateUtils 日期比較。", "純日期輸入必須先建立本地午夜，再轉 UTC 儲存；禁止先 toUtc 再 dateOnly，否則 UTC+8 會落到前一天。", "get_filtered_calendar_events 必須回傳 is_completed，讓跨裝置完成狀態能取消手機提醒。", "事件新增、修改、刪除、完成後都需失效受影響月份；跨月事件需同時失效起訖月份。", "通知排程在 App 關閉時由原生排程觸發；完成或改期時要先取消舊通知再重排。", "共用事件只能讀取；更新、刪除 RLS 僅允許擁有者。"]) 

    doc.add_heading("6. 推薦與地理資料", level=1)
    bullets(doc, ["事件去重：無時間來源使用名稱＋日期＋城市＋地點；有時間來源再加時間。", "map_lat/map_lng 是專用地圖座標，與天氣附近座標 lat/lng 分離；已有專用座標時不可重抓。", "地理編碼使用國家 ISO 代碼、城市、地點與名稱；回填限管理者並分批執行。", "天氣只載入畫面可見且八天內資料；已抓快取重用，不因每次重建重抓。", "推薦清單先依喜歡狀態，再按有效開始日、時間、結束日、國家、城市、地點排序。", "客戶端預覽只在 subEvents 非空時開啟；大資料量應使用資料庫分頁。"]) 

    doc.add_heading("7. 記帳、積分與遊戲", level=1)
    table(doc, ["模組", "資料原則", "關鍵規則"], [
        ("記帳", "numeric，最多 4 位小數", "date 排序；primary_category 與 group 分開；保留項不受日期窗影響"),
        ("積分", "整數點數", "德智體群美分類；近 30 天；保留項不受日期窗影響"),
        ("遊戲", "雲端或本機題庫", "可用題目總數達遊戲門檻才可開始；本機模式不得讀管理者題庫"),
    ])
    bullets(doc, ["所有金額 TextInputFormatter 應修正多餘小數點與超過四位的小數，不可清空整欄。", "明細新增與編輯皆傳完整 timestamp；畫面分離顯示日期與時間。", "事件完成工作流可同時建立收入、支出、積分與回憶，共用同一 recordedAt。", "題庫新增前做本機／雲端重複檢查；刪除後立即刷新配額。"]) 

    doc.add_heading("8. 訂閱與額度", level=1)
    bullets(doc, ["額度取決於使用者當次付款綁定的 pricing version、倍數與管理者 override，不可只讀最新版本。", "unlimited quota 在 UI 顯示 ∞，不要顯示 bigint 最大值。", "雲端 Plus 到期後唯讀；30 天內可續訂或搬本機；排程只刪超額部分並優先保留最新與保留項。", "本機方案到期不刪資料，只禁止新增。", "清理函式必須由 service_role／postgres 每日執行，authenticated 與 anon 不可 execute。", "方案頁依模組授權過濾積分與遊戲說明，避免顯示使用者無權使用的額度。"]) 

    doc.add_page_break()
    doc.add_heading("9. 效能與生命週期", level=1)
    table(doc, ["問題", "實作策略"], [
        ("帳號殘留", "請求帶 account generation；完成時比對帳號；切換時清空 state/cache"),
        ("dispose 後通知", "SafeChangeNotifier、mounted、request token；取消 stream/timer"),
        ("首頁載入", "core 與推薦延遲載入；積分未授權時不發 request"),
        ("圖片卡頓", "縮圖尺寸限制、RepaintBoundary、可見時才解碼"),
        ("長清單", "分頁、ListView builder、載入更多空結果一次即停"),
        ("行事曆", "依月份快取；新增／修改後精準失效，不全量重抓"),
    ])

    doc.add_heading("10. 多國語系", level=1)
    bullets(doc, ["來源檔：lib/l10n/app_zh.arb、app_en.arb、app_ja.arb、app_ko.arb。", "修改 ARB 後執行 flutter gen-l10n；不可直接只改 generated dart。", "placeholder 必須在訊息 metadata 定義且型別一致。", "UI 不得硬編碼簡體中文或英文；資料分類輸出 Excel 時也需轉為當時語系。", "長文字需以 Wrap、Flexible、LayoutBuilder 驗證手機、平板與 Web。"]) 

    doc.add_heading("11. Supabase", level=1)
    bullets(doc, ["RLS 是最後防線；隱藏按鈕不能取代政策。", "SECURITY DEFINER 必須 SET search_path TO '' 並使用完整 schema 名稱。", "RPC 預設撤銷 public/anon，再只授權 authenticated 或 service_role。", "模組授權 SQL 建立 admin_get_user_modules、admin_set_user_modules、life_pilot_can_use_module。", "部署 SQL 後查 pg_proc、proconfig、has_function_privilege 與 pg_policies 驗證。", "資料庫函式回傳欄位變更時先 DROP 舊簽名再 CREATE，避免 42P13。"]) 

    doc.add_heading("12. 建置與發布", level=1)
    steps(doc, ["flutter pub get", "flutter gen-l10n", "dart format lib test", "flutter analyze", "flutter test", "Android：確認 applicationId com.minavi.life_pilot、簽章、Gradle／AGP 相容後建置 AAB。", "iOS：確認 Bundle ID com.minavi.life_pilot、Signing Team、Associated Domains、通知權限後 Archive。", "Web：驗證 Recovery URL、IndexedDB、本機／雲端搬移與下載 Excel。"])
    note(doc, "Gradle", "目前 Flutter 需要 Gradle 8.14 以上；不要將 wrapper 降回 8.11.1。")

    doc.add_heading("13. 維運檢查", level=1)
    table(doc, ["頻率", "檢查"], [
        ("每日", "訂閱超額清理、答題紀錄清理、推薦活動抓取 marker、錯誤率"),
        ("每週", "RLS／RPC 權限掃描、匿名 grants、孤兒收藏、爬蟲去重率"),
        ("每版", "四語系、手機／平板／Web overflow、帳號切換、背景通知、資料搬移"),
        ("重大變更", "先在測試專案驗證 SQL；保留可重跑檢查；記錄函式簽名與政策差異"),
    ])
    return doc


def test_plan():
    doc = Document()
    setup(doc, "Life Pilot 測試計畫與檢查點")
    cover(doc, "測試計畫與檢查點", "可逐項執行、記錄證據與回歸結果的完整測試手冊")
    contents(doc, ["測試準備", "帳號與權限", "首頁", "行事曆與分享", "推薦與回憶", "記帳與積分", "遊戲", "儲存模式與訂閱", "匯出與刪除", "股票與管理功能", "效能／相容性／發布", "缺陷紀錄"])
    doc.add_heading("1. 測試準備", level=1)
    table(doc, ["角色／環境", "準備資料"], [
        ("管理者 A", "所有模組、雲端 Plus、可管理方案與模組"),
        ("一般使用者 B", "僅六個預設模組、雲端免費版"),
        ("一般使用者 C", "授權積分與遊戲"),
        ("裝置", "Android 手機、Android 平板、iPhone/iPad、Chrome Web、寬螢幕"),
        ("資料", "跨月行程、同時段行程、推薦活動／景點、記帳／積分、本機與雲端資料"),
    ])
    note(doc, "紀錄方式", "每項測試填寫實際結果、通過／失敗／阻塞、缺陷編號，並保留截圖、console、Supabase 查詢結果。")

    cases = [
        ("AUTH-01", "註冊與登入", "登出；使用新 Email", "完成註冊並登入，再登出重登", "進入首頁；法律同意紀錄存在；不殘留前一帳號資料", "auth.users、legal_consents；首頁無舊資料"),
        ("AUTH-02", "重設密碼", "Web 與手機各一", "寄送重設信並點連結", "直接進入重設頁；無 main.dart.js 未捕捉錯誤", "Supabase recovery session；新密碼可登入"),
        ("AUTH-03", "帳號切換隔離", "A 有行程／帳戶，B 無", "A 登出後登入 B，不按重新整理", "首頁、月曆、記帳立即顯示 B 狀態", "所有 provider/cache account key 已切換"),
        ("MOD-01", "預設模組", "一般使用者 B 無 user_module", "登入並開功能選單與首頁", "只見首頁、行事曆、推薦活動、推薦景點、回憶、記帳；無積分查詢", "Network 不應呼叫積分摘要"),
        ("MOD-02", "管理者授權", "A 管理者、B 一般", "先執行授權 SQL；A 搜尋 B，勾積分／遊戲後儲存；B 重登", "B 功能選單與首頁出現積分、遊戲；未部署 RPC 時顯示明確提示", "user_module 有 enabled=true 的兩筆；RPC 權限正確"),
        ("MOD-03", "取消授權", "B 已在積分頁", "A 取消積分；B 重登", "B 回首頁且積分入口、方案文字消失", "不可用舊 selectedPage 繞過"),
        ("MOD-04", "可授權管理模組", "B 無權限", "分別授權股票、Business Plan、意見回饋", "只顯示已授權項目；操作受 RLS 保護", "life_pilot_can_use_module 與 feedback policies"),
        ("HOME-01", "首頁分段載入", "帳號有行程與記帳", "冷啟動首頁", "核心先顯示；推薦在展開時載入；無長時間白屏", "推薦 API 未在未展開時呼叫"),
        ("HOME-02", "推薦日期與時間", "裝置 Asia/Taipei；準備早於與晚於目前時間的活動／景點", "從首頁與推薦頁分別加入今天的行程", "日期不變昨天；來源時間較晚時保留，來源時間已過時預設現在；可手動調整", "start_date 轉本地後日期等於選擇日；start_time 等於確認值"),
        ("HOME-03", "完成行程整合", "設定記帳與積分帳戶", "完成行程並建立回憶、收入、支出、積分", "四類結果顯示成功；日期時間相同；入口可回對應帳戶", "關聯 ID、subEvents 當日資料"),
        ("CAL-01", "跨月快取", "8/31–9/1 行程", "從首頁新增後進月曆，切 8 月與 9 月", "兩個月份都立即看到，不需手動刷新", "兩個月份 cache invalidated"),
        ("CAL-02", "改期通知", "手機建立今日提醒", "Web 將事件移到明天，再開手機", "今日舊提醒取消；明天提醒重排", "RPC 回傳 is_completed；通知 ID 無重複"),
        ("CAL-03", "完成通知", "Web 與手機同帳號", "Web 完成事件後等待手機原提醒時間", "手機不再通知", "手機同步完成狀態並取消排程"),
        ("CAL-04", "重疊提醒", "今天／明天各兩個重疊事件", "新增或編輯成重疊", "儲存前與首頁皆提示；已完成事件不計", "只計今天與明天未完成事件"),
        ("SHARE-01", "指定事件分享", "A、B 雲端", "A 分享 2 筆；B 接受", "B 只看到 2 筆且不能改；顏色區分", "calendar_share_events、RLS select"),
        ("SHARE-02", "追加月份事件", "已有 8/31 分享", "切 9 月再分享 9/8", "兩筆都保留，不覆蓋舊選擇", "同 invitation 累加 selected events"),
        ("SHARE-03", "拒絕／停止與額度", "額度接近上限", "拒絕、停止查看、停止分享", "非有效紀錄從清單消失且額度立即釋放", "只計 pending／accepted；明細清理"),
        ("SHARE-04", "分享錯誤訊息", "重複 Email、超額", "再次送出", "分別顯示重複邀請或額度已滿，不顯示 database_error", "RPC JSON code 正確映射"),
        ("REC-01", "推薦活動排序", "like／一般／hate 與不同日期時間", "開啟活動清單", "先 like、最後 hate；同組依有效開始日、時間、結束日、國家城市地點", "無 endDate 時視同 startDate"),
        ("REC-02", "去重", "同名同日同城同地點", "分別匯入無時間與有時間資料", "無時間不重複；有時間僅同時間去重", "不使用 master_url 條件"),
        ("REC-03", "地圖城市", "台灣多縣市與海外資料", "切地圖，點城市名稱與數字", "定位合理並切回該城市清單；無 overflow", "country、map_lat、map_lng 快取"),
        ("MEM-01", "30 天載入更多", "跨 90 天資料", "初開後連按載入更多", "每次前推 30 天；空結果一次後按鈕消失；不重複", "日期窗與 ID 去重"),
        ("MEM-02", "未來回憶與預覽", "未來回憶含 subEvents", "開清單並點卡", "未來資料可見；有細項可預覽", "subEvents 非空且日期正確"),
        ("ACC-01", "日期時間與小數", "記帳帳戶", "輸入 1,234.5678 並改日期時間", "儲存精確 numeric；格式有千分位；不清空輸入", "value、date、currency、分類"),
        ("ACC-02", "分類與保留項", "舊『餘』資料及新資料", "查近 30 天與載入更多", "舊資料為保留項且永久列出；不再用文字判斷", "primary_category=reserved"),
        ("POINT-01", "授權前後", "B 無積分、C 有積分", "比較首頁、行程完成與方案頁", "B 完全無積分 UI/request；C 正常", "Network 與 usage 資源過濾"),
        ("GAME-01", "最低題數", "題庫 2 題／3 題", "分別開始遊戲", "未達門檻阻擋；達門檻可玩；不要求每分類 3 題", "availability 可用總題數"),
        ("GAME-02", "本機題庫", "本機模式無題／有題", "進遊戲與新增題目", "無題不能進；有題可玩；不讀管理者題庫", "LocalDataStore，無題庫 RPC"),
        ("STORE-01", "雲端轉本機", "多資源雲端資料", "確認搬移", "搬完本機可見、雲端刪除、畫面自動關閉與刷新", "IndexedDB／Sembast 與雲端筆數"),
        ("STORE-02", "本機轉雲端超額", "本機筆數超免費額度", "嘗試切換", "整批失敗、顯示資源 used/incoming/quota、本機全保留", "雲端無部分新增"),
        ("STORE-03", "Web 本機警告", "Chrome 本機模式", "檢視說明並清網站資料測試", "明確提醒清網站資料／換瀏覽器會遺失可見性", "IndexedDB 實際位置與 owner key"),
        ("SUB-01", "到期與寬限", "雲端 Plus 超額到期", "模擬到期、+29 天、+31 天", "唯讀；顯示截止日與超額；31 天只刪超額並保留最新／保留項", "cleanup audit 與實際 quota"),
        ("SUB-02", "方案頁授權過濾", "B 無積分遊戲、C 有", "開方案頁", "B 不見積分／遊戲文字；C 看得到", "版本 quotas 原值不被改寫"),
        ("EXPORT-01", "Excel 完整性", "四語系與跨日期資料", "下載 Excel", "只有行事曆、回憶、記帳、積分頁簽；欄名／值語系化；全日期；無 Sheet1", "排序、千分位、幣別、兩級分類"),
        ("DELETE-01", "刪除帳號申請", "一般使用者", "申請、重複申請、取消、管理者確認", "依序顯示申請中／撤銷；管理者確認才刪除", "申請狀態與 auth.users"),
        ("STOCK-01", "日期與搜尋", "管理員或已授權使用者", "等待更新完成，選舊日期並搜尋", "更新中禁選；成功／失敗後可選；搜尋同時篩兩清單；清除恢復", "只查現存 Supabase 表，不查 stock_daily_price"),
        ("PERF-01", "手機冷啟動", "Release 或 profile", "清程序後啟動 5 次", "無 MissingPluginException；可互動畫面穩定；無長時間白屏", "首幀、核心資料時間、錯誤 log"),
        ("PERF-02", "頁面生命週期", "慢網路", "快速進出股票、行事曆、回憶、推薦", "無 used after disposed、setState async、未捕捉 Future", "timer/stream/request token 已取消"),
        ("UI-01", "響應式", "手機、平板直橫向、Web", "逐頁切換並開所有 Dialog", "無 right/bottom overflow；文字可讀；按鈕可點", "Flutter error log 為空"),
        ("I18N-01", "四語系", "zh/en/ja/ko", "逐頁切換語系", "無簡體中文、硬編碼、placeholder 錯誤；長標題不截斷關鍵資訊", "flutter gen-l10n 與 analyze 通過"),
    ]
    doc.add_heading("2–11. 詳細測試案例", level=1)
    for case_id, name, precondition, action, expected, checkpoint in cases:
        doc.add_heading(f"{case_id}｜{name}", level=2)
        table(doc, ["欄位", "內容"], [
            ("前置條件／資料", precondition),
            ("操作步驟", action),
            ("預期畫面／行為", expected),
            ("資料／技術檢查點", checkpoint),
            ("實際結果", "＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿＿"),
            ("結果", "□ 通過　□ 失敗　□ 阻塞　　缺陷編號：＿＿＿＿＿＿"),
        ], [1.4, 5.6])

    doc.add_heading("12. 缺陷紀錄", level=1)
    table(doc, ["缺陷編號", "平台／版本", "重現步驟", "預期／實際", "嚴重度", "狀態"], [
        ("", "", "", "", "", ""), ("", "", "", "", "", ""), ("", "", "", "", "", ""),
    ])
    doc.add_heading("發布門檻", level=2)
    bullets(doc, ["flutter analyze：0 issue。", "自動化測試全部通過；不以忽略測試取代修正。", "P0/P1 缺陷為 0；資料遺失、跨帳號洩漏、權限繞過一律阻擋發布。", "四語系與五種版面完成抽查；Web 與 Android 至少完成一次完整搬移。", "Supabase 新 RPC、RLS、EXECUTE 權限已在正式環境以查詢結果驗證。"]) 
    return doc


def save():
    OUT.mkdir(parents=True, exist_ok=True)
    documents = {
        "Life_Pilot_使用者操作說明.docx": user_guide(),
        "Life_Pilot_開發者技術文件.docx": developer_guide(),
        "Life_Pilot_測試計畫與檢查點.docx": test_plan(),
    }
    for name, doc in documents.items():
        doc.core_properties.title = name.removesuffix(".docx")
        doc.core_properties.subject = "Life Pilot 完整產品文件"
        doc.core_properties.author = "Life Pilot"
        doc.save(OUT / name)
        print(OUT / name)


if __name__ == "__main__":
    save()
