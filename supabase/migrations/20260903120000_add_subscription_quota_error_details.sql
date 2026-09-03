create or replace function public.life_pilot_raise_if_quota_reached(p_resource text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_usage bigint;
  current_limit bigint;
begin
  if public.life_pilot_is_admin() then return; end if;
  if not public.life_pilot_cloud_writes_allowed() then
    raise exception using
      errcode = 'P0001',
      message = 'LIFE_PILOT_RENEWAL_REQUIRED';
  end if;

  current_usage := public.life_pilot_my_usage(p_resource);
  current_limit := public.life_pilot_plan_limit(p_resource);
  if current_usage >= current_limit then
    raise exception using
      errcode = 'P0001',
      message = 'LIFE_PILOT_QUOTA_REACHED:' || p_resource || ':' ||
                current_usage || ':' || current_limit;
  end if;
end;
$$;
