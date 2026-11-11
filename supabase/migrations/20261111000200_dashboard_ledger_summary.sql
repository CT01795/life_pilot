begin;

create or replace function public.get_my_dashboard_ledger_summary(
  p_kind text,
  p_account_id uuid,
  p_day_start timestamptz,
  p_day_end timestamptz
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_email text := public.life_pilot_user_email();
  v_result jsonb;
begin
  if auth.uid() is null or nullif(v_email, '') is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_kind not in ('accounting', 'points')
     or p_account_id is null
     or p_day_start is null
     or p_day_end is null
     or p_day_end <= p_day_start then
    raise exception 'invalid_dashboard_ledger_request' using errcode = '22023';
  end if;

  if p_kind = 'accounting' then
    select jsonb_build_object(
      'total', a.balance,
      'currency', coalesce(nullif(trim(a.main_currency), ''), 'TWD'),
      'today_total', coalesce((
        select sum(d.value)
        from public.accounting_detail d
        where d.account_id = a.id
          and d.currency = a.main_currency
          and d.date >= p_day_start
          and d.date < p_day_end
      ), 0),
      'records', coalesce((
        select jsonb_agg(to_jsonb(preview) order by preview.date desc, preview.id desc)
        from (
          select d.id, d.description, d.value, d.currency,
                 d.created_at, d.date, d."group"
          from public.accounting_detail d
          where d.account_id = a.id
            and d.currency = a.main_currency
            and d.date >= p_day_start
            and d.date < p_day_end
          order by d.date desc, d.id desc
          limit 5
        ) preview
      ), '[]'::jsonb)
    ) into v_result
    from public.accounting_account a
    where a.id = p_account_id
      and a.is_valid is true
      and lower(trim(a.created_by)) = v_email;
  else
    select jsonb_build_object(
      'total', a.points,
      'today_total', coalesce((
        select sum(d.value)
        from public.point_record_detail d
        where d.account_id = a.id
          and d.date >= p_day_start
          and d.date < p_day_end
      ), 0),
      'records', coalesce((
        select jsonb_agg(to_jsonb(preview) order by preview.date desc, preview.id desc)
        from (
          select d.id, d.description, d.type, d.value,
                 d.created_at, d.date, d."group"
          from public.point_record_detail d
          where d.account_id = a.id
            and d.date >= p_day_start
            and d.date < p_day_end
          order by d.date desc, d.id desc
          limit 5
        ) preview
      ), '[]'::jsonb)
    ) into v_result
    from public.point_record_account a
    where a.id = p_account_id
      and a.is_valid is true
      and lower(trim(a.created_by)) = v_email;
  end if;

  return v_result;
end;
$$;

revoke all on function public.get_my_dashboard_ledger_summary(
  text, uuid, timestamptz, timestamptz
) from public, anon;
grant execute on function public.get_my_dashboard_ledger_summary(
  text, uuid, timestamptz, timestamptz
) to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
