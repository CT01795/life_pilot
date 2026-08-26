-- Treat detail.date as the user-editable transaction date while preserving
-- created_at as the immutable record creation timestamp.

alter table public.accounting_detail
  add column if not exists primary_category text;
alter table public.point_record_detail
  add column if not exists primary_category text;

update public.accounting_detail
set date = created_at
where date is null;
update public.point_record_detail
set date = created_at
where date is null;

update public.accounting_detail
set primary_category = 'uncategorized'
where primary_category is null or trim(primary_category) = '';
update public.point_record_detail
set primary_category = 'uncategorized'
where primary_category is null or trim(primary_category) = '';

alter table public.accounting_detail
  alter column date set default now(),
  alter column date set not null,
  alter column primary_category set default 'uncategorized',
  alter column primary_category set not null;
alter table public.point_record_detail
  alter column date set default now(),
  alter column date set not null,
  alter column primary_category set default 'uncategorized',
  alter column primary_category set not null;

alter table public.accounting_detail
  drop constraint if exists accounting_detail_primary_category_check;
alter table public.accounting_detail
  add constraint accounting_detail_primary_category_check check (
    primary_category in (
      'uncategorized', 'food', 'clothing', 'housing',
      'transportation', 'education', 'entertainment'
    )
  );

alter table public.point_record_detail
  drop constraint if exists point_record_detail_primary_category_check;
alter table public.point_record_detail
  add constraint point_record_detail_primary_category_check check (
    primary_category in (
      'uncategorized', 'virtue', 'intelligence', 'fitness', 'social', 'arts'
    )
  );

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
begin
  select main_currency into v_main_currency
  from public.accounting_account
  where id = p_account_id;

  for record_row in select * from jsonb_array_elements(p_records)
  loop
    insert into public.accounting_detail (
      id, account_id, type, value, description, currency,
      primary_category, "group"
    ) values (
      (record_row->>'id')::uuid,
      p_account_id,
      p_type,
      (record_row->>'value')::int,
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
      (record_row->>'value')::int,
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
        then (record_row->>'value')::int
        else 0
      end
    where id = p_account_id;
  end loop;
end;
$function$;

create or replace function public.add_point_records_batch(
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
begin
  for record_row in select * from jsonb_array_elements(p_records)
  loop
    insert into public.point_record_detail (
      account_id, type, value, description, primary_category, "group"
    ) values (
      p_account_id,
      p_type,
      (record_row->>'value')::int,
      record_row->>'description',
      coalesce(nullif(record_row->>'primary_category', ''), 'uncategorized'),
      coalesce(record_row->>'group', '')
    );

    update public.point_record_account
    set points = coalesce(points, 0) +
      case when p_type = 'points'
        then (record_row->>'value')::int else 0 end
    where id = p_account_id;
  end loop;
end;
$function$;

create or replace function public.update_accounting_detail_with_date(
  p_detail_id uuid,
  p_new_value bigint,
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
  v_old_value bigint;
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
  select
    v_account_id,
    p_new_currency,
    p_new_value,
    category
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

create or replace function public.update_point_record_detail(
  p_detail_id uuid,
  p_new_value bigint,
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
  v_old_value bigint;
  v_type text;
begin
  select account_id, value, type
    into v_account_id, v_old_value, v_type
  from public.point_record_detail
  where id = p_detail_id
  for update;

  if not found then
    raise exception 'Point record detail not found';
  end if;
  if v_type <> 'points' then
    raise exception 'Only point records can be edited';
  end if;

  update public.point_record_account
  set points = coalesce(points, 0) - coalesce(v_old_value, 0) + p_new_value
  where id = v_account_id;

  update public.point_record_detail
  set value = p_new_value,
      description = p_new_description,
      date = p_new_date,
      primary_category = p_new_primary_category,
      "group" = coalesce(p_new_group, '')
  where id = p_detail_id;
end;
$function$;

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

create or replace function public.fetch_today_point_records(
  p_account_id uuid,
  p_type text
)
returns table(detail public.point_record_detail, points bigint)
language plpgsql
set search_path = ''
as $function$
begin
  return query
  select detail_row, account_row.points
  from public.point_record_account account_row
  left join public.point_record_detail detail_row
    on detail_row.account_id = account_row.id
   and lower(detail_row.type) = lower(p_type)
   and detail_row.date >= now() - interval '31 day'
  where account_row.id = p_account_id
  order by detail_row.date desc;
end;
$function$;

revoke all on function public.update_accounting_detail_with_date(
  uuid, bigint, text, text, timestamp with time zone, text, text
) from public, anon;
revoke all on function public.update_point_record_detail(
  uuid, bigint, text, timestamp with time zone, text, text
) from public, anon;

grant execute on function public.update_accounting_detail_with_date(
  uuid, bigint, text, text, timestamp with time zone, text, text
) to authenticated;
grant execute on function public.update_point_record_detail(
  uuid, bigint, text, timestamp with time zone, text, text
) to authenticated;
