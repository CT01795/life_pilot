begin;

create or replace function public.get_my_memory_window(
  p_from date,
  p_to date,
  p_limit integer default 12,
  p_expand_fallback boolean default false
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_email text := public.life_pilot_user_email();
  v_start date := p_from;
  v_end date := p_to;
  v_latest date;
  v_next date;
  v_rows jsonb;
  v_count integer;
  v_limit integer := least(greatest(coalesce(p_limit, 12), 1), 50);
begin
  if auth.uid() is null or nullif(v_email, '') is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_from is null or p_to is null or p_from > p_to then
    raise exception 'invalid_memory_window' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.memory_trace m
    where lower(trim(m.account)) = v_email
      and m.start_date::date between v_start and v_end
  ) then
    select max(m.start_date::date) into v_latest
    from public.memory_trace m
    where lower(trim(m.account)) = v_email
      and m.start_date::date < v_start;
    if v_latest is not null then
      v_end := v_latest;
      v_start := case when p_expand_fallback
        then v_latest - 29
        else v_latest
      end;
    end if;
  end if;

  with selected as (
    select m.*
    from public.memory_trace m
    where lower(trim(m.account)) = v_email
      and m.start_date::date between v_start and v_end
    order by m.start_date desc nulls last, m.start_time desc nulls last, m.id
    limit v_limit + 1
  )
  select count(*), coalesce(
    jsonb_agg(to_jsonb(s) order by s.start_date desc nulls last,
      s.start_time desc nulls last, s.id) filter (where ordinal <= v_limit),
    '[]'::jsonb
  )
  into v_count, v_rows
  from (
    select selected.*,
      row_number() over (
        order by selected.start_date desc nulls last,
          selected.start_time desc nulls last,
          selected.id
      ) ordinal
    from selected
  ) s;

  select max(m.start_date::date) into v_next
  from public.memory_trace m
  where lower(trim(m.account)) = v_email
    and m.start_date::date < v_start;

  return jsonb_build_object(
    'events', v_rows,
    'has_page_more', v_count > v_limit,
    'has_more', v_count > v_limit or v_next is not null,
    'window_start', v_start,
    'window_end', v_end,
    'next_date', v_next
  );
end;
$$;

revoke all on function public.get_my_memory_window(date,date,integer,boolean)
  from public, anon;
grant execute on function public.get_my_memory_window(date,date,integer,boolean)
  to authenticated, service_role;

create or replace function public.get_admin_question_hint(
  p_table_name text,
  p_group text,
  p_random_key double precision
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_table_name not in ('game_grammar', 'game_sentence', 'game_translation')
     or nullif(trim(p_group), '') is null
     or p_random_key < 0 or p_random_key >= 1 then
    raise exception 'invalid_question_hint_request' using errcode = '22023';
  end if;

  execute format($query$
    with candidates as (
      (select q.question, q.answer, 0 as priority
       from public.%I q
       where q.owner_id = 'cd55646b-7924-4413-9cd0-b75de0b9f605'::uuid
         and q."group" = $1 and q.is_active is true and q.rand_key >= $2
       order by q.rand_key
       limit 1)
      union all
      (select q.question, q.answer, 1 as priority
       from public.%I q
       where q.owner_id = 'cd55646b-7924-4413-9cd0-b75de0b9f605'::uuid
         and q."group" = $1 and q.is_active is true and q.rand_key < $2
       order by q.rand_key
       limit 1)
    )
    select jsonb_build_object('question', c.question, 'answer', c.answer)
    from candidates c
    order by c.priority
    limit 1
  $query$, p_table_name, p_table_name)
  into v_result
  using p_group, p_random_key;

  return v_result;
end;
$$;

revoke all on function public.get_admin_question_hint(text,text,double precision)
  from public, anon;
grant execute on function public.get_admin_question_hint(text,text,double precision)
  to authenticated, service_role;

create or replace function public.get_missing_public_event_sources(
  p_urls text[],
  p_start_date date
)
returns text[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result text[];
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_start_date is null then
    raise exception 'invalid_start_date' using errcode = '22023';
  end if;

  select coalesce(array_agg(source.url order by source.ordinality), array[]::text[])
  into v_result
  from unnest(coalesce(p_urls, array[]::text[])) with ordinality source(url, ordinality)
  where nullif(trim(source.url), '') is not null
    and not exists (
      select 1 from public.recommended_event_url existing
      where existing.master_url = source.url
        and existing.start_date::date = p_start_date
    );
  return v_result;
end;
$$;

revoke all on function public.get_missing_public_event_sources(text[],date)
  from public, anon;
grant execute on function public.get_missing_public_event_sources(text[],date)
  to authenticated, service_role;

update public.dashboard_setting setting
set accounting_account_id = (
  select account_row.id
  from public.accounting_account account_row
  where lower(trim(account_row.created_by)) = lower(trim(setting.account))
    and account_row.account = setting.accounting_account_name
    and account_row.is_valid is true
  order by account_row.created_at desc nulls last, account_row.id
  limit 1
)
where (
    setting.accounting_account_id is null
    or not exists (
      select 1 from public.accounting_account existing
      where existing.id = setting.accounting_account_id
        and lower(trim(existing.created_by)) = lower(trim(setting.account))
        and existing.is_valid is true
    )
  );

update public.dashboard_setting setting
set point_account_id = (
  select account_row.id
  from public.point_record_account account_row
  where lower(trim(account_row.created_by)) = lower(trim(setting.account))
    and account_row.account = setting.point_account_name
    and account_row.is_valid is true
  order by account_row.created_at desc nulls last, account_row.id
  limit 1
)
where (
    setting.point_account_id is null
    or not exists (
      select 1 from public.point_record_account existing
      where existing.id = setting.point_account_id
        and lower(trim(existing.created_by)) = lower(trim(setting.account))
        and existing.is_valid is true
    )
  );

do $$
begin
  if exists (
    select 1 from public.dashboard_setting setting
    where (nullif(trim(setting.accounting_account_name), '') is not null and (
        setting.accounting_account_id is null
        or not exists (
          select 1 from public.accounting_account account_row
          where account_row.id = setting.accounting_account_id
            and lower(trim(account_row.created_by)) = lower(trim(setting.account))
            and account_row.is_valid is true
        )
      ))
       or (nullif(trim(setting.point_account_name), '') is not null and (
        setting.point_account_id is null
        or not exists (
          select 1 from public.point_record_account account_row
          where account_row.id = setting.point_account_id
            and lower(trim(account_row.created_by)) = lower(trim(setting.account))
            and account_row.is_valid is true
        )
      ))
  ) then
    raise exception 'dashboard_account_id_backfill_incomplete';
  end if;
end;
$$;

drop function if exists public.get_my_memory_initial_window(date,date,integer);

notify pgrst, 'reload schema';
commit;
