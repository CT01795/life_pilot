begin;

update public.calendar_events set country = 'TW' where lower(btrim(country)) = 'taiwan';
update public.recommended_events set country = 'TW' where lower(btrim(country)) = 'taiwan';
update public.recommended_events_deleted set country = 'TW' where lower(btrim(country)) = 'taiwan';
update public.recommended_attractions set country = 'TW' where lower(btrim(country)) = 'taiwan';
update public.memory_trace set country = 'TW' where lower(btrim(country)) = 'taiwan';

alter table public.calendar_events alter column country set default 'TW';
alter table public.recommended_events alter column country set default 'TW';
alter table public.recommended_events_deleted alter column country set default 'TW';
alter table public.recommended_attractions alter column country set default 'TW';
alter table public.memory_trace alter column country set default 'TW';

alter table public.calendar_events
  drop constraint if exists calendar_events_country_code_format_check,
  add constraint calendar_events_country_code_format_check
    check (country ~ '^[A-Z]{2}$');
alter table public.recommended_events
  drop constraint if exists recommended_events_country_code_format_check,
  add constraint recommended_events_country_code_format_check
    check (country ~ '^[A-Z]{2}$');
alter table public.recommended_events_deleted
  drop constraint if exists recommended_events_deleted_country_code_format_check,
  add constraint recommended_events_deleted_country_code_format_check
    check (country ~ '^[A-Z]{2}$');
alter table public.recommended_attractions
  drop constraint if exists recommended_attractions_country_code_format_check,
  add constraint recommended_attractions_country_code_format_check
    check (country ~ '^[A-Z]{2}$');
alter table public.memory_trace
  drop constraint if exists memory_trace_country_code_format_check,
  add constraint memory_trace_country_code_format_check
    check (country ~ '^[A-Z]{2}$');

commit;
