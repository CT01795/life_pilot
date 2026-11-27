begin;

-- The existing bootstrap owns authorization, cloud usage and posting quotas.
-- Resolve the device-only tier in the same request without granting cloud access.
create or replace function public.get_my_subscription_bootstrap_v2(
  p_storage_plan text default 'cloud'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bootstrap jsonb;
  v_local_free_name text;
begin
  v_bootstrap := public.get_my_subscription_bootstrap(p_storage_plan);

  if auth.uid() is not null and coalesce(
    (select u.raw_user_meta_data ->> 'account_type'
     from auth.users u where u.id = auth.uid()), 'personal'
  ) <> 'vendor' then
    select p.version_name into v_local_free_name
    from public.subscription_pricing_versions p
    where p.storage_plan = 'local'
      and p.quarterly_price_twd = 0
      and p.is_active
      and p.effective_at <= now()
    order by p.effective_at desc, p.id desc
    limit 1;
  end if;

  return v_bootstrap || jsonb_build_object(
    'local_free_version_name', v_local_free_name
  );
end;
$$;

revoke all on function public.get_my_subscription_bootstrap_v2(text)
  from public, anon;
grant execute on function public.get_my_subscription_bootstrap_v2(text)
  to authenticated;
notify pgrst, 'reload schema';
commit;
