begin;

create or replace function public.get_my_ledger_account_by_event(
  p_kind text,
  p_event_id text,
  p_expected_email text
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
  if v_email <> lower(trim(coalesce(p_expected_email, ''))) then
    raise exception 'account_changed' using errcode = '42501';
  end if;
  if p_kind not in ('accounting', 'points')
     or nullif(trim(p_event_id), '') is null
     or length(p_event_id) > 200 then
    raise exception 'invalid_ledger_event_lookup' using errcode = '22023';
  end if;

  if p_kind = 'accounting' then
    select jsonb_build_object(
      'id', account_row.id,
      'account', account_row.account,
      'category', account_row.category,
      'balance', account_row.balance,
      'main_currency', account_row.main_currency,
      'exchange_rate', account_row.exchange_rate
    )
    into v_result
    from public.accounting_account account_row
    where lower(trim(account_row.created_by)) = v_email
      and account_row.is_valid is true
      and (
        account_row.id::text = p_event_id
        or account_row.id in (
          select detail.account_id
          from public.accounting_detail detail
          where detail.event_id::text = p_event_id
          order by detail.date desc nulls last, detail.id desc
          limit 1
        )
      )
    order by (account_row.id::text = p_event_id) desc
    limit 1;
  else
    select jsonb_build_object(
      'id', account_row.id,
      'account', account_row.account,
      'category', account_row.category,
      'points', account_row.points
    )
    into v_result
    from public.point_record_account account_row
    where lower(trim(account_row.created_by)) = v_email
      and account_row.is_valid is true
      and (
        account_row.id::text = p_event_id
        or account_row.id in (
          select detail.account_id
          from public.point_record_detail detail
          where detail.event_id::text = p_event_id
          order by detail.date desc nulls last, detail.id desc
          limit 1
        )
      )
    order by (account_row.id::text = p_event_id) desc
    limit 1;
  end if;

  return v_result;
end;
$$;

revoke all on function public.get_my_ledger_account_by_event(text, text, text)
  from public, anon;
grant execute on function public.get_my_ledger_account_by_event(text, text, text)
  to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
