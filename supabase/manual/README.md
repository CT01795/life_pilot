# 手動資料庫退役清理

這些腳本刻意不放在 migrations，避免未完成 App／Edge 更新與依賴確認就自動刪除。

## 2026-11-06 第一批

- `20261106_retire_legacy_rpc_paths.sql`：四個舊 RPC。
- `20261106_retired_rpc_snapshot.json`：刪除前的定義、擁有者及 ACL。
- 此批必須先部署已移除退役路由的 Edge。

## 2026-11-06 第二批

- `20261106_retire_legacy_rpc_batch2.sql`：十五個已確認無呼叫者的舊入口。
- `20261106_retired_rpc_batch2_snapshot.json`：正式資料庫刪除前的定義、擁有者及 ACL。
- 已檢查 App、Edge、Python、資料庫登記依賴、跨 schema 函式／程序文字引用，
  以及 EXECUTE、format、字串組裝的實際用途。
- 第二批沒有修改 Edge，無須因本批重新部署 Edge。
- 正式環境已執行第二批，十五列 `removed` 均為 `true`。
- `20261106_retired_rpc_batch2_verification.json` 保存前後比對結果：其餘 209 個
  public 函式的定義／擁有者／ACL，以及觸發器、政策與角色設定摘要完全一致。
  此為資料庫物件驗證，不代表已完成登入後的實機操作測試。

## 2026-11-10 訂閱 helper

- `20261110_retire_subscription_helpers.sql`：退役兩個已確認無內外部呼叫者的
  訂閱 helper。
- `20261110_retired_subscription_helpers_snapshot.json`：正式資料庫刪除前的
  完整定義、擁有者、ACL 與依賴盤點。
- `20261110_retired_subscription_helpers_verification.json`：保存正式環境的
  移除結果與前後安全指紋。
- 正式環境已移除
  `life_pilot_has_active_cloud_plus()` 與
  `life_pilot_subscription_plan_for_user(uuid)`。
- 其餘 207 個 public 函式、125 個 RLS policy、83 個 trigger 與 15 筆角色設定
  的數量及內容指紋前後一致。

## 2026-11-10 舊縮圖 helper

- `20261110_retire_legacy_ledger_thumbnail_backfill.sql`：正式環境手動退役
  `backfill_my_ledger_thumbnail(text,uuid,text,text)`。
- `20261110_retired_ledger_thumbnail_backfill_snapshot.json`：保存刪除前的
  定義、擁有者、ACL 與替代函式。
- 對應 migration 為
  `../migrations/20261110000100_retire_legacy_ledger_thumbnail_backfill.sql`，
  避免新專案、分支或資料庫重建後再次留下舊 RPC。
- 現行 App 使用
  `upgrade_my_ledger_thumbnail(text,uuid,text,text,text)`，舊 helper 不再使用。
- 正式環境已完成退役，且兩份縮圖 migration 都已登記為 applied。
- `20261110_retired_ledger_thumbnail_backfill_verification.json` 保存退役後驗證。
  既有 JPEG migration 重新建立新版 helper 時將來源換行由 CRLF 正規化為 LF，
  因此原始函式雜湊不同；函式內容、擁有者與 ACL 等價，RLS、trigger 與角色設定
  前後一致。

## 安全原則

1. 每次執行前重新核對正式環境；曾經無依賴不代表日後永遠無依賴。
2. 先保留定義與權限備份，確認舊客戶端與外部呼叫者已退役。
3. 腳本採交易、5 秒 lock timeout、文字引用檢查與精確簽章 DROP ... RESTRICT。
4. 遇到引用或依賴則停止，不能改用 CASCADE 強制通過。
5. 檢查所有 removed 結果及現行替代 RPC、觸發器、RLS／Data API 防護。
6. 快照不是自動還原指令；還原時必須同時核對函式定義、擁有者與原 ACL。
7. 舊 tool 安裝腳本可能重新建立退役函式，重裝後須重新盤點。
