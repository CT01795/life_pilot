begin;

create or replace function public.fetch_today_accountings(
  p_account_id uuid,
  p_type text
)
returns table(detail public.accounting_detail, balance bigint)
language plpgsql
stable
set search_path = ''
as $function$
begin
  return query
  select detail_row, account_row.balance
  from public.accounting_account account_row
  left join public.accounting_detail detail_row
    on detail_row.account_id = account_row.id
   and lower(detail_row.type) = lower(p_type)
   and (
     account_row.category = 'project'
     or detail_row.primary_category = 'reserved'
     or detail_row.date >= current_date - interval '29 days'
   )
  where account_row.id = p_account_id
  order by detail_row.date desc nulls last;
end;
$function$;

create or replace function public.fetch_today_point_records(
  p_account_id uuid,
  p_type text
)
returns table(detail public.point_record_detail, points bigint)
language plpgsql
stable
set search_path = ''
as $function$
begin
  return query
  select detail_row, account_row.points
  from public.point_record_account account_row
  left join public.point_record_detail detail_row
    on detail_row.account_id = account_row.id
   and lower(detail_row.type) = lower(p_type)
   and (
     detail_row.primary_category = 'reserved'
     or detail_row.date >= current_date - interval '29 days'
   )
  where account_row.id = p_account_id
  order by detail_row.date desc nulls last;
end;
$function$;

revoke all on function public.fetch_today_accountings(uuid, text)
  from public, anon;
revoke all on function public.fetch_today_point_records(uuid, text)
  from public, anon;
grant execute on function public.fetch_today_accountings(uuid, text)
  to authenticated;
grant execute on function public.fetch_today_point_records(uuid, text)
  to authenticated;

commit;
