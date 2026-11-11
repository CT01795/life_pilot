begin;
create or replace function public.get_my_ledger_history_window_v2(
  p_kind text, p_account_id uuid, p_type text, p_from timestamptz,
  p_until timestamptz, p_include_reserved boolean, p_include_latest boolean
) returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare
  v_table text; v_account_table text; v_total_column text;
  v_columns text := 'd.id,d.account_id,d.created_at,d.date,d.primary_category,d."group",d.description,d.type,d.value';
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode='42501'; end if;
  if p_from is null or p_until is null or p_until <= p_from or p_until > p_from + interval '101 days' then
    raise exception 'invalid_ledger_history_window' using errcode='22023';
  end if;
  if p_kind='accounting' then
    v_table:='accounting_detail'; v_account_table:='accounting_account'; v_total_column:='balance';
    v_columns:=v_columns||',d.currency';
  elsif p_kind='points' then
    v_table:='point_record_detail'; v_account_table:='point_record_account'; v_total_column:='points';
  else raise exception 'invalid_ledger_kind' using errcode='22023'; end if;
  execute format($query$
    with page as (
      select %1$s from public.%2$I d where d.account_id=$1 and d.type ilike $2
        and ((d.date >= $3 and d.date < $4) or ($5 and d.primary_category='reserved'))
      order by d.date desc limit 1001
    ), fallback as (
      select %1$s from public.%2$I d where $6
        and not exists(select 1 from page where primary_category is distinct from 'reserved')
        and d.account_id=$1 and d.type ilike $2 and d.primary_category<>'reserved'
      order by d.date desc limit 1
    ), boundary as (select least($3,(select date from fallback)) before),
    display_rows as (select * from page union all select * from fallback)
    select jsonb_build_object(
      'rows',case when (select count(*) from page)<=1000 then coalesce((select jsonb_agg(to_jsonb(r) order by r.date desc) from display_rows r),'[]'::jsonb) end,
      'next_before',boundary.before,
      'next_date',(select d.date from public.%2$I d where d.account_id=$1 and d.type ilike $2 and d.date<boundary.before and d.primary_category<>'reserved' order by d.date desc limit 1),
      'total',(select a.%3$I from public.%4$I a where a.id=$1 and a.is_valid is true)
    ) from boundary
  $query$,v_columns,v_table,v_total_column,v_account_table)
  into v_result using p_account_id,p_type,p_from,p_until,p_include_reserved,p_include_latest;
  return v_result;
end; $$;
revoke all on function public.get_my_ledger_history_window_v2(text,uuid,text,timestamptz,timestamptz,boolean,boolean) from public,anon;
grant execute on function public.get_my_ledger_history_window_v2(text,uuid,text,timestamptz,timestamptz,boolean,boolean) to authenticated,service_role;
notify pgrst,'reload schema';
commit;
