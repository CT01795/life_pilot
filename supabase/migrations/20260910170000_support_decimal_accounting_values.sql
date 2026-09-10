-- Accounting amounts are money-like values and may contain one decimal point.
-- Point records intentionally remain integer values.

drop function if exists public.update_accounting_detail_with_date(
  uuid, bigint, text, text, timestamp with time zone, text, text
);
drop function if exists public.update_accounting_detail_with_date(
  uuid, numeric, text, text, timestamp with time zone, text, text
);

alter table public.accounting_detail
  alter column value type numeric using value::numeric;

alter table public.accounting_account
  alter column balance type numeric using balance::numeric;

alter table public.accounting_balance_by_currency
  alter column balance type numeric using balance::numeric;

create or replace function public.add_accountings_batch2(
  p_account_id uuid,
  p_type text,
  p_records jsonb
)
returns void
language plpgsql
set search_path = ''
as $function$
declare
  record_row jsonb;
  v_main_currency text;
  v_value numeric;
begin
  select main_currency into v_main_currency
  from public.accounting_account
  where id = p_account_id;

  for record_row in select * from jsonb_array_elements(p_records)
  loop
    v_value := (record_row->>'value')::numeric;

    insert into public.accounting_detail (
      id, account_id, type, value, description, currency,
      primary_category, "group"
    ) values (
      (record_row->>'id')::uuid,
      p_account_id,
      p_type,
      v_value,
      record_row->>'description',
      record_row->>'currency',
      coalesce(nullif(record_row->>'primary_category', ''), 'uncategorized'),
      coalesce(record_row->>'group', '')
    );

    insert into public.accounting_balance_by_currency (
      account_id, currency, balance, category
    ) values (
      p_account_id,
      record_row->>'currency',
      v_value,
      (select category from public.accounting_account where id = p_account_id)
    )
    on conflict (account_id, currency)
    do update set balance =
      public.accounting_balance_by_currency.balance + excluded.balance;

    update public.accounting_account
    set balance = coalesce(balance, 0) +
      case
        when p_type = 'balance'
         and (record_row->>'currency') = v_main_currency
        then v_value
        else 0
      end
    where id = p_account_id;
  end loop;
end;
$function$;

create function public.update_accounting_detail_with_date(
  p_detail_id uuid,
  p_new_value numeric,
  p_new_currency text,
  p_new_description text,
  p_new_date timestamp with time zone,
  p_new_primary_category text,
  p_new_group text
)
returns void
language plpgsql
set search_path = ''
as $function$
declare
  v_account_id uuid;
  v_old_value numeric;
  v_old_currency text;
  v_main_currency text;
  v_type text;
begin
  select account_id, value, currency, type
    into v_account_id, v_old_value, v_old_currency, v_type
  from public.accounting_detail
  where id = p_detail_id
  for update;

  if not found then
    raise exception 'Accounting detail not found';
  end if;
  if v_type <> 'balance' then
    raise exception 'Only balance records can be edited';
  end if;

  select main_currency
    into v_main_currency
  from public.accounting_account
  where id = v_account_id;

  update public.accounting_balance_by_currency
  set balance = balance - coalesce(v_old_value, 0)
  where account_id = v_account_id
    and currency = v_old_currency;

  insert into public.accounting_balance_by_currency (
    account_id, currency, balance, category
  )
  select v_account_id, p_new_currency, p_new_value, category
  from public.accounting_account
  where id = v_account_id
  on conflict (account_id, currency)
  do update set balance =
    public.accounting_balance_by_currency.balance + excluded.balance;

  update public.accounting_account
  set balance =
    coalesce(balance, 0)
    - case when v_old_currency = v_main_currency
        then coalesce(v_old_value, 0) else 0 end
    + case when p_new_currency = v_main_currency
        then p_new_value else 0 end
  where id = v_account_id;

  update public.accounting_detail
  set value = p_new_value,
      currency = p_new_currency,
      description = p_new_description,
      date = p_new_date,
      primary_category = p_new_primary_category,
      "group" = coalesce(p_new_group, '')
  where id = p_detail_id;
end;
$function$;

revoke all on function public.add_accountings_batch2(uuid, text, jsonb)
from public, anon;
grant execute on function public.add_accountings_batch2(uuid, text, jsonb)
to authenticated;

revoke all on function public.update_accounting_detail_with_date(
  uuid, numeric, text, text, timestamp with time zone, text, text
) from public, anon;
grant execute on function public.update_accounting_detail_with_date(
  uuid, numeric, text, text, timestamp with time zone, text, text
) to authenticated;
