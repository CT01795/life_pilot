create or replace function public.delete_my_accounting_detail(
  p_detail_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  detail_row public.accounting_detail%rowtype;
  v_main_currency text;
begin
  select detail.*
    into detail_row
  from public.accounting_detail as detail
  join public.accounting_account as account_row
    on account_row.id = detail.account_id
  where detail.id = p_detail_id
    and lower(trim(account_row.created_by)) = public.life_pilot_user_email()
  for update of detail;

  if not found then
    raise exception 'Accounting detail not found';
  end if;

  select account_row.main_currency
    into v_main_currency
  from public.accounting_account as account_row
  where account_row.id = detail_row.account_id;

  update public.accounting_balance_by_currency as currency_balance
  set balance = currency_balance.balance - coalesce(detail_row.value, 0)
  where currency_balance.account_id = detail_row.account_id
    and currency_balance.currency = detail_row.currency;

  update public.accounting_account as accounting_account
  set balance = coalesce(accounting_account.balance, 0) - case
    when detail_row.type = 'balance'
      and detail_row.currency = v_main_currency
      then coalesce(detail_row.value, 0)
    else 0
  end
  where accounting_account.id = detail_row.account_id;

  delete from public.accounting_detail as detail
  where detail.id = p_detail_id;
end;
$$;

revoke all on function public.delete_my_accounting_detail(uuid)
from public, anon;

grant execute on function public.delete_my_accounting_detail(uuid)
to authenticated;
