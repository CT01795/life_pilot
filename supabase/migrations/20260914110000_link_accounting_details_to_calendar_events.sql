alter table public.accounting_detail
  add column if not exists event_id text;

create index if not exists accounting_detail_event_date_idx
  on public.accounting_detail (event_id, date desc)
  where event_id is not null;

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
      primary_category, "group", event_id
    ) values (
      (record_row->>'id')::uuid,
      p_account_id,
      p_type,
      v_value,
      record_row->>'description',
      record_row->>'currency',
      coalesce(nullif(record_row->>'primary_category', ''), 'uncategorized'),
      coalesce(record_row->>'group', ''),
      nullif(record_row->>'event_id', '')
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

revoke all on function public.add_accountings_batch2(uuid, text, jsonb)
from public, anon;
grant execute on function public.add_accountings_batch2(uuid, text, jsonb)
to authenticated;
