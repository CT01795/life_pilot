-- Resolve shared-image permission through the existing security-definer
-- capability function. The overview RPC runs as the recipient, so selecting
-- ledger_read_shares directly requires a broad table grant and is still
-- filtered by RLS, which can incorrectly report an allowed permission as false.
begin;

create or replace function public.list_my_shared_ledger_overview_window(
  p_kind text, p_limit integer, p_offset integer, p_visible_limit integer,
  p_month_start timestamptz, p_month_end timestamptz,
  p_day_start timestamptz, p_day_end timestamptz
) returns table(share_id uuid, kind text, account_id text, account_name text, totals jsonb)
language plpgsql stable security invoker set search_path = '' as $$
declare
  entry record;
  position_in_page integer := 0;
  visible_limit integer := greatest(0, least(coalesce(p_visible_limit, 0), 100));
  image_allowed boolean;
begin
  for entry in
    select * from public.list_my_shared_ledgers_by_kind(
      p_kind, least(coalesce(p_limit, 30), visible_limit + 1), p_offset)
  loop
    position_in_page := position_in_page + 1;
    if position_in_page > visible_limit then
      share_id := null; kind := null; account_id := null;
      account_name := null; totals := null;
      return next;
      return;
    end if;
    share_id := entry.share_id;
    kind := entry.kind;
    account_id := entry.account_id;
    account_name := entry.account_name;
    image_allowed := public.can_change_shared_ledger_image(share_id);
    begin
      totals := public.get_my_shared_ledger_totals(
        share_id, p_month_start, p_month_end, p_day_start, p_day_end)
        || jsonb_build_object(
          'allow_image_changes', coalesce(image_allowed, false)
        );
    exception when insufficient_privilege then
      totals := jsonb_build_object(
        'allow_image_changes', coalesce(image_allowed, false)
      );
    end;
    return next;
  end loop;
end;
$$;

-- Access to this table is intentionally mediated by security-definer RPCs.
-- Undo the temporary broad grant that was needed by the broken overview query.
revoke select on table public.ledger_read_shares from authenticated;

revoke all on function public.list_my_shared_ledger_overview_window(
  text,integer,integer,integer,timestamptz,timestamptz,timestamptz,timestamptz
) from public, anon;
grant execute on function public.list_my_shared_ledger_overview_window(
  text,integer,integer,integer,timestamptz,timestamptz,timestamptz,timestamptz
) to authenticated;

notify pgrst, 'reload schema';
commit;
