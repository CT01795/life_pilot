begin;

create or replace function public.get_my_dashboard_ledger_account_options(
  p_kind text,
  p_search text default '',
  p_cursor jsonb default null,
  p_selected_id text default null,
  p_limit integer default 20
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null or nullif(public.life_pilot_user_email(), '') is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_kind not in ('accounting', 'points') then
    raise exception 'invalid_ledger_kind' using errcode = '22023';
  end if;

  with input as (
    select
      lower(trim(coalesce(p_search, ''))) search,
      least(greatest(coalesce(p_limit, 20), 1), 50) page_limit,
      coalesce((p_cursor ->> 'group')::integer, -1) cursor_group,
      coalesce(p_cursor ->> 'name', '') cursor_name,
      coalesce(p_cursor ->> 'id', '') cursor_id
  ), candidates as materialized (
    select
      0 sort_group,
      lower(coalesce(a.account, '')) sort_name,
      a.id::text sort_id,
      jsonb_build_object(
        'id', a.id,
        'account', a.account,
        'category', a.category,
        'shared_kind', null
      ) payload
    from public.accounting_account a
    where p_kind = 'accounting'
      and lower(trim(a.created_by)) = public.life_pilot_user_email()
      and a.is_valid is true
    union all
    select
      0,
      lower(coalesce(a.account, '')),
      a.id::text,
      jsonb_build_object(
        'id', a.id,
        'account', a.account,
        'category', a.category,
        'shared_kind', null
      )
    from public.point_record_account a
    where p_kind = 'points'
      and lower(trim(a.created_by)) = public.life_pilot_user_email()
      and a.is_valid is true
    union all
    select
      1,
      lower(coalesce(a.account, p.account, '')),
      s.id::text,
      jsonb_build_object(
        'id', s.id,
        'account', coalesce(a.account, p.account),
        'category', '',
        'shared_kind', s.kind
      )
    from public.ledger_read_shares s
    join auth.users recipient on recipient.id = s.recipient_id
    join auth.users owner_user on owner_user.id = s.owner_id
    left join public.accounting_account a
      on s.kind = 'accounting'
     and a.id::text = s.account_id
     and lower(trim(a.created_by)) = lower(trim(owner_user.email))
     and a.is_valid is true
    left join public.point_record_account p
      on s.kind = 'points'
     and p.id::text = s.account_id
     and lower(trim(p.created_by)) = lower(trim(owner_user.email))
     and p.is_valid is true
    where s.kind = p_kind
      and recipient.id = auth.uid()
      and (recipient.banned_until is null or recipient.banned_until <= now())
      and public.life_pilot_ledger_share_owner_eligible(s.owner_id)
      and (a.id is not null or p.id is not null)
  ), filtered as materialized (
    select c.*
    from candidates c cross join input i
    where i.search = '' or c.sort_name like '%' || i.search || '%'
  ), page_candidates as materialized (
    select f.*
    from filtered f cross join input i
    where p_cursor is null
       or (f.sort_group, f.sort_name, f.sort_id)
          > (i.cursor_group, i.cursor_name, i.cursor_id)
    order by f.sort_group, f.sort_name, f.sort_id
    limit (select page_limit + 1 from input)
  ), page_rows as materialized (
    select p.*
    from page_candidates p
    order by p.sort_group, p.sort_name, p.sort_id
    limit (select page_limit from input)
  ), selected_row as (
    select f.*
    from filtered f cross join input i
    where p_cursor is null
      and i.search = ''
      and f.sort_id = nullif(p_selected_id, '')
      and not exists (
        select 1 from page_rows p
        where p.sort_group = f.sort_group and p.sort_id = f.sort_id
      )
    order by f.sort_group
    limit 1
  ), output_rows as (
    select -1 output_group, s.sort_group, s.sort_name, s.sort_id, s.payload
    from selected_row s
    union all
    select 0, p.sort_group, p.sort_name, p.sort_id, p.payload
    from page_rows p
  ), last_page_row as (
    select p.* from page_rows p
    order by p.sort_group desc, p.sort_name desc, p.sort_id desc
    limit 1
  )
  select jsonb_build_object(
      'rows', coalesce((
        select jsonb_agg(o.payload order by o.output_group, o.sort_group,
          o.sort_name, o.sort_id) from output_rows o
      ), '[]'::jsonb),
      'next_cursor', case when
        (select count(*) from page_candidates) > (select page_limit from input)
      then (
        select jsonb_build_object(
          'group', l.sort_group, 'name', l.sort_name, 'id', l.sort_id
        ) from last_page_row l
      ) else null end
    ) into v_result;
  return v_result;
end;
$$;

revoke all on function public.get_my_dashboard_ledger_account_options(
  text,text,jsonb,text,integer
) from public, anon;
grant execute on function public.get_my_dashboard_ledger_account_options(
  text,text,jsonb,text,integer
) to authenticated, service_role;

-- The dashboard now uses the combined owned/shared cursor query.
drop function if exists public.get_my_ledger_account_options(text, integer);

notify pgrst, 'reload schema';
commit;
