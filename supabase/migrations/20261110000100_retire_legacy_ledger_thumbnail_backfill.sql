-- The app now uses upgrade_my_ledger_thumbnail(), which also compares the
-- previous thumbnail hash before replacing it. Keep fresh databases aligned
-- with production by removing the superseded missing-thumbnail-only RPC.
drop function if exists
  public.backfill_my_ledger_thumbnail(text, uuid, text, text)
  restrict;
