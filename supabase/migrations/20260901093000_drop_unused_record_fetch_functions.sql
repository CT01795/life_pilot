begin;

drop function if exists public.fetch_today_accountings(uuid, text);
drop function if exists public.fetch_today_point_records(uuid, text);

commit;
