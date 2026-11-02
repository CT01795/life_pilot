# 非股票功能改走 Supabase（2026-11-02）

## 邊界

- 股票維持既有路徑：Supabase 直接讀取、既有 Render／本機股票後端更新；本次不修改 `lib/stock/service_stock.dart`。
- 一般資料讀寫、額度、公開活動匯入／更新鎖／例行清理：App 使用既有受控 RPC，保留登入者 JWT、RLS 及資料庫端權限檢查。
- 天氣／假日／地址：先讀既有 Supabase 共用快取 RPC；未命中才呼叫本 Edge Function。需要外部服務的工作不在 SQL 裡處理。
- 管理員建立帳號與重設密碼：本 Function 驗證登入者後，以登入者 JWT 呼叫 `life_pilot_is_admin`，通過才使用伺服器管理金鑰。
- 公開活動 HTML 代理僅接受 HTTPS `www.taiwan.net.tw/m1.aspx`，不接受任意網址、重新導向或股票代理路徑。
- `apiSupabase` 已限制為 `stock/`；非股票功能不會退回 Render。舊 Python 非股票路由暫時保留相容性，但新 App 不再使用，股票需要的舊代理也不移除。

## 部署前順序（尚未自動部署）

1. 在 Supabase SQL Editor 執行本機 `tool/supabase_edge_services_20261102.sql`。這是安裝腳本，**不要執行** `tool/test_edge_services_20261102.sql`；後者只用於獨立測試資料庫。
2. 確認既有快取資料表：`weather_forecast_cache`、`geocode_cache`、`public_holidays`、`holiday_sync_runs`。腳本沿用它們的既有欄位，不遷移原資料。
3. 確認之前的 RPC 已部署：`life_pilot_cached_weather`、`life_pilot_cached_holidays`、`life_pilot_cached_geocode`、`life_pilot_cached_map_coordinates`、`life_pilot_backfill_cached_map_coordinates`、`life_pilot_public_event_refresh`、`life_pilot_import_public_events`、`life_pilot_run_daily_cleanup`。Edge 不會繞過未安裝的資料庫權限流程。
4. 到 Supabase Dashboard → Edge Functions → Secrets 設定下列值；**不要貼到 App、`--dart-define`、Git、SQL 資料表或聊天內容**。
5. 部署 `life-pilot-services`。若使用 Supabase CLI，在專案根目錄登入並連結正確專案後執行：

   ```sh
   supabase functions deploy life-pilot-services
   ```

   保留此專案 `supabase/config.toml` 的 JWT 驗證。Function 也會透過 Auth `get user` 驗證使用者，不只解碼 JWT。若 gateway 回傳 JWT 設定問題，先依官方 Auth headers 文件核對專案金鑰／驗證方式，不直接移除使用者驗證。
6. 重新啟動 App，再測試下方案例。**部署前的新 App 遇到需要外部服務／管理操作時會回報錯誤，不會偷偷退回 Render**。

SQL 檔依使用者既有要求被 `/tool/*.sql` 排除 Git，換電腦部署前需另行安全保留該本機安裝腳本。SQL 本身不含金鑰。

## Secrets

| 名稱 | 用途 |
| --- | --- |
| `OPEN_WEATHER_API_KEY` | OpenWeather 預報與地址查詢 |
| `GOOGLE_API_KEY` | Google Calendar 公開假日；限制為所需 API |
| `CORS_ALLOWED_ORIGINS` | 允許的正式 Web origins，以逗號分隔，不含網頁路徑；例如 `https://your-domain.example`。務必設成實際網站來源 |
| `SUPABASE_URL`、`SUPABASE_ANON_KEY` | Supabase Edge 環境提供的專案連線設定；公開 key 不是管理權限 |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase Edge 環境提供的伺服器管理金鑰；僅此伺服器程式使用 |
| `LIFE_PILOT_SERVICE_ROLE_KEY` | 可選：只有需要替代預設管理金鑰時才設定，同樣只放 Secrets |

本機 Web 測試允許 `http://localhost` 及 `http://127.0.0.1` 的連接埠。原生手機不要求 Origin；無論有無 Origin 都必須有有效的登入 JWT。CORS 不是權限驗證的替代品。

## 用量控制與失敗處理

- 共用快取沿用舊資料表，避免為每位使用者重抓相同天氣／假日／地址；地址查無結果也保留負快取。
- 資料庫短期租約阻止相同查詢同時呼叫供應商；失敗釋放租約，未能釋放則最久兩分鐘後可重試。
- 每種供應商工作有「每位使用者每五分鐘」及「全站每天 UTC」上限，只對快取未命中的供應商／管理操作計數；不是方案筆數額度。
- 可透過 Secrets 調整，無需修改 App。每個值必須是 1–1,000,000 的整數。

| kind（環境變數中使用大寫） | `EDGE_<KIND>_USER_LIMIT` 預設 | `EDGE_<KIND>_DAILY_LIMIT` 預設 |
| --- | ---: | ---: |
| `WEATHER` | 300 | 1000 |
| `GEOCODE` | 30 | 1000 |
| `HOLIDAYS` | 20 | 32 |
| `PUBLIC_PROXY` | 60 | 32 |
| `ACCOUNT_ADMIN` | 30 | 1000 |

- 供應商單次等待上限 12 秒，回應大小上限 4 MiB；App 等待 Edge 上限 45 秒。操作逾時不代表已撤銷遠端寫入，管理員應先查詢帳號是否已建立再重試。
- 預報到供應商當地午夜到期；假日每天同步；成功座標快取 180 天、查無座標 7 天；公開 HTML 15 分鐘。資料庫有索引，過期 Edge 快取／預算紀錄集中在各類每日首筆允許請求時清理。
- 私人行程／回憶座標補齊先檢查擁有權；公開投稿遵循公開／作者／管理員規則。座標寫回由 RPC 鎖定並重新檢查現址，避免編輯地址期間寫入舊座標。
- 全域登入錯誤處理仍保留；外部供應商的 401 不當成使用者被登出。帳號 A 的延遲失敗不會登出新登入的 B，A 的私人回應也不交給 B。
- 暫時密碼只回傳給已驗證的管理員，不寫 log、快取或資料表；回覆使用者仍由管理員的既有寄信流程完成，Function 不自動寄密碼信。

這是把非股票工作從 Render 移到 Supabase，不是免除總用量。Edge 呼叫、Auth 驗證、SQL 及外部 API 仍會計費／計量；上述共用快取、租約與可設定預算降低重複工作。其他 Render 服務及股票仍可能消耗 Render 時數。

## 驗證

自動化（使用假回應／獨立測試資料庫，沒有操作正式帳號）：

```sh
node --test supabase/functions/life-pilot-services/handler.test.mjs
flutter test test/cloud_api_routing_test.dart test/auth_session_guard_test.dart
```

部署後實測：

1. 一般使用者查看天氣、假日、地址：網路紀錄只有 Supabase RPC／Functions，不應出現 Render；第二次相同查詢使用快取。
2. 一般使用者偽呼叫管理帳號路由：403，不能列出使用者或修改密碼。
3. 管理員新建一般／廠商帳號、重設測試帳號密碼；已確認帳號不可被「建立帳號」覆寫。不要拿主要管理帳號測試。
4. 試著指定別人的私人行程 ID：不能讀地址或補寫座標。
5. 公開活動匯入／完成更新／失敗重試及地圖補齊沿用資料庫權限，只有明確錯誤，不顯示假成功。
6. 切換帳號時延遲回應不能顯示前一帳號內容。
7. 股票讀取與更新仍走原路徑；本次不調整股票外部資料來源或寫入策略。

官方參考：[Secrets](https://supabase.com/docs/guides/functions/secrets)、[Auth headers](https://supabase.com/docs/guides/functions/auth-headers)、[Function configuration](https://supabase.com/docs/guides/functions/function-configuration)。
