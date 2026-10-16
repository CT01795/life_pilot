# Life Pilot 開發者技術文件

本文件供接手 Flutter、資料庫與 FastAPI 的開發者使用。先建立可重現環境，再沿資料來源與 MVC 分工追查功能；涉及搬移、權益、帳號與提醒時，優先確認資料隔離及後端約束，不以畫面按鈕是否存在取代安全驗證。

基準提交為 41789f21，日期為 2026 年 10 月 16 日。最近一次程式驗證為 flutter analyze 通過、Flutter 測試 832 項通過。這不是 Android、iOS、Web 所有實機案例的完成證明。Supabase 遠端函式、排程、政策及資料不是本機 Git 的自動副本，部署前另做契約查核。

## 1 系統邊界與資料流

Life Pilot 有 Flutter 用戶端、Supabase Authentication 與 PostgreSQL，以及 FastAPI 三個主要邊界。Flutter 透過 Provider 協調畫面和狀態；Service 依資源與目前儲存位置呼叫 RPC、本機資料庫或外部服務。FastAPI 代理外部活動、天氣、地理編碼及股票，也執行需要受信任權限的帳號管理。

個人資料採雲端與本機互斥主要來源。推薦公開內容、外部天氣與股票不因個人儲存位置是本機就變成完全離線服務。搬移個人紀錄時必須對照支援資源清單，不能泛稱搬移整個網站資料。

### 主要目錄

| 路徑 | 責任 |
|---|---|
| lib/apps | 主頁切換 模組授權 儲存位置 |
| lib/auth | 登入 Recovery 帳號安全 身分生命週期 |
| lib/calendar | 月曆排版 事件操作 分享 提醒協調 |
| lib/event | 推薦活動景點 共用事件模型 搜尋 地圖 匯入 |
| lib/memory_trace | 回憶時間軸 卡片 預覽 |
| lib/accounting 與 lib/point_record | 帳戶 明細 日期分類 金額及積分 |
| lib/game | 題庫 各遊戲控制器 進度與平台編輯器 |
| lib/local_storage | Sembast IndexedDB 模式搬移 |
| lib/subscription 與 lib/vendor | 個人權益 廠商版本 額度與管理畫面 |
| lib/pages/home | 首頁 Dashboard 與跨模組摘要 |
| lib/utils | 日期 解析 分頁 輸入格式 網路及匯出工具 |
| python_ai_service | FastAPI 代理與管理 API |
| test 與 python_ai_service/tests | 單元 Widget 契約及後端測試 |
| docs 與 tool | 文件原始稿 Word 與產生工具 |

## 2 開發環境與版本基準

目前 pubspec.yaml 宣告 Dart SDK ^3.10.0，CI 固定 Flutter 3.47.4。不要沿用舊文件的 Flutter 3.35 或 Dart 3.6。實際開發機先以 flutter --version 確認，套件解析必須使用相容 SDK，不任意降版 idb_shim 來規避執行期問題。

主要套件包括 supabase_flutter 2.12.4、Provider、http、Sembast、sembast_web、idb_shim、flutter_local_notifications、Flame、speech_to_text、flutter_tts、excel 及 webview_flutter。依精確 pin、範圍與 pubspec.lock 安裝，不把文件列出的套件當成重新選版清單。

flutter_keyboard_visibility 指向 third_party 本地修補。flutter_html 使用 html 0.15.6 的 pin 是因上游內部 matches 相容問題；升級需先跑 Web 與 Android 建置，不要因看似舊版就直接刪除 override。

### Flutter 日常指令

```powershell
flutter --version
flutter pub get
flutter gen-l10n
flutter analyze
flutter test --concurrency=2
flutter run
```

效能測量使用實機 Profile，不能直接用 Debug 與桌面瀏覽器比裝置能力：

```powershell
flutter run --profile
flutter build web --release --base-href "/life_pilot/"
```

目前 CI 的 API_BASE_URL 指向 Render 服務，可用 dart-define 覆寫。私人 Mac API 是另一資料來源，不能把它當作所有雲端功能都可依賴的永久服務。文件與 Log 不寫入 access token、資料庫密碼或 service role。

### Android 與 iOS

Android namespace 與 applicationId 是 com.minavi.life_pilot，Gradle wrapper 為 9.1.0，AGP 為 9.0.1，Kotlin plugin 為 2.3.20，Java target 17。目前仍有 Kotlin plugin，相容性警告要依實際 Flutter 與套件狀態處理，不在文件宣稱已完成 Built-in Kotlin 全面遷移。

Release 使用 android/key.properties 與對應 keystore，缺少設定會拒絕 Release 建置。不要改回 Debug key 來讓正式建置通過。簽章、keystore 密碼與環境設定不可入 Git；App 版本 1.0.0+1 是目前 pubspec 值，不代表商店已上線。

iOS 原生設定有 lifepilot URL scheme、麥克風、相簿與語音辨識用途說明，iPad 有直橫向設定。iOS 簽署、Team、裝置允許與發佈需在 Mac 和 Xcode 另驗證；Windows 測試通過不能代替 iPad 實機結果。

## 3 MVC 分工與重構原則

Page 與 Widget 負責輸入、導航、顯示狀態及畫面生命週期。Controller 負責查詢協調、載入旗標、請求世代與通知。Model 負責排序、篩選、排版、資料轉換及衍生快照。Service 或 Repository 才負責網路與本機儲存。

既有檔名不代表責任完全純化，例如 ModelDashboard 仍有非同步協調與通知。接手時先維持公開契約，再逐步抽純邏輯，不把全專案描述成已經完全符合嚴格 MVC。

### 新增功能的實作順序

1. 明確列出來源、所有權、日期時區、額度與失敗狀態。
2. 純排序與驗證放 Model，先寫單元測試。
3. Service 定義輸入輸出契約，不接收 BuildContext。
4. Controller 控制在途請求、舊結果與狀態轉換。
5. View 只監聽所需欄位，導航與彈窗保留在 View。
6. 增加 Widget、資料來源及實機負向測試後再改 UI。
7. 重構先以等價測試保留排序、載入更多、共享唯讀與關聯入口，不順便改需求。

不要為抽象而建立多層轉發。少量且用途明確的介面，比所有函式一律包成 Repository 更容易維護。

## 4 啟動 登入與帳號生命週期

先建立 Flutter binding，完成必要的 Supabase 初始化，再讓登入畫面使用服務。通知與時區初始化要有明確完成或失敗處理，不能讓 MissingPluginException 變成無限啟動畫面。

Web 只處理當前 URL 的 Recovery 資訊；原生 App Links 監聽只留 Android 與 iOS，銷毀時取消。Recovery 要高於既有已登入首頁的路由判斷，A 的信件不能因已登入 B 而被略過，格式錯誤及過期 URL 要有可操作結果。

ControllerAuth 的身份來自 Supabase session。管理者判斷使用 app_metadata.role，不接受一般使用者自行改 user_metadata 或本地布林值取得權限。廠商角色與個人角色分開，主選單還需模組授權。

帳號檢查在啟動及回前景強制進行，一般操作主動檢查以 120 分鐘節流並共用在途請求。AuthSessionGuard 與共用 HTTP client 回報 401、user_not_found、session_not_found、invalid_jwt 等失效狀態。不要把一般網路失敗直接當成帳號遭刪而清掉本機資料。

### 舊請求隔離模式

```dart
final generation = _dataScopeGeneration;
final result = await service.read();
if (!_isCurrentDataScope(generation)) return;
// 只在帳號 模式與世代仍一致時更新 Model
```

這是示意模式，實際公開更新與行事曆還有 request token。資料範圍切換時要重設 Model、分頁、城市與 ViewModel 快取；finally 也需防護，避免舊請求關掉新請求的 loading。取消通知監聽與真正取消 HTTP 是不同層次，guard 不代表已中斷網路。

## 5 頁面初始化與監聽管理

ControllerEvent.initializePage 將進頁查詢、公開更新狀態與可選更新集中協調。在途呼叫共用 Future，完成或失敗後清掉，不是把整頁資料永久快取。

```dart
final pending = _pageInitialization;
if (pending != null) return pending;
final generation = _dataScopeGeneration;
final completion = Completer<void>();
final operation = completion.future;
_pageInitialization = operation;
```

必須先設定在途 Future 再啟動工作，才擋得住 notifyListeners 造成的重入。完成時只清同一個 operation，不能讓舊帳號的 finally 清掉新帳號初始化。

GenericEventPage 與 MemoryGenericEventPage 只呼叫 Controller 的 initializePage。頁面擁有的 ControllerAppBarActions、ScrollController、Timer 與 listener 需在 dispose 釋放；共享 Provider 服務不能被單一子頁關掉。

Calendar 的語系監聽用具名方法，dispose 移除。Widget 更新 Controller 實例時，didUpdateWidget 移除舊監聽並掛新監聽，避免畫面已換來源卻仍收到舊事件。

## 6 雲端與本機資料路由

LocalDataStore 使用 owner 正規化與 resource 隔離，記錄鍵包含 owner、resource、id。Web 用 IndexedDB，原生平台在 getApplicationSupportDirectory 的 life_pilot_local.db 保存 Sembast。完整絕對路徑依 OS、App 安裝及使用者而定，不應寫死 Windows C 槽。

ServiceEvent 查詢可接收已知 storageLocation，避免雲端讀取前先開本機 DB：

```dart
return (storageLocation ??
        await LocalDataStore.instance.preferredLocation(owner)) ==
    DataStorageLocation.local;
```

此判斷還先限制 calendar_events、memory_trace 與有效 owner。推薦活動景點仍是線上內容。Controller 在初次、歷史 fallback、hasOlder 與載入更多都傳 auth.preferredStorage，不能只修第一個查詢。

不要將「只讀一個主要來源」誤解成整個 App 只會連一個後端。方案、公開內容、外部導航及身份檢查仍可能需要網路；離線測試需區分個人資料可用與外部資料可用。

## 7 本機快照與資料完整性

readOnlyRows 共用快取 Future 與唯讀清單，查詢端不再每次把所有 Map 重新複製。舊 list 保留可修改的頂層副本，避免破壞既有呼叫契約。

```dart
final request = _listCache[cacheKey] ??= _loadList(owner, resource);
return await request;
```

快取 key 必須含帳號與資源。寫入、更新、刪除與清空後沿既有 invalidation 清掉相應快取；失敗的 Future 也移除，讓下一次能重試。List.unmodifiable 與 Map.unmodifiable 不是深度遞迴凍結，巢狀值仍須當唯讀，不能用快照當編輯緩衝。

LocalDataStore.withDatabase 可注入獨立記憶體 DB，測試不動 singleton 或正式個人資料。本機大資料的下一步是索引或分頁，不是無限提高記憶體快取容量。

ModelLocalEventQuery.iterate 先篩 id、日期及 offset，再解析 EventItem。select 保持舊介面並收集 iterate 結果。latestRowBefore 單次比較找最大日期，取代整批日期排序，維持既有可解析日期格式。

## 8 搬移流程與失敗邊界

ServiceLocalDataTransfer 的支援清單包含個人行事曆、回憶、記帳與積分帳戶明細、自建語言及社交題目、相關詳細答題紀錄與遊戲進度。dashboard_setting 另行處理。公開推薦表不在這個個人搬移清單內。

### 雲端到本機

讀取遊戲目錄及首頁設定，再呼叫 export_my_cloud_data_for_local。逐筆檢查資源與 ID，拒絕本機同 ID 衝突，寫入本機並記錄 staged。全部寫入後呼叫 delete_cloud_records_and_revoke_shares_after_local_copy，核對刪除筆數，再由畫面更新位置。

例外路徑嘗試清除 staged 與本次設定。這是補償式處理，不是本機與雲端的分散式交易；網路在伺服器提交後中斷時，仍須人工核對兩端，不能宣稱任何失敗都保證完全零變更。

### 本機到雲端

蒐集支援資源與首頁設定，normalize country 等欄位，再用 restore_local_personal_records_with_setting 一次交付後端。成功筆數需等於 payload 長度，才清除該帳號本機來源紀錄。空資料與只有設定的情境也要測。

額度預檢與真正寫入都要由後端保護；只在 Flutter 預檢無法阻止並發超額。不要在復原失敗時先刪本機，也不要以 DB 容器名稱存在與否判定搬移。

### 必測失敗

重複 ID、缺 country、來源已變動、目的端額度不足、中途離線、回應遺失、使用者換帳號、刪除筆數不符及 retry。記錄來源與目的端筆數與 ID，不把 moved 數字當成逐欄資料校驗或 checksum。

## 9 回憶首屏分批載入

雲端回憶邏輯頁為 50 筆顯示，加一筆 lookahead。最新調整只把有 onPartialEvents 且 offset 為零的初次網路批次改為 6 筆，後續填滿同一邏輯頁。

```dart
initialBatchSize:
    tableName == TableNames.memoryTrace &&
        onPartialEvents != null &&
        offset == 0
    ? 6
    : null,
```

readPagedRows 依實際已收筆數推進 offset，不能因回傳數小於要求就判定結尾，因 RPC 可能有自己的 cap。重複 id 視為 offset 契約異常，不無聲宣告已到最後一頁。

```dart
final remaining = limit - rows.length;
final batchLimit =
    rows.isEmpty && initialBatchSize != null &&
        initialBatchSize < remaining
    ? initialBatchSize
    : remaining;
final batch = await fetch(offset + rows.length, batchLimit);
if (batch.isEmpty) break;
```

資料累積每批通知 onProgress，Service 只解析 rows.skip(decoded.length)，避免已收資料每批重新轉換。Controller 發布主清單副本並排序，不能讓排序改變 Service 正累積的 buffer。

24 筆範例為 offset 0 取 6、offset 6 要 45 回 18、offset 24 要 27 回空。總照片量不變，通常多一次查詢；加速的是首批，不保證全部載入完成更快，也不是縮圖服務。

本機有回呼時先解析 12 筆、讓出事件迴圈，再繼續；每 100 筆也讓出。這只改解析節奏，不把本機紀錄上限改成 12。

## 10 首筆顯示與背景工作狀態

isLoadingMemoryRecords 控制主要資料是否仍在讀取，與可選 hasOlder 檢查分開。partial preview 可以先顯示，但在主要載入期間用 IgnorePointer 暫停卡片操作及新增按鈕，避免載入結果覆蓋使用者剛編輯的資料。

```dart
if (!_isCurrentDataScope(generation) || rows.isEmpty) return;
_modelEvent.setEvents(rows.take(_cloudPageSize).toList());
_modelEvent.sortMemoryEvents();
_hasLoadedEventsSuccessfully = true;
_hasMoreMemory = true;
_invalidateViewModelCache();
notifyListeners();
```

主資料完成即解除 isLoadingMemoryRecords；hasEventsBefore 最多等待十秒，失敗保留內容及重試入口。loadMore 遇到前次主載入錯誤時先重載，不沿用不完整 offset。

近 30 天無資料時先找最新舊日期。摘要查詢只取 id、name、日期時間、country、city、location、account，不重複抓 master_graph_url 與 sub_events，先顯示摘要，再查該日完整紀錄。未來紀錄仍要依現有查詢範圍保留，不能用「回憶只能過去」自行裁掉。

## 11 延後解析子活動

EventItem.fromJson 不再立即把全部子活動轉成 EventItem，而以 DeferredList 儲存逐筆 loader。EventViewModel 的子項也用 LazyMappedList，避免清單只檢查有無子活動時就先格式化全部子畫面。

```dart
.._subEvents = DeferredList<EventItem>(
  subEventsJson.map(
    (row) => () => EventItem.fromJson(json: row),
  ),
);
```

LazyMappedList 對 DeferredList 使用不解碼的 membership snapshot，其餘來源複製 membership。每個元素的成功結果只建立一次，nullable 值也可快取，失敗可重試。它是唯讀衍生清單，不能拿來 add。

DeferredList 維持可編輯 List 介面，寫入前 materialize 成一般 growable List。複製、序列化或完整預覽仍可能需要讀全部元素，這是必要成本，不應偷偷丟掉內容。延後也可能把錯誤發現時機移到讀取子項；對不可信資料應增加欄位驗證與錯誤隔離。

目前回憶清單 showSubEvents 為 false，完整預覽仍呈現子活動。不要再寫成清單只顯示三筆子活動，程式並不是這個規則。

## 12 卡片 圖片與篩選重建

WidgetsMemoryCard 不再用 AnimatedBuilder 對 Controller 每次通知重建整張卡片。State 訂閱 Controller，只在自己位置的 forecast 或日期邊界改變時額外 setState。

```dart
if (_weatherDay == DateTimeFormatter.dateOnly(DateTime.now()) &&
    listEquals(_forecast, forecast)) {
  return;
}
setState(_readForecast);
```

forecast 快照複製 membership，能發現同一 List 被替換元素。EventWeather 欄位為 final，有利相等比較。didUpdateWidget 處理控制器替換，dispose 移除 listener。ViewModel 由父層更新時仍正常重建，因此編輯儲存不被這個天氣篩選擋住。

WidgetsEventImage 的 Base64 bytes 快取以 8 筆與 24 MB 為限制，圖片解碼使用背景 compute，Image 使用 cacheWidth 與 cacheHeight 等縮小解碼尺寸。這是裝置端解碼優化，不是網路傳輸壓縮。大量 Base64 仍會在 RPC body 下載，不能說已有真正原圖懶載入。

ModelEventProjection 依來源清單 identity 與完整 predicate key 快取作者篩選。key 包含廠商身分、我的投稿開關及 currentAccount。未提供 key 一律重算，避免錯誤快取。ModelEvent 先排除日期與已刪項，再在真的有關鍵字時建立搜尋文字，保留原本篩選語意。

## 13 回憶效能診斷與實測解讀

LoadTiming 預設在 Debug 與 Profile 啟用，Release 停用輸出。只記固定 stage、經過時間、上個 stage 間隔與筆數，不記帳號、內容、圖片或 token；不增加雲端查詢。

主要標記為 load_start、mode_cloud 或 mode_local、rpc_start、rpc_returned、batch_decoded、complete、first_content_frame 與 initialization_complete。first_content_frame 是該幀 post-frame callback，不等於 GPU 呈現、全部圖片完成或可互動時間。

使用者提供的一次手機樣本：RPC 回傳約 1483 ms，24 筆 EventItem 轉換約 15.6 ms，首屏約 1954 ms。SQL Editor 執行 RPC 為 13.524 ms。另一查詢估計原始 JSON 1432.3 KB，其中圖片欄位 1402.2 KB，子活動約 0 KB。這些是單次診斷樣本，且 SQL Editor 身分與 App RLS 路徑不同，不能當效能保證。

這表示該樣本優先處理傳輸量與首批等待，而不是繼續調整子活動解析。後面的空頁探測約 647 ms 在首屏後完成，刪掉它不會等比例縮短首次顯示，卻可能讓分頁判斷錯誤。

### 可重現測量方式

1. 同裝置同帳號同模式同網路，先記錄版本、資料筆數及圖片量。
2. Profile 測五次冷進頁及五次暖進頁，記錄中位數與最慢值。
3. 分別量首內容、可互動、全部主要資料及圖片完成時間。
4. 比較各 stage，不只比轉圈數或以手機 Debug 對桌面 Release。
5. 對照片多、無照片及慢網路各重測，核對資料完整性與 API 次數。
6. 保留最慢案例並檢查 frame、GC、圖片 decode，拒絕用隱藏 spinner 取代真正改善。

未來真正降低流量可考慮縮圖與原圖分離、圖片專用儲存及可見區域載入，但需同時設計 quota、權限、離線搬移、編輯前 hydrate 與刪圖清理。不可直接從清單移除圖片欄位後又把 null 寫回造成照片遺失。

## 14 推薦內容更新與分頁

推薦活動與景點即使個人模式為 local 仍用線上分頁。公開更新完成後最多取 51 筆，維持 50 筆顯示與 next offset，不能更新後突然變成下載全部資料。

公開更新有 success、running、failed 等狀態，更新按鈕顯示依政策而非只看按過一次。離頁或帳號切換後的狀態回應及 finally 都檢查 scope，不允許舊工作蓋掉新工作狀態。

Like 與 Dislike 不應每次重下載全部內容，不喜歡以排序往後，不是從結果刪除。排序交 ModelEventOrdering：活動先 preference，再 effective start date、start time、end date、country、city、location、name；早於今天的 start 只在排序鍵視同 today。景點依 preference 再地點鍵。缺時間會用排序預設值，不能擅自把缺時間寫成現在。

投稿作者不可被審核動作改成管理者。is_approved 與曾公開狀態相關刪除規則需後端保護，作者編輯後待審也不能假裝從未公開。互動計數與可見性 RPC 也要檢查目標表、id 與事件是否可讀。

## 15 行事曆資料與跨月快取

ControllerCalendar 仍保留前後月份查詢，以支援跨月活動與月曆第一最後列。此輪沒有用 TTL 略過相鄰月份下載；改的是日期分組與排版運算快取。

ModelCalendar.groupEventsByWeekAndDay 先 normalize 每個事件的日期區間一次，再分到各天，避免每個日格重複轉換。ModelCalendarWeekLayout 保存同一月份快照的區間與逐週 row layout，Controller 只委派 Model。

```dart
final source = eventsForMonth(month);
var layout = _weekLayouts[key];
if (layout == null || !identical(layout.source, source)) {
  layout = _weekLayouts[key] = ModelCalendarWeekLayout(source);
}
return layout.forWeek(weeks[weekIndex].first, weeks[weekIndex].last);
```

cacheMonthEvents、invalidateEventRange 與 clearAll 必須同時清 week layout。若 EventItem 原地更動卻不走 invalidation，identity 快取可能過期；所有新增修改刪除及跨月轉移要從 Controller 的正式流程進入。

查詢完成後先檢查 disposed、generation、scope 與每月 token，再啟動天氣 warmup，舊結果不能再安排不必要外部請求。這不等於取消已發出的網路。

### 月曆重建範圍

PageCalendar 把 CalendarBody 放 AnimatedBuilder.child，月份操作列仍更新。星期標頭另用 Selector 監聽 isCurrentMonth，主體以日期 Selector 保留今日顯示更新。月資料與每週列仍獨立監聽，所以不能把穩定 child 理解成永遠不更新。

## 16 行程加入 完成與跨模組關聯

推薦加入行事曆使用共用日期時間確認流程。未來來源保留未來日期；已開始或當日來源依開始時間與現在時間決定預設。最後以使用者確認值建立單日行程，首頁與兩個推薦頁一致。

新增、修改與刪除後需清首頁及月曆受影響範圍；跨到畫面邊界的鄰月也在失效範圍。不能只清 DateTime.now 的月份或只刷新當下可見頁。

完成行程可選填回憶、收入支出及加扣分。回憶預設不勾，收支與積分共用一組日期時間，積分入口依模組權限。subEventsForDate 只帶當日適用子活動，避免跨日全部內容複製入一筆回憶。

記帳與積分關聯以事件與實際帳戶記錄定位，卡片快捷入口應直達對應帳戶明細。複製內容至其他頁面是建立新資料，不保證後續同步，亦不授予修改共享原事件的權限。

## 17 首頁 Dashboard 的等待依賴

移除 PageHome.initState 重複啟動核心載入，保留 build 的 post-frame 入口並在真正執行前再檢查帳號與積分授權是否仍需更新。

推薦區塊只需保存的城市設定，不應等待記帳、積分等所有摘要：

```dart
final dashboard = context.read<ModelDashboard>();
await dashboard.waitForSettings(account: account);
if (!mounted || context.read<ModelAuthView>().account != account) return;
```

ModelDashboard 抽出 _loadSettings 與 _readSettings，保存 _settingsLoad 與 request sequence。waitForSettings 等待目前請求，若中間換成新設定請求會跟隨，不增加一個讀取設定的 API。寫回需同帳號同 generation 且 request 最新。

首次預設收合推薦、記帳及積分，近日行程展開。使用者展開才啟動相應 lazy 載入，pull refresh 仍依已啟用區塊處理。不要把折疊狀態當成資料已清除，也不要漏掉完成行程後必要的摘要刷新。

## 18 日期 時區 小數與分類

日期與時間在 EventItem 分開保存，parse 與存回時分辨 UTC timestamp、local day 與 TimeOfDay。單日日期不可經錯誤時區轉換變成前一天。轉換一次並有凌晨、跨年、UTC 正負時差測試，不能為顯示補八小時又重複 toLocal。

記帳與積分明細以 date 作查詢與排序，可編輯日期及分鐘。保留項使用 primary_category = reserved，不再靠 description LIKE 餘字。income 與 expense 有不同分類；積分有 virtue、intelligence、fitness、social、arts 等穩定鍵，顯示用 l10n。

金額文字輸入最多四位小數，修正多餘小數點與截超出位數，不清空全欄。千分位是顯示格式，送後端前轉回有效數值。TextEditingValue 的 selection 與 composing 必須落在新文字範圍內，尤其 Web 退格至空字串與 IME 組字。

資料庫金額欄位使用 numeric 而非因 UI 需要小數就換 float8；實際 scale、RPC 參數及舊 overload 必須查遠端。前端可輸入四位不表示 SQL bigint 的函式已自動支援。

## 19 訂閱版本與累加權益

ServiceSubscription 並行取 usage、status、entitlements，再依目前 storagePlan 取 cumulative quotas。不可用最新一筆 entitlement 的模式推斷目前資料位置。

有效權益由版本快照、倍率、起訖日與 resource 決定。舊版未到期新增新版應是另一筆 entitlement；仍有付費權益就不再加免費額度。相同本地到期日分組後整組移除，再算 remaining quotas，顯示近期兩階段，不因兩筆時間不同顯示虛假的兩次下降。

SubscriptionExpirySchedule 區分 partial 與 all。若最近到期但仍有較久的有效權益，呈現剩餘累加額度；全部相關權益均在十五天內到期才使用全部到期提醒。跨年度顯示包含年。

本機適用資源的 0 可表示不限制，顯示層須依資源及模式解讀；本機不支援共用行事曆，推薦投稿亦不應誤當無限。過期無有效本機使用權者設本機 create permission false，新增及修改由集中層拒絕，不只按鈕反灰。

雲端有效額度下降與超額清理要以目前有效總額計算。清理只移除超額部分，最新資料與保留項的保留政策由後端契約保護；前端有按鈕不代表每天排程已存在。付款串接、收據驗證及 webhook 需獨立部署，不能把管理員手動開通當成已完成商店扣款。

## 20 管理介面與廠商權益

AdminSubscriptionEditor 先依 Email 查詢。已有有效權益而未選新增時跳確認，避免加購操作誤覆蓋。每筆 entitlement 以 ID 編輯或刪除，不用 Email 刪除整組來代替刪單筆。延長 N 天與管理者摘要使用相應 RPC，查無資料與讀取失敗不能混為空資料。

收費版本同名更新、異名新增，刪除前由後端確認未被使用。個人與廠商不同版本表及 Service，倍率與快照要在各資源測試，不只檢查畫面價格。

不限額度活動包含多段區間、指定帳號與提醒天數。空名單適用設定範圍內一般使用者，指定名單按正規化 Email 判斷。開始、結束與提醒邊界由 Timer 重載狀態，回前景也須重新確認。不要用活動 UI 隱藏訂閱頁就認為後端寫入一定豁免。

廠商工作台顯示目前權益、近期投稿、公開待審比例及互動計數。偏好、收藏、瀏覽不是實際轉換，統計需考慮重複請求、機器人、表別與所有權；這些可列後續分析工作，不假稱已完成完整反作弊。

## 21 分享與提醒契約

ServiceCalendarSharing 先 requireCloudMode，邀請清單只取 pending、accepted。shareableEvents 來自當前已載入的自己的有日期事件，去重後由近到遠，包括符合可見範圍的過去事件。全選是目前清單，不是永久訂閱全部未來事件。

分享 RPC 要支援追加指定 ID、不覆蓋之前月份；重邀需重設待接受、清除過期狀態；拒絕、停止查看及停止分享釋放有效額度。calendar_share_events 與 invitation 表需有一致的參與者 SELECT 政策及擁有者寫入限制。RLS 是最後防線，前端唯讀按鈕不是安全保證。

NotificationServiceMobile 使用 flutter_local_notifications 排程，依精確鬧鐘權限選 exactAllowWhileIdle 或 inexactAllowWhileIdle；拒絕權限及 OS 電池限制都要實測。Web 走畫面提醒，不把兩者當作同一背景推播。

跨裝置完成事件需要手機同步雲端 is_completed 後取消已排通知。後端目前不是對關閉 App 永遠推送取消指令的保證。提醒 ID 使用事件與選項，重排要取消舊選項集合。通知重啟、時區變動、強制停止與重複事件另列實機風險，不以單元測試取代。

## 22 遊戲與 Blockly 維護

QuestionBankAvailability 對 Translation 類合計至少三題，其他使用題庫遊戲至少一題，再依來源規則過濾關卡及分類。requiresThreeInGroup 是保留的舊欄位名稱，現行語意不是每分類三題。管理題庫與我的題庫共用可玩性檢查，本機只使用自己的題庫。

GameQuestionSourceRules 保留穩定名稱 Translation (CH-EN)、Translation (CH-JP)、Translation (CH-KR)，不要拿 l10n 顯示字串作資料庫主鍵。系統題庫擁有者常數與 admin role 是兩個判斷來源，測試要分開。

GameHelpButton 使用 l10n 與共用顏色。GameSpeechTooltip 只提示、按下才播放，不自動 hover 朗讀。非同步 TTS、audio、Flame component 移除及子彈碰撞，要避免在遍歷中破壞集合或等待未完成語音而卡住更新迴圈。

Scratch 使用 Web iframe 與原生 WebView 的不同 bridge，request 回應以識別與 queue 隔離回合。一次開始只處理一次目前工作區，不能同時由舊 listener、輪詢或重送 bridge 執行。離開確認 Future 及 Navigator context 需 mounted 防護。

ScratchWorkspace 的窄畫面為上下，原生 editor 與 board 比例依現行設定；寬 Web editor flex 2、board flex 1，編輯器內左右分區，形成三區。600 為目前版面斷點。旋轉維持同一元素樹，避免每次重建 WebView 丟掉積木。原生拖曳不要再包競爭手勢的 Flutter drag scroll。

## 23 Excel 匯出與個資處理

ServicePersonalData.export 呼叫 export_my_cloud_data_for_local，使用 range 每次最多 1000 wrapper rows 迴圈取回，再只輸出允許的個人表。畫面是否顯示匯出入口依目前雲端模式，無刪除資料的副作用。

Excel 第一頁是 l10n 匯出說明，刪除預設 Sheet1；分頁與欄位標題依目前語系，使用者自由文字保持原文。個資匯出只有行事曆、回憶、記帳與積分的畫面對應欄位，不把全部 DB 欄位、題庫或推薦資料通通洩出。

account_name 先由帳戶表關聯回明細，date 拆成顯示日期時間，category 與 secondary_category 分開。系統分類鍵翻譯，未知自由值保留。貨幣與數值千分位為可讀性格式，但目前匯出以 TextCellValue 為主，不保證是可直接 SUM 的數值欄型態。

頁面 ServiceExportExcel 是另一套活動表匯出工具，可能只取目前已載入內容並含活動專用欄位；不要與完整個資匯出混淆。大量匯出需考量記憶體、取消與長任務進度，目前不要承諾無限量匯出一定不耗記憶體。

申請刪帳、取消申請、管理者確認撤銷與真正刪帳分別呼叫不同 RPC。送出申請不能顯示已刪除成功。清理個人資料的按鈕不等於刪除 auth.users，管理者刪帳後需同步處理 session 失效。

## 24 RPC 與 API 查核清單

| 功能 | 主要介面 |
|---|---|
| 事件查詢 | get_filtered_calendar_events get_filtered_memory_trace get_filtered_recommended_events get_filtered_recommended_attractions |
| 記帳新增 | add_accountings_batch2 |
| 積分新增 | add_point_records_batch |
| 分享 | invite_calendar_viewer respond_calendar_invitation revoke_calendar_invitation remove_calendar_shared_event get_my_shared_calendar_events |
| 個資搬移 | export_my_cloud_data_for_local delete_cloud_records_and_revoke_shares_after_local_copy restore_local_personal_records_with_setting |
| 訂閱讀取 | get_my_subscription_usage get_my_subscription_status get_my_subscription_entitlements get_my_cumulative_subscription_quotas |
| 訂閱管理 | admin_get_user_subscription admin_get_user_subscription_entitlements admin_list_user_subscription_summaries |
| 權益異動 | admin_add_user_subscription_entitlement admin_update_user_subscription_entitlement admin_delete_user_subscription_entitlement |
| 個人版本 | get_subscription_pricing_versions admin_create_subscription_pricing_version admin_update_subscription_pricing_version admin_delete_subscription_pricing_version |
| 活動豁免 | get_quota_free_period admin_set_quota_free_period admin_delete_quota_free_period |
| 清理 | get_subscription_cleanup_preview cleanup_subscription_data |
| 刪帳 | request_account_deletion cancel_account_deletion_request admin_delete_account_and_data admin_confirm_account_deletion_cancellation |
| 後端管理 | POST /account/admin/create-user POST /account/admin/reset-password |

上表是呼叫契約索引，不代表遠端均已部署或簽章永遠不變。完整參數以 Service 原始碼與 pg_get_functiondef 對照，尤其舊函式 overload、json 與 jsonb、text ID 與 uuid 差異。

### 唯讀契約檢查

```sql
select n.nspname, p.proname,
       pg_get_function_identity_arguments(p.oid) as arguments,
       pg_get_function_result(p.oid) as return_type
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prokind = 'f'
order by p.proname, arguments;
```

再查 pg_policies、table_privileges、pg_indexes 與具體函式 execute grants。沒有 RPC 的 404 不能用前端重試假裝成功。RETURNS TABLE 改欄位需處理舊回傳型別與相依物件，不在正式庫盲目 DROP CASCADE。

目前 tool/*.sql 刻意不進 Git，專案沒有可直接信任的完整 migration 目錄。部署單應另記執行腳本、版本、時間、前後查驗與回復方案；不要再教接手者照一個不存在的 migrations 目錄操作。

## 25 FastAPI 啟動與部署

後端使用 Python 3.11，依 requirements.txt 建環境。不要將本機文件製作的 Python runtime 當後端正式 Python 版本。資料庫 URL driver 與已安裝 psycopg 或 psycopg2 必須對應，曾出現的 ModuleNotFoundError 需從依賴與 SQLAlchemy URL 一起查。

```powershell
cd python_ai_service
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
uvicorn app:app --reload
python -m unittest discover -s tests
```

環境變數包括 DB_URL、SUPABASE_URL、SUPABASE_ANON_KEY、SUPABASE_SERVICE_ROLE_KEY 及 CORS_ALLOWED_ORIGINS。只列名稱，不在文件放值。service role 僅後端使用，不能因前端要幫管理員重設密碼就放進 Flutter。

/account/admin/create-user 與 reset-password 必須有 require_supabase_admin 依賴。管理者輸入一般或廠商信箱，API 直接建立已確認帳號或設定暫時密碼，再由管理者回覆；不能把 API 回傳 temporary_password 視為寄信完成。

Render 常用 uvicorn app:app --host 0.0.0.0 --port $PORT --workers 1，工作目錄需與 app.py 對應。先查 /health、CORS、JWT 驗證與資料庫，再查外部資料來源。啟動失敗與路由 503 分開排查，不以開放所有來源或移除驗證作長期修補。

## 26 安全 權限與清理排程

一般 authenticated 僅取得所需資料與函式權限；anon 不應讀個人表。SECURITY DEFINER 必須固定 search_path 並在函式內核對 caller，不接受 inputuser 參數等於已授權的假設。分享只 SELECT，帳戶與明細需防跨 owner；管理按鈕隱藏不是安全防護。

清理超額、雲端答題紀錄保留及無效帳戶處理均需查實際排程。查有函式不代表排程每天執行，查 cron.job 前先確認 pg_cron 是否啟用，非測試庫不直接跑清除驗證。

```sql
select to_regclass('cron.job') as cron_job_table;
select indexname, indexdef
from pg_indexes
where schemaname = 'public' and tablename = 'memory_trace';
```

用合成帳號測到期及清理，先 preview，再清超額，核對最新資料、reserved 與無關帳號不變。留 audit 並避免 Log 記錄完整私人 payload。資料庫備份、復原、金鑰輪替與事故處理需有維運流程，不能用程式單元測試宣稱已完成。

## 27 測試 發佈與日常維護

CI 對 master 或 main 跑 pub get、語系產生相容性分析、Flutter 測試、Web Release；Python job 跑 compileall 與 unittest。實際 workflow 以 .github/workflows 為準，測試數量會隨提交變化。

提交前執行嚴格 flutter analyze 與 flutter test --concurrency=2，必要時跑單一檔找出負向測試的預期 Log。錯誤日誌不必然代表測試失敗，以測試結果與 exit code 判斷；也不能只看到 832 passed 就忽略未跑的實機場景。

三份文件重產使用 docs 的使用者與技術 Markdown、測試案例資料與 tool 內文件工具。生成 DOCX 後先做 ZIP/XML 結構與 Word 相容檢查，再輸出 PDF 及逐頁圖像驗版。不要把二進位產生成功當作 Word 一定可開，尤其舊版 Word 的 OOXML 元素順序。

發佈順序為核對資料庫契約、部署後端、驗證健康與授權、部署客戶端、執行各裝置冒煙、觀察效能與錯誤。簽章、Recovery URL、外部權限、訂閱清理、投稿審核與跨裝置提醒均要列上線門檻。

## 28 維護時優先保護的規則

保持舊資料與新資料的日期排序一致；保留項不改回文字餘判斷。雲端與本機權益依位置分算；同日到期整組移除。共享只讀與原作者不變；曾公開內容不能由非管理者刪除。搬移先確認後執行，只有可驗證成功才清來源。首屏較早不代表下載較少；新增快取必須同時設計失效。

建議後續依量測處理縮圖傳輸、本機大資料索引、長匯出記憶體與伺服器分頁契約。每項改善先記現況、加入回歸案例，再比較同條件實測，不承諾沒有證據的百分比或秒數提升。

