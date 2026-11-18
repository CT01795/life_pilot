begin;

create or replace function public.create_or_restore_my_ledger_account(
  p_kind text,
  p_account_id uuid,
  p_name text,
  p_category text,
  p_currency text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := public.life_pilot_user_email();
  v_accounting public.accounting_account%rowtype;
  v_points public.point_record_account%rowtype;
begin
  if auth.uid() is null or nullif(v_email, '') is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_kind not in ('accounting', 'points') then
    raise exception 'invalid_ledger_kind' using errcode = '22023';
  end if;
  if p_account_id is null or nullif(trim(p_name), '') is null
     or nullif(trim(p_category), '') is null then
    raise exception 'invalid_ledger_account' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    concat_ws('|', v_email, p_kind, p_category, p_name),
    0
  ));

  if p_kind = 'accounting' then
    select a.* into v_accounting
    from public.accounting_account a
    where lower(trim(a.created_by)) = v_email
      and a.account = p_name
      and a.category = p_category
    limit 1
    for update;

    if found then
      if v_accounting.is_valid is true then
        raise exception 'account_already_exists' using errcode = '23505';
      end if;
      update public.accounting_account a
      set is_valid = true
      where a.id = v_accounting.id
      returning a.* into v_accounting;
    else
      insert into public.accounting_account (
        id, account, created_by, category, main_currency, balance,
        exchange_rate, is_valid
      ) values (
        p_account_id, p_name, v_email, p_category, p_currency, 0, null, true
      )
      returning * into v_accounting;
    end if;

    return jsonb_build_object(
      'id', v_accounting.id,
      'account', v_accounting.account,
      'category', v_accounting.category,
      'master_graph_url', v_accounting.master_graph_url,
      'balance', v_accounting.balance,
      'main_currency', v_accounting.main_currency,
      'exchange_rate', v_accounting.exchange_rate
    );
  end if;

  select a.* into v_points
  from public.point_record_account a
  where lower(trim(a.created_by)) = v_email
    and a.account = p_name
    and a.category = p_category
  limit 1
  for update;

  if found then
    if v_points.is_valid is true then
      raise exception 'account_already_exists' using errcode = '23505';
    end if;
    update public.point_record_account a
    set is_valid = true
    where a.id = v_points.id
    returning a.* into v_points;
  else
    insert into public.point_record_account (
      id, account, created_by, category, points, is_valid
    ) values (
      p_account_id, p_name, v_email, p_category, 0, true
    )
    returning * into v_points;
  end if;

  return jsonb_build_object(
    'id', v_points.id,
    'account', v_points.account,
    'category', v_points.category,
    'master_graph_url', v_points.master_graph_url,
    'points', v_points.points
  );
end;
$$;

revoke all on function public.create_or_restore_my_ledger_account(
  text, uuid, text, text, text
) from public, anon;
grant execute on function public.create_or_restore_my_ledger_account(
  text, uuid, text, text, text
) to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
