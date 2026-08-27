begin;

alter table public.calendar_events
  add column if not exists country text,
  add column if not exists map_lat double precision,
  add column if not exists map_lng double precision;
alter table public.recommended_events
  add column if not exists country text,
  add column if not exists map_lat double precision,
  add column if not exists map_lng double precision;
alter table public.recommended_events_deleted
  add column if not exists country text,
  add column if not exists map_lat double precision,
  add column if not exists map_lng double precision;
alter table public.recommended_attractions
  add column if not exists country text,
  add column if not exists map_lat double precision,
  add column if not exists map_lng double precision;
alter table public.memory_trace
  add column if not exists country text,
  add column if not exists map_lat double precision,
  add column if not exists map_lng double precision;

update public.calendar_events
set country = 'Taiwan'
where nullif(btrim(country), '') is null;

update public.recommended_events
set country = 'Taiwan'
where nullif(btrim(country), '') is null;

update public.recommended_events_deleted
set country = 'Taiwan'
where nullif(btrim(country), '') is null;

update public.recommended_attractions
set country = 'Taiwan'
where nullif(btrim(country), '') is null;

update public.memory_trace
set country = 'Taiwan'
where nullif(btrim(country), '') is null;

alter table public.calendar_events
  alter column country set default 'Taiwan',
  alter column country set not null;
alter table public.recommended_events
  alter column country set default 'Taiwan',
  alter column country set not null;
alter table public.recommended_events_deleted
  alter column country set default 'Taiwan',
  alter column country set not null;
alter table public.recommended_attractions
  alter column country set default 'Taiwan',
  alter column country set not null;
alter table public.memory_trace
  alter column country set default 'Taiwan',
  alter column country set not null;

alter table public.calendar_events
  drop constraint if exists calendar_events_country_not_blank,
  add constraint calendar_events_country_not_blank
    check (nullif(btrim(country), '') is not null);

alter table public.calendar_events
  drop constraint if exists calendar_events_map_coordinates_check,
  add constraint calendar_events_map_coordinates_check check (
    (map_lat is null and map_lng is null)
    or (map_lat is not null and map_lng is not null
        and map_lat between -90 and 90 and map_lng between -180 and 180)
  );
alter table public.recommended_events
  drop constraint if exists recommended_events_map_coordinates_check,
  add constraint recommended_events_map_coordinates_check check (
    (map_lat is null and map_lng is null)
    or (map_lat is not null and map_lng is not null
        and map_lat between -90 and 90 and map_lng between -180 and 180)
  );
alter table public.recommended_events_deleted
  drop constraint if exists recommended_events_deleted_map_coordinates_check,
  add constraint recommended_events_deleted_map_coordinates_check check (
    (map_lat is null and map_lng is null)
    or (map_lat is not null and map_lng is not null
        and map_lat between -90 and 90 and map_lng between -180 and 180)
  );
alter table public.recommended_attractions
  drop constraint if exists recommended_attractions_map_coordinates_check,
  add constraint recommended_attractions_map_coordinates_check check (
    (map_lat is null and map_lng is null)
    or (map_lat is not null and map_lng is not null
        and map_lat between -90 and 90 and map_lng between -180 and 180)
  );
alter table public.memory_trace
  drop constraint if exists memory_trace_map_coordinates_check,
  add constraint memory_trace_map_coordinates_check check (
    (map_lat is null and map_lng is null)
    or (map_lat is not null and map_lng is not null
        and map_lat between -90 and 90 and map_lng between -180 and 180)
  );
alter table public.recommended_events
  drop constraint if exists recommended_events_country_not_blank,
  add constraint recommended_events_country_not_blank
    check (nullif(btrim(country), '') is not null);
alter table public.recommended_events_deleted
  drop constraint if exists recommended_events_deleted_country_not_blank,
  add constraint recommended_events_deleted_country_not_blank
    check (nullif(btrim(country), '') is not null);
alter table public.recommended_attractions
  drop constraint if exists recommended_attractions_country_not_blank,
  add constraint recommended_attractions_country_not_blank
    check (nullif(btrim(country), '') is not null);
alter table public.memory_trace
  drop constraint if exists memory_trace_country_not_blank,
  add constraint memory_trace_country_not_blank
    check (nullif(btrim(country), '') is not null);

create index if not exists calendar_events_country_city_idx
  on public.calendar_events (country, city);
create index if not exists recommended_events_country_city_idx
  on public.recommended_events (country, city);
create index if not exists recommended_events_deleted_country_city_idx
  on public.recommended_events_deleted (country, city);
create index if not exists recommended_attractions_country_city_idx
  on public.recommended_attractions (country, city);
create index if not exists memory_trace_country_city_idx
  on public.memory_trace (country, city);

commit;
