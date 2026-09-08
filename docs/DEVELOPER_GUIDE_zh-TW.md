# Life Pilot 開發者技術文件

文件版本：2026-09-08

## 1. 系統概觀

Life Pilot 採三層式混合架構：

1. Flutter 客戶端：Web、Android、iOS 與桌面 UI、狀態管理、本機資料及部分外部資料解析。
2. Supabase：Authentication、PostgreSQL、RPC、RLS 與主要雲端資料。
3. FastAPI：代理外部活動、天氣、地理編碼及股票服務，並執行需要 service role／資料庫連線的清理工作。

主要技術：Flutter 3.35.4、Dart 3.6+、Provider、Supabase Flutter、FastAPI、SQLAlchemy、PostgreSQL、Sembast／IndexedDB。

## 2. 原始碼結構

```text
lib/
  accounting/       記帳
  apps/             主框架、設定、模組入口
  auth/             登入、註冊、密碼與權限
  business_plan/    Business Plan（管理者）
  calendar/         行事曆、提醒、分享
  event/            推薦活動／景點、爬蟲解析、地圖、天氣
  feedback/         意見回饋
  game/             各遊戲、題庫與進度
  local_storage/    本機資料與雲端／本機搬移
  memory_trace/     回憶走廊
  pages/home/       首頁及 Dashboard
  point_record/     積分
  stock/            股票（管理者）
  subscription/     方案、額度、版本化權益
  l10n/             ARB 與產生的語系類別
python_ai_service/  FastAPI 服務
supabase/migrations Supabase 正式 migration
test/               Flutter 單元與 Widget 測試
```

## 3. 本機開發

### 3.1 Flutter

```powershell
flutter pub get
flutter gen-l10n
flutter analyze --no-fatal-infos
flutter test
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

正式 Web API 預設為 `https://life-pilot.onrender.com`，可用 `API_BASE_URL` 覆寫。不要把 Supabase service role、資料庫密碼或簽章密碼寫進 Git。

### 3.2 FastAPI

```powershell
cd python_ai_service
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
uvicorn app:app --reload
python -m unittest discover -s tests
```

必要環境變數：

- `DB_URL`：PostgreSQL／Supabase pooler 連線字串。
- `SUPABASE_URL`：用於驗證 access token。
- `SUPABASE_ANON_KEY`：用於驗證 Supabase JWT。
- `CORS_ALLOWED_ORIGINS`：逗號分隔的允許來源；未設定時使用正式站與 Render 預設來源。

## 4. Flutter 架構慣例

- UI 頁面放在各模組 `page_*.dart`。
- Controller 使用 `ChangeNotifier`，非同步完成前後必須確認 `mounted`／`disposed`，避免已銷毀物件仍通知 UI。
- Service／Repository 處理 Supabase、FastAPI 或本機儲存，不在 Widget 內直接混合多個資料來源。
- `ControllerAuth` 保存登入者、管理者狀態、資料位置及訂閱快照。
- `main.dart` 透過 `MultiProvider` 建立共用服務與 Controller。
- 表名及共用欄位集中於 `lib/utils/const.dart`。
- 新增 UI 字串必須先寫入四個 ARB，再執行 `flutter gen-l10n`；不可在業務畫面加入未翻譯硬編碼文字。

## 5. 雲端與本機資料模式

`DataStorageLocation.cloud` 與 `DataStorageLocation.local` 為互斥主要來源。

- 本機儲存由 `LocalDataStore` 管理；Web 使用 IndexedDB，其他平台使用 Sembast 檔案。
- `ServiceLocalDataTransfer` 負責匯出雲端、寫入本機、額度預檢、雲端還原及確認後刪除來源資料。
- 搬移必須遵守「先複製、驗證成功、再刪來源」；部分失敗不可切換偏好位置。
- local → cloud 必須先取得全部資源筆數並一次檢查額度；超額時整批取消。
- cloud → local 會撤銷行事曆分享，避免本機刪除後回雲端出現不一致。
- 新增資料服務必須明確依目前資料模式選擇 Supabase 或 LocalDataStore，不能在本機模式仍送出空 ID 的雲端請求。

## 6. Supabase 資料與安全

### 6.1 主要表

- 個人：`calendar_events`、`memory_trace`、`accounting_account/detail`、`point_record_account/detail`、`dashboard_setting`。
- 推薦：`recommended_events`、`recommended_attractions`、`recommended_events_deleted/favor/stat`、`recommended_event_url`。
- 遊戲：`game_list`、`game_grammar`、`game_sentence`、`game_translation`、`game_social_*` 及各答題紀錄表。
- 訂閱：`user_subscriptions`、`subscription_pricing_versions`、`user_subscription_entitlements`、付款與清理稽核表。
- 分享：`calendar_share_invitations`、`calendar_share_events`。

### 6.2 權限原則

- `anon` 不應直接存取個人或業務表，也不應執行業務 RPC。
- `authenticated` 只取得實際需要的 SELECT／INSERT／UPDATE／DELETE 權限。
- RLS 以 `auth.uid()` 或 JWT Email 判斷擁有者；受邀行事曆只開放 SELECT。
- 高權限 RPC 使用 `SECURITY DEFINER SET search_path = ''`，函式內所有物件使用完整 schema 名稱。
- service role 僅留在 FastAPI／後端環境，不得放入 Flutter 或公開 repository。
- 管理者權限來自 JWT `app_metadata.role = 'admin'`，由受信任後端設定，不接受客戶端自行寫入。

### 6.3 Migration 流程

1. 在 `supabase/migrations/` 新增時間序檔案。
2. 優先使用 `IF EXISTS`／`IF NOT EXISTS`，確保可安全重試。
3. 修改 `RETURNS TABLE` 欄位時，先 `DROP FUNCTION schema.name(signature)`，再建立新版。
4. 在 transaction 內完成 schema、函式、RLS、grant/revoke。
5. 執行後查驗欄位、函式簽章、RLS、權限及資料筆數。
6. App 上線前先部署 migration，再部署呼叫新 RPC 的客戶端。

## 7. 訂閱與版本化額度

`subscription_pricing_versions` 保存不可變的方案版本；使用者付款時把該版本與倍率轉成 frozen snapshot 存入 `user_subscription_entitlements`。

- 舊版未到期時加購新版：新增 entitlement，不覆蓋舊 entitlement。
- `life_pilot_plan_limit(resource)` 加總所有目前有效、storage plan 為 cloud 的 snapshot 額度。
- 有效 local entitlement 回傳不限量；管理者亦不限量。
- UI 的 `get_my_subscription_entitlements()` 顯示每筆權益；`get_my_subscription_usage()` 顯示合計使用量／限額。
- 到期後 entitlement 不再納入加總。
- 管理者可建立價格版本、替換使用者方案或新增疊加權益。
- 正式付款尚需串接 Google Play／Apple In-App Purchase、後端收據驗證、付款事件冪等及 webhook。

基準免費額度為 30／30／30／30／50／2／0 bytes；基準 Plus 方案由資料庫版本控制，不可只寫死於 UI。

## 8. 推薦活動更新

更新流程：

1. 呼叫 `/event/start_public_event_refresh` 取得鎖 token。
2. 以 heartbeat 延長 15 分鐘執行權。
3. 讀取既有事件與 tombstone，建立正規化去重鍵。
4. 逐來源抓取、解析、驗證、地理編碼及寫入。
5. 管理者可直接寫入；一般手機使用者透過 `/event/import_public_events`，後端強制 owner 與核准狀態。
6. 至少一個來源成功處理才呼叫 complete；全部失敗則 abort，不寫今日完成標記。

去重原則：名稱＋開始日期＋時間＋正規化城市＋地點；匯入資料沒有時間時，再以名稱＋日期＋城市＋地點比對。來源 URL 存在時亦建立來源鍵。刪除過的公開活動以 `recommended_events_deleted` 阻止再次匯入。

重要 log：

- `Public event source completed`
- `Public event source failed`
- `Public event refresh summary`
- `Public event import batch failed`

## 9. 時間、國家、地圖與天氣

- PostgreSQL 時間欄位優先使用 `timestamptz`，Flutter 顯示前呼叫 `toLocal()`。
- 日期邏輯以 Asia/Taipei 為產品基準時區時，SQL 必須明確使用 `AT TIME ZONE 'Asia/Taipei'`。
- 國家以 ISO 3166-1 alpha-2 代碼保存，例如台灣為 `TW`。
- 一般 `lat/lng` 可供天氣附近位置使用；地圖精確位置使用 `map_lat/map_lng`，不可混用。
- `map_lat/map_lng` 已存在時不得重複呼叫地理編碼。
- 天氣只預抓可見、近期且在預報範圍內的資料；列表向下滑動時按需載入。

## 10. 發行與部署

### Web

GitHub Actions 在 master/main push 時執行 pub get、analyze、test 與 Web build；部署 workflow 使用 GitHub Pages。

### FastAPI

Render 執行 `python_ai_service`，健康檢查為 `/health`。部署後確認 CORS、DB_URL、Supabase 驗證參數及 migration 版本。

### Android／iOS

正式簽章詳見根目錄 `RELEASE_SIGNING.md`。Android 使用本機 `android/key.properties` 指向 upload keystore；不得提交真實 keystore 或密碼。iOS 使用 Xcode Automatic Signing、Apple Developer Team 及 bundle ID `com.minavi.life_pilot`。

## 11. 目前技術限制與後續工作

- 正式 App 內付款及收據驗證尚未完成。
- 推薦活動、景點與回憶資料量持續增加後，需全面改為伺服器分頁及條件查詢。
- 本機大量資料目前仍需逐資源掃描，後續可增加索引與分頁。
- 外部活動網站 DOM 可能變更，來源解析器需要監控與 fixture 測試。
- 免費無活動帳號自動清理涉及跨表刪除，正式排程前需在 staging 驗證 FK、稽核紀錄與可恢復流程。
