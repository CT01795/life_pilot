begin;

-- Initialize the organizer account and return the complete first-screen
-- snapshot in one transaction. This replaces the former ensure + three-read
-- sequence without relaxing the validation inside ensure_my_vendor_account.
create or replace function public.get_my_vendor_dashboard_bootstrap(
  p_day_start timestamp with time zone
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
begin
  perform public.ensure_my_vendor_account();
  return jsonb_build_object(
    'status', public.get_my_vendor_subscription_status(),
    'metrics', public.get_my_vendor_dashboard_metrics(p_day_start),
    'plans', coalesce(
      public.get_pricing_catalog(true) -> 'versions',
      '[]'::jsonb
    )
  );
end;
$function$;

-- Owner filtering is the common prefix for dashboard totals, active-content
-- counts, recent submissions and quota usage. The date expression then lets
-- active/expired checks avoid scanning every row owned by that organizer.
create index if not exists recommended_events_vendor_active_idx
  on public.recommended_events (
    lower(trim(account)),
    (coalesce(end_date, start_date))
  );
create index if not exists recommended_attractions_vendor_active_idx
  on public.recommended_attractions (
    lower(trim(account)),
    (coalesce(end_date, start_date))
  );

revoke all on function public.get_my_vendor_dashboard_bootstrap(
  timestamp with time zone
) from public, anon;
grant execute on function public.get_my_vendor_dashboard_bootstrap(
  timestamp with time zone
) to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
