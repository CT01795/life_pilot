-- Prevent unauthenticated and anonymous Supabase users from accessing stock data.
-- Registered users may read stock data. Mutations remain backend/service-role only.

do $migration$
declare
  stock_table text;
  read_policy text;
begin
  foreach stock_table in array array[
    'stock_date',
    'stock_daily_price',
    'stock_institutional',
    'futures_institutional',
    'stock_predicted',
    'stock_predicted_list'
  ]
  loop
    if to_regclass(format('public.%I', stock_table)) is null then
      raise notice 'Skipping missing stock table: public.%', stock_table;
      continue;
    end if;

    read_policy := stock_table || '_registered_users_read';

    execute format(
      'alter table public.%I enable row level security',
      stock_table
    );

    -- Remove privileges inherited through the API roles or PUBLIC before
    -- granting back the minimum access required by the application.
    execute format('revoke all on table public.%I from public', stock_table);
    execute format('revoke all on table public.%I from anon', stock_table);
    execute format('revoke all on table public.%I from authenticated', stock_table);

    execute format(
      'drop policy if exists %I on public.%I',
      read_policy,
      stock_table
    );
    execute format(
      'create policy %I on public.%I for select to authenticated using (' ||
      'auth.uid() is not null and ' ||
      'coalesce((auth.jwt() ->> ''is_anonymous'')::boolean, false) = false' ||
      ')',
      read_policy,
      stock_table
    );

    execute format('grant select on table public.%I to authenticated', stock_table);
    execute format('grant all on table public.%I to service_role', stock_table);
  end loop;
end
$migration$;
