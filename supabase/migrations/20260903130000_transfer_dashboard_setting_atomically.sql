begin;

create or replace function public.restore_local_personal_records_with_setting(
  p_records jsonb,
  p_dashboard_setting jsonb default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  restored_count integer;
  current_email text := public.life_pilot_user_email();
begin
  if auth.uid() is null or jsonb_typeof(coalesce(p_records, '[]'::jsonb)) <> 'array' then
    raise exception 'invalid_local_upload_payload';
  end if;

  if p_dashboard_setting is not null then
    if jsonb_typeof(p_dashboard_setting) <> 'object'
       or lower(trim(coalesce(p_dashboard_setting ->> 'account', ''))) <> current_email then
      raise exception 'local_upload_owner_mismatch:dashboard_setting';
    end if;
  end if;

  -- Both operations run in this transaction. If restoring the dashboard
  -- preference fails, the personal-record restore is rolled back as well.
  restored_count := public.restore_local_personal_records_admin(
    coalesce(p_records, '[]'::jsonb)
  );

  if p_dashboard_setting is not null then
    insert into public.dashboard_setting
    select *
      from jsonb_populate_record(
        null::public.dashboard_setting,
        p_dashboard_setting
      )
    on conflict (account) do update set
      recommend_event_city = excluded.recommend_event_city,
      recommend_place_city = excluded.recommend_place_city,
      language = excluded.language,
      accounting_account_id = excluded.accounting_account_id,
      accounting_account_name = excluded.accounting_account_name,
      point_account_id = excluded.point_account_id,
      point_account_name = excluded.point_account_name;
  end if;

  return restored_count;
end;
$function$;

revoke all on function public.restore_local_personal_records_with_setting(jsonb, jsonb)
  from public, anon;
grant execute on function public.restore_local_personal_records_with_setting(jsonb, jsonb)
  to authenticated, service_role;

commit;
