# 減少 Render 呼叫：Supabase 直連

## 部署步驟

1. 在 Supabase SQL Editor，以管理者執行本機檔案
   `tool/supabase_direct_cloud_access_20261028.sql` 的完整內容。
2. 最後的唯讀驗證應回傳四個 RPC，`authenticated_can_execute = true`、
   `anon_can_execute = false`。此驗證不會執行清理。
3. 更新 App／Web；測試活動頁、行事曆假日與天氣。
4. 觀察瀏覽器 Network：命中快取、查詢更新狀態時應為 Supabase
   `/rest/v1/rpc/life_pilot_*`，不應喚醒 Render。

### 第二階段：地址、地圖與公開活動匯入

第一階段已完成後，再執行本機的
`tool/supabase_geocode_and_public_import_20261028.sql`。
最後應列出以下四個 RPC，authenticated 可執行、anon 不可執行：

- `life_pilot_cached_geocode(text)`：只回傳未過期座標或有效的「查無結果」。
- `life_pilot_cached_map_coordinates(text,text)`：檢查事件可見權限，再用快取補齊
  地圖座標；私人行事曆與回憶僅允許擁有者，公開推薦資料沿用原後端的可見規則。
- `life_pilot_backfill_cached_map_coordinates(text,integer,integer)`：只限管理員，
  只支援推薦活動／景點，每批最多 25 筆。快取缺失才交由原後端向供應商查詢；
  合併兩階段成功筆數，完成後的覆蓋率以最後一次查詢為準。
- `life_pilot_import_public_events(text,jsonb)`：一般登入使用者的公開來源匯入，
  每批 1–200 筆，來源網域沿用後端白名單。強制系統作者、未審核狀態，限制
  可匯入欄位，包含子活動；不接受作者、審核歷史、統計數字等特權欄位。

這些批次上限是請求安全限制，不是使用者訂閱額度。沒有更改任何方案額度。
匯入保留「無時間資料以名稱／日期／城市／地點去重、有時間再比較時間」及
刪除紀錄檢查；整批失敗不寫入完成標記。新 RPC 匯入使用交易鎖序列化，
仍保留既有唯一索引的衝突處理。管理員原本直接匯入的路徑沒有改動。

地址快取依現有 Python 的 NFKC／空白／小寫雜湊方式查詢。少數 Unicode
字元的 Python casefold 與 PostgreSQL lower 結果不同時，可能無法命中舊快取，
此時安全地沿用後端查址，不會把密鑰放入 App，也不會放寬快取表寫入權限。

SQL 只建立函式，不主動搬移、清除或匯入資料。函式安裝後，App 正常使用時
才會查快取、補寫座標或匯入活動。SQL 尚未安裝時保留舊後端相容路徑。

SQL 依專案既定規則不納入 Git；請在執行它的電腦保留該檔案。
部署程式不會自行執行 SQL。若 RPC 尚未部署，只有 `PGRST202` 會沿用原後端；
權限、登入、額度、資料表或其他資料庫錯誤不會繞過 Supabase 轉向後端。

## 變更範圍

- 活動更新狀態、開始／心跳／完成／取消鎖：直接由資料庫執行，與舊後端
  使用相同鎖名稱、標記、十五分鐘有效時間及台北日界。
- 每日清理：改呼叫 Supabase，一天只成功執行一次；仍沿用既有的一年活動
  保留、訂閱超額、答題紀錄及無效帳戶清理函式，不允許前端指定截止日。
  SQL 安裝本身不會執行清理；第一次相應的正常 App 呼叫才可能執行。
- 假日：讀 `public_holidays`／`holiday_sync_runs` 的公開結果。有當日快取時
  不呼叫 Render；有舊資料時立即顯示並背景更新，成功後更新 App 年度快取。
  缺少整個年度資料時仍需後端向供應商取得。
- 天氣：讀 `weather_forecast_cache` 未過期結果，過期／缺資料才呼叫後端。
  座標分桶使用與 Python 相同的四捨六入五成雙規則，沿用原快取鍵與有效期。
- 股票的雲端與 Mac 讀寫完全不變。

## 權限與仍需後端的功能

只新增受登入身分檢查的 RPC；不開放快取表的直接寫入，不提供密鑰查詢。
所有 SECURITY DEFINER 函式固定空 search_path，完整指定應用資料表 schema，
撤銷 PUBLIC／anon 執行權限。前端只使用原本的使用者 Supabase session。

外部 API 密鑰、管理 service_role 仍留在後端，不放到 App 可讀 table。
尚未取消 Render 的功能包括：外站抓取、快取缺失時的假日／天氣／地理編碼、
需要外部供應商的座標補齊，以及管理員建立帳號與重設密碼。
這些日後可以移到 Supabase Edge Functions 與其 Secrets，不能只靠公開 table
取代需要可信執行權限的工作。本輪沒有部署 Edge Functions 或變更 Render 服務。

## 驗證限制

Dart 測試以模擬 Supabase HTTP 回應確認快取命中、缺失與錯誤處理。
第二階段另在隔離 PostgreSQL 17 測試基本資料表、登入／權限、匯入與交易行為，
不是對正式 Supabase 的測試，也不含正式環境所有 RLS、觸發器及資料。
正式執行 SQL 後，需以一般使用者測試
讀取、以未登入身分確認拒絕，並驗證同時更新只取得一個活動更新 token。
