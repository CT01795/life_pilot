begin;

drop function if exists public.get_my_memory_window(date,date,integer,boolean);

create or replace function public.get_my_memory_window(
  p_from date,
  p_to date,
  p_limit integer default 12,
  p_offset integer default 0,
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
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
begin
  if auth.uid() is null or nullif(v_email, '') is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if p_from is null or p_to is null or p_from > p_to then
    raise exception 'invalid_memory_window' using errcode = '22023';
  end if;

  if v_offset = 0 and not exists (
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
    offset v_offset
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

revoke all on function public.get_my_memory_window(date,date,integer,integer,boolean)
  from public, anon;
grant execute on function public.get_my_memory_window(date,date,integer,integer,boolean)
  to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
