begin;

create or replace function public.get_or_create_my_dashboard_core_v2(
  p_expected_email text,
  p_month_start timestamptz,
  p_month_end timestamptz,
  p_day_start timestamptz,
  p_day_end timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_core jsonb;
  v_shared jsonb;
begin
  if p_month_start is null or p_month_end is null
     or p_day_start is null or p_day_end is null
     or p_month_end <= p_month_start
     or p_day_end <= p_day_start
     or p_day_start < p_month_start
     or p_day_end > p_month_end then
    raise exception 'Invalid dashboard date boundary' using errcode = '22023';
  end if;

  v_core := public.get_or_create_my_dashboard_core(
    p_expected_email,
    p_day_start,
    p_day_end
  );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'share_id', link.share_id,
        'kind', link.kind,
        'account_name', link.account_name,
        'snapshot', public.get_my_shared_ledger_home_preview(
          link.share_id,
          p_month_start,
          p_month_end,
          p_day_start,
          p_day_end
        )
      ) order by link.kind
    ),
    '[]'::jsonb
  )
  into v_shared
  from public.list_my_ledger_home_links() link;

  return v_core || jsonb_build_object('shared_ledgers', v_shared);
end;
$$;

revoke all on function public.get_or_create_my_dashboard_core_v2(
  text, timestamptz, timestamptz, timestamptz, timestamptz
) from public, anon;
grant execute on function public.get_or_create_my_dashboard_core_v2(
  text, timestamptz, timestamptz, timestamptz, timestamptz
) to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
