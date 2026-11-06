-- Allow compact JPEG thumbnails without increasing the 64 KiB base64 limit.
-- Existing owner checks, RLS, and compare-and-swap guards remain unchanged.
begin;

create or replace function public.backfill_my_ledger_thumbnail(
  p_resource text, p_account_id uuid, p_original_hash text, p_thumbnail text
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare v_owner text := public.life_pilot_user_email(); v_updated bigint;
begin
  if auth.uid() is null or nullif(v_owner, '') is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_resource is null or p_resource not in ('accounting_account', 'point_record_account')
    or p_original_hash is null or p_original_hash !~ '^[0-9a-f]{64}$'
    or p_thumbnail is null or length(p_thumbnail) not between 1 and 65536
    or (p_thumbnail not like 'iVBORw0KGgo%' and p_thumbnail not like '/9j/%') then
    raise exception 'invalid_ledger_thumbnail' using errcode = '22023';
  end if;
  execute format('update public.%I set thumbnail_base64 = $1
    where id = $2 and lower(trim(created_by)) = $3 and is_valid
      and thumbnail_base64 is null
      and encode(sha256(convert_to(master_graph_url, ''UTF8'')), ''hex'') = $4', p_resource)
    using p_thumbnail, p_account_id, v_owner, p_original_hash;
  get diagnostics v_updated = row_count;
  return jsonb_build_object('updated', v_updated > 0);
end;
$$;
revoke all on function public.backfill_my_ledger_thumbnail(text,uuid,text,text) from public, anon;
grant execute on function public.backfill_my_ledger_thumbnail(text,uuid,text,text) to authenticated;

create or replace function public.upgrade_my_ledger_thumbnail(
  p_resource text, p_account_id uuid, p_original_hash text, p_thumbnail text, p_previous_hash text
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare v_owner text := public.life_pilot_user_email(); v_updated bigint;
begin
  if auth.uid() is null or nullif(v_owner, '') is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_resource is null or p_resource not in ('accounting_account', 'point_record_account')
    or p_original_hash is null or p_original_hash !~ '^[0-9a-f]{64}$'
    or (p_previous_hash is not null and p_previous_hash !~ '^[0-9a-f]{64}$')
    or p_thumbnail is null or length(p_thumbnail) not between 1 and 65536
    or (p_thumbnail not like 'iVBORw0KGgo%' and p_thumbnail not like '/9j/%') then
    raise exception 'invalid_ledger_thumbnail' using errcode = '22023';
  end if;
  execute format('update public.%I set thumbnail_base64 = $1
    where id = $2 and lower(trim(created_by)) = $3 and is_valid
      and encode(sha256(convert_to(thumbnail_base64, ''UTF8'')), ''hex'') is not distinct from $5
      and encode(sha256(convert_to(master_graph_url, ''UTF8'')), ''hex'') = $4', p_resource)
    using p_thumbnail, p_account_id, v_owner, p_original_hash, p_previous_hash;
  get diagnostics v_updated = row_count;
  return jsonb_build_object('updated', v_updated > 0);
end;
$$;
revoke all on function public.upgrade_my_ledger_thumbnail(text,uuid,text,text,text) from public, anon;
grant execute on function public.upgrade_my_ledger_thumbnail(text,uuid,text,text,text) to authenticated;

notify pgrst, 'reload schema';
commit;

-- Read-only deployment verification (both rows should be true):
select p.proname as function_name,
  position('/9j/' in pg_get_functiondef(p.oid)) > 0 as accepts_jpeg
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('backfill_my_ledger_thumbnail', 'upgrade_my_ledger_thumbnail');
