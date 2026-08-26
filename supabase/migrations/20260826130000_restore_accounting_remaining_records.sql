create or replace function public.fetch_today_accountings(
  p_account_id uuid,
  p_type text
)
returns table(detail public.accounting_detail, balance bigint)
language plpgsql
set search_path = ''
as $function$
begin
  return query
  with latest_currency as (
    select d.currency,
           max(d.date) as latest_record_date
    from public.accounting_detail d
    join public.accounting_account account_row on account_row.id = d.account_id
    where d.account_id = p_account_id
      and lower(d.type) = lower(p_type)
      and (
        d.date >= now() - interval '8 day'
        or d.description like '%餘%'
        or account_row.category = 'project'
      )
    group by d.currency
  )
  select detail_row, account_row.balance
  from public.accounting_account account_row
  left join public.accounting_detail detail_row
    on detail_row.account_id = account_row.id
   and lower(detail_row.type) = lower(p_type)
   and (
     detail_row.date >= now() - interval '31 day'
     or detail_row.description like '%餘%'
     or account_row.category = 'project'
   )
  left join latest_currency currency_row
    on detail_row.currency = currency_row.currency
  where account_row.id = p_account_id
  order by currency_row.latest_record_date desc,
           detail_row.date desc;
end;
$function$;

revoke all on function public.fetch_today_accountings(uuid, text)
  from public, anon;
grant execute on function public.fetch_today_accountings(uuid, text)
  to authenticated;
