begin;

create or replace function public.get_public_event_deduplication_rows_v2(
  p_dates date[]
)
returns table(
  is_deleted boolean,
  id text,
  name text,
  start_date timestamptz,
  start_time text,
  city text,
  location text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if coalesce(array_length(p_dates, 1), 0) = 0 then
    return;
  end if;
  return query
    select false, event.id, event.name, event.start_date,
      event.start_time, event.city, event.location
    from public.recommended_events event
    where event.start_date::date = any(p_dates)
    union all
    select true, deleted.id, deleted.name, deleted.start_date,
      deleted.start_time, deleted.city, deleted.location
    from public.recommended_events_deleted deleted
    where deleted.start_date::date = any(p_dates)
    order by 4, 2, 1;
end;
$$;

revoke all on function public.get_public_event_deduplication_rows_v2(date[])
  from public, anon;
grant execute on function public.get_public_event_deduplication_rows_v2(date[])
  to authenticated, service_role;

create or replace function public.life_pilot_import_public_events(
  p_source_url text,
  p_events jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
set timezone = 'UTC'
as $$
declare
  item jsonb;
  rows jsonb := '[]'::jsonb;
  v_columns text;
  v_values text;
  v_received integer;
  v_inserted integer := 0;
  v_duplicate_deleted integer := 0;
  v_duplicate_existing integer := 0;
  v_conflicts integer := 0;
  v_count integer;
  v_source text := trim(p_source_url);
  v_identity jsonb;
  v_time text;
  v_day timestamptz;
begin
  if auth.uid() is null or nullif(public.life_pilot_user_email(), '') is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if v_source is null or v_source !~*
    '^https://(strolltimes[.]com|cloud[.]culture[.]tw|www[.]accupass[.]com|www[.]paperwindmill[.]com[.]tw|event[.]moc[.]gov[.]tw|www[.]taiwan[.]net[.]tw|www[.]ntpc[.]gov[.]tw|cultureexpress[.]taipei)(:443)?([/?#]|$)'
      or v_source ~ '[[:cntrl:]\\]' then
    raise exception 'Event source is not allowed' using errcode = '42501';
  end if;
  if jsonb_typeof(p_events) is distinct from 'array' then
    raise exception 'Events must be an array' using errcode = '22023';
  end if;
  v_received := jsonb_array_length(p_events);
  if v_received not between 1 and 200 then
    raise exception 'Expected 1 to 200 events' using errcode = '22023';
  end if;

  for item in select value from jsonb_array_elements(p_events) loop
    rows := rows || jsonb_build_array(
      public.life_pilot_sanitize_public_event(item, v_source)
    );
  end loop;

  perform pg_advisory_xact_lock(hashtext('life_pilot_public_import'));
  for item in select value from jsonb_array_elements(rows) loop
    v_identity := public.life_pilot_import_identity(item);
    v_time := public.life_pilot_import_time(item ->> 'start_time');
    v_day := (v_identity ->> 1)::date::timestamptz;
    if exists (
      select 1
      from public.recommended_events_deleted deleted
      cross join lateral (select to_jsonb(deleted) value) source
      where deleted.start_date >= v_day
        and deleted.start_date < v_day + interval '1 day'
        and (
          (
            public.life_pilot_import_identity(source.value) = v_identity
            and (
              v_time = ''
              or public.life_pilot_import_time(source.value ->> 'start_time') = v_time
            )
          )
          or (
            trim(coalesce(source.value ->> 'id', '')) = trim(item ->> 'id')
            and public.life_pilot_import_identity(source.value) -> 1 = v_identity -> 1
            and public.life_pilot_import_identity(source.value) -> 2 = v_identity -> 2
            and public.life_pilot_import_identity(source.value) -> 3 = v_identity -> 3
          )
          or (
            nullif(trim(item ->> 'master_url'), '') = trim(source.value ->> 'master_url')
            and public.life_pilot_import_identity(source.value) -> 1 = v_identity -> 1
            and public.life_pilot_import_identity(source.value) -> 2 = v_identity -> 2
            and public.life_pilot_import_identity(source.value) -> 3 = v_identity -> 3
            and public.life_pilot_import_time(source.value ->> 'start_time') = v_time
          )
        )
    ) then
      v_duplicate_deleted := v_duplicate_deleted + 1;
      continue;
    end if;
    if exists (
      select 1
      from public.recommended_events event
      where event.start_date >= v_day
        and event.start_date < v_day + interval '1 day'
        and public.life_pilot_import_identity(to_jsonb(event)) = v_identity
        and (
          v_time = ''
          or public.life_pilot_import_time(event.start_time) = v_time
        )
    ) then
      v_duplicate_existing := v_duplicate_existing + 1;
      continue;
    end if;

    select
      string_agg(format('%I', attribute.attname), ',' order by attribute.attnum),
      string_agg(format('record.%I', attribute.attname), ',' order by attribute.attnum)
      into v_columns, v_values
    from pg_catalog.pg_attribute attribute
    where attribute.attrelid = 'public.recommended_events'::regclass
      and attribute.attnum > 0
      and not attribute.attisdropped
      and attribute.attgenerated = ''
      and attribute.attidentity = ''
      and item ? attribute.attname;
    execute format(
      'insert into public.recommended_events (%s) '
      'select %s from jsonb_populate_record(null::public.recommended_events,$1) record '
      'on conflict do nothing',
      v_columns,
      v_values
    ) using item;
    get diagnostics v_count = row_count;
    if v_count = 0 then
      v_conflicts := v_conflicts + 1;
    else
      v_inserted := v_inserted + v_count;
    end if;
  end loop;

  insert into public.recommended_event_url(master_url, start_date)
  values (
    v_source,
    date_trunc('day', now() at time zone 'Asia/Taipei') at time zone 'Asia/Taipei'
  )
  on conflict(master_url, start_date) do nothing;

  return jsonb_build_object(
    'status', 'ok',
    'received_rows', v_received,
    'inserted_rows', v_inserted,
    'duplicate_rows', v_duplicate_deleted + v_duplicate_existing + v_conflicts,
    'duplicate_deleted_rows', v_duplicate_deleted,
    'duplicate_existing_rows', v_duplicate_existing,
    'conflict_rows', v_conflicts
  );
end;
$$;

revoke all on function public.life_pilot_import_public_events(text, jsonb)
  from public, anon;
grant execute on function public.life_pilot_import_public_events(text, jsonb)
  to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
