begin;

-- Account-name search is performed by PostgREST before range pagination.
-- These partial indexes first narrow the scan to the signed-in owner's active
-- category and keep rows ordered by account name for the existing page query.
create index if not exists accounting_account_owner_category_name_search_idx
  on public.accounting_account (created_by, category, account)
  where is_valid is true;

create index if not exists point_record_account_owner_category_name_search_idx
  on public.point_record_account (created_by, category, account)
  where is_valid is true;

commit;
