begin;

-- Keep the three-argument function available to older app builds. This
-- overload returns the same snapshot, suppressing an unchanged plan payload.
create or replace function public.get_my_vendor_dashboard_bootstrap(
  p_day_start timestamptz,
  p_force_refresh boolean,
  p_include_plans boolean,
  p_known_plans_version text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_dashboard jsonb;
  v_version text;
begin
  v_dashboard := public.get_my_vendor_dashboard_bootstrap(
    p_day_start, p_force_refresh, p_include_plans
  );
  if jsonb_typeof(v_dashboard -> 'plans') = 'array' then
    v_version := md5((v_dashboard -> 'plans')::text);
    if v_version = p_known_plans_version then
      v_dashboard := jsonb_set(v_dashboard, '{plans}', 'null'::jsonb);
    end if;
  end if;
  return v_dashboard || jsonb_build_object('plans_version', v_version);
end;
$$;

revoke all on function public.get_my_vendor_dashboard_bootstrap(
  timestamptz, boolean, boolean, text
) from public, anon;
grant execute on function public.get_my_vendor_dashboard_bootstrap(
  timestamptz, boolean, boolean, text
) to authenticated, service_role;
notify pgrst, 'reload schema';
commit;
