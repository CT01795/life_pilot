alter table public.point_record_detail
  add column if not exists event_id text;

create index if not exists point_record_detail_event_date_idx
  on public.point_record_detail (event_id, date desc)
  where event_id is not null;

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
      account_id, type, value, description, primary_category, "group",
      event_id, date
    ) values (
      p_account_id,
      p_type,
      (record_row->>'value')::integer,
      record_row->>'description',
      coalesce(nullif(record_row->>'primary_category', ''), 'uncategorized'),
      coalesce(record_row->>'group', ''),
      nullif(record_row->>'event_id', ''),
      coalesce(
        nullif(record_row->>'date', '')::timestamp with time zone,
        now()
      )
    );

    update public.point_record_account
    set points = coalesce(points, 0) +
      case when p_type = 'points'
        then (record_row->>'value')::integer else 0 end
    where id = p_account_id;
  end loop;
end;
$function$;

revoke all on function public.add_point_records_batch(uuid, text, jsonb)
from public, anon;
grant execute on function public.add_point_records_batch(uuid, text, jsonb)
to authenticated;
