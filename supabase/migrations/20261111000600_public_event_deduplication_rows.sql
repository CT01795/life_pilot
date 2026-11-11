begin;
create or replace function public.get_public_event_deduplication_rows(
  p_deleted boolean, p_dates date[]
) returns table(id text,name text,start_date timestamptz,start_time text,city text,location text)
language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if coalesce(array_length(p_dates,1),0)=0 then return; end if;
  if p_deleted then
    return query select e.id,e.name,e.start_date,e.start_time,e.city,e.location
      from public.recommended_events_deleted e where e.start_date::date=any(p_dates)
      order by e.start_date,e.id;
  else
    return query select e.id,e.name,e.start_date,e.start_time,e.city,e.location
      from public.recommended_events e where e.start_date::date=any(p_dates)
      order by e.start_date,e.id;
  end if;
end; $$;
revoke all on function public.get_public_event_deduplication_rows(boolean,date[]) from public,anon;
grant execute on function public.get_public_event_deduplication_rows(boolean,date[]) to authenticated,service_role;
notify pgrst,'reload schema';
commit;
