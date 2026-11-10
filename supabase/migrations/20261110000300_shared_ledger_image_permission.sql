-- A recipient may replace a shared ledger image only when the owner grants
-- this permission. Image replacement is immediate and does not create a
-- ledger-entry proposal; entry proposal permission remains independent.
begin;

alter table public.ledger_read_shares
  add column if not exists allow_image_changes boolean not null default false;

create or replace function public.set_my_ledger_share_image_permission(
  p_share_id uuid, p_allowed boolean
) returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or p_allowed is null then
    raise exception 'ledger_share_unavailable' using errcode = '42501';
  end if;
  update public.ledger_read_shares
  set allow_image_changes = p_allowed
  where id = p_share_id and owner_id = auth.uid()
    and (not p_allowed or public.life_pilot_ledger_share_owner_eligible(auth.uid()));
  if not found then
    raise exception 'ledger_share_unavailable' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.can_change_shared_ledger_image(p_share_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.ledger_read_shares s
    join auth.users recipient on recipient.id = s.recipient_id
    join auth.users owner_row on owner_row.id = s.owner_id
    where s.id = p_share_id
      and recipient.id = auth.uid()
      and s.allow_image_changes
      and (recipient.banned_until is null or recipient.banned_until <= now())
      and public.life_pilot_ledger_share_owner_eligible(s.owner_id)
      and (
        (s.kind = 'accounting' and exists (
          select 1 from public.accounting_account a
          where a.id::text = s.account_id and a.is_valid
            and lower(trim(a.created_by)) = lower(trim(owner_row.email))
        )) or
        (s.kind = 'points' and exists (
          select 1 from public.point_record_account a
          where a.id::text = s.account_id and a.is_valid
            and lower(trim(a.created_by)) = lower(trim(owner_row.email))
        ))
      )
  );
$$;

create or replace function public.update_my_shared_ledger_image(
  p_share_id uuid, p_master_graph_url text, p_thumbnail_base64 text
) returns void language plpgsql security definer set search_path = '' as $$
declare
  shared public.ledger_read_shares%rowtype;
  owner_email text;
begin
  if nullif(p_master_graph_url, '') is null
     or length(p_master_graph_url) > 33554432
     or nullif(p_thumbnail_base64, '') is null
     or length(p_thumbnail_base64) > 65536
     or (p_thumbnail_base64 not like 'iVBORw0KGgo%'
         and p_thumbnail_base64 not like '/9j/%') then
    raise exception 'invalid_ledger_image' using errcode = '22023';
  end if;

  select s.* into shared
  from public.ledger_read_shares s
  join auth.users recipient on recipient.id = s.recipient_id
  where s.id = p_share_id and recipient.id = auth.uid()
    and s.allow_image_changes
    and (recipient.banned_until is null or recipient.banned_until <= now())
    and public.life_pilot_ledger_share_owner_eligible(s.owner_id)
  for update of s;
  if not found then
    raise exception 'ledger_image_change_not_allowed' using errcode = '42501';
  end if;

  select lower(trim(email)) into owner_email
  from auth.users where id = shared.owner_id;
  if shared.kind = 'accounting' then
    update public.accounting_account
    set master_graph_url = p_master_graph_url,
        thumbnail_base64 = p_thumbnail_base64
    where id::text = shared.account_id and is_valid
      and lower(trim(created_by)) = owner_email;
  elsif shared.kind = 'points' then
    update public.point_record_account
    set master_graph_url = p_master_graph_url,
        thumbnail_base64 = p_thumbnail_base64
    where id::text = shared.account_id and is_valid
      and lower(trim(created_by)) = owner_email;
  else
    raise exception 'unsupported_ledger_kind' using errcode = '22023';
  end if;
  if not found then
    raise exception 'ledger_share_unavailable' using errcode = '42501';
  end if;
end;
$$;

-- Keep the overview response compact: the permission is added to the totals
-- object already returned for each visible account, avoiding another request.
create or replace function public.list_my_shared_ledger_overview_window(
  p_kind text, p_limit integer, p_offset integer, p_visible_limit integer,
  p_month_start timestamptz, p_month_end timestamptz,
  p_day_start timestamptz, p_day_end timestamptz
) returns table(share_id uuid, kind text, account_id text, account_name text, totals jsonb)
language plpgsql stable security invoker set search_path = '' as $$
declare
  entry record;
  position_in_page integer := 0;
  visible_limit integer := greatest(0, least(coalesce(p_visible_limit, 0), 100));
  image_allowed boolean;
begin
  for entry in
    select * from public.list_my_shared_ledgers_by_kind(
      p_kind, least(coalesce(p_limit, 30), visible_limit + 1), p_offset)
  loop
    position_in_page := position_in_page + 1;
    if position_in_page > visible_limit then
      share_id := null; kind := null; account_id := null;
      account_name := null; totals := null;
      return next;
      return;
    end if;
    share_id := entry.share_id;
    kind := entry.kind;
    account_id := entry.account_id;
    account_name := entry.account_name;
    select s.allow_image_changes into image_allowed
      from public.ledger_read_shares s where s.id = share_id;
    begin
      totals := public.get_my_shared_ledger_totals(
        share_id, p_month_start, p_month_end, p_day_start, p_day_end)
        || jsonb_build_object('allow_image_changes', coalesce(image_allowed, false));
    exception when insufficient_privilege then
      totals := null;
    end;
    return next;
  end loop;
end;
$$;

-- Bundle both capabilities with the existing first detail page.
create or replace function public.get_my_shared_ledger_detail_first_page(
  p_share_id uuid, p_limit integer,
  p_month_start timestamptz, p_month_end timestamptz,
  p_day_start timestamptz, p_day_end timestamptz
) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_share public.ledger_read_shares%rowtype;
  v_owner_email text;
  v_account_id uuid;
  v_currency text;
  v_table text;
  v_currency_json text;
  v_currency_filter text;
  v_result jsonb;
begin
  if p_month_start is null or p_month_end is null or p_day_start is null or p_day_end is null
     or p_month_end <= p_month_start or p_month_end > p_month_start + interval '32 days'
     or p_day_end <= p_day_start or p_day_end > p_day_start + interval '26 hours'
     or p_day_start < p_month_start or p_day_end > p_month_end then
    raise exception 'invalid_ledger_summary_range';
  end if;
  select s.* into v_share
  from public.ledger_read_shares s
  join auth.users r on r.id = s.recipient_id
  where s.id = p_share_id and r.id = auth.uid()
    and (r.banned_until is null or r.banned_until <= now())
    and public.life_pilot_ledger_share_owner_eligible(s.owner_id);
  if not found then raise exception 'ledger_share_unavailable' using errcode = '42501'; end if;
  select lower(trim(o.email)) into v_owner_email from auth.users o where o.id = v_share.owner_id;
  if v_share.kind = 'accounting' then
    select a.id, a.main_currency into v_account_id, v_currency
    from public.accounting_account a
    where a.id::text = v_share.account_id and lower(trim(a.created_by)) = v_owner_email and a.is_valid;
    v_table := 'accounting_detail';
    v_currency_json := ', ''currency'', d.currency';
    if v_account_id is not null and nullif(trim(v_currency), '') is null then
      raise exception 'Missing accounting currency' using errcode = '22023';
    end if;
    v_currency_filter := 'and d.currency = $6';
  elsif v_share.kind = 'points' then
    select a.id into v_account_id
    from public.point_record_account a
    where a.id::text = v_share.account_id and lower(trim(a.created_by)) = v_owner_email and a.is_valid;
    v_table := 'point_record_detail';
    v_currency_json := '';
    v_currency_filter := '';
  end if;
  if v_account_id is null then raise exception 'ledger_share_unavailable' using errcode = '42501'; end if;
  execute format($query$
    with summary as (
      select coalesce(sum(d.value), 0) as total,
        coalesce(sum(d.value) filter (where d.date >= $2 and d.date < $3), 0) as month,
        coalesce(sum(d.value) filter (where d.date >= $4 and d.date < $5), 0) as today
      from public.%1$I d where d.account_id = $1 and d.date is not null %2$s
    ), page as (
      select d.id, d.date, jsonb_build_object('entry', jsonb_build_object(
        'id', d.id, 'date', d.date, 'type', d.type, 'description', d.description,
        'value', d.value, 'primary_category', d.primary_category,
        'secondary_category', d."group" %3$s)) as item
      from public.%1$I d
      where d.account_id = $1 and d.primary_category is distinct from 'reserved'
      order by d.date desc, d.id desc limit $9
    )
    select jsonb_build_object(
      'can_propose', $7::boolean,
      'can_change_image', $8::boolean,
      'totals', jsonb_build_object('total', summary.total,
        'currency', $6::text, 'month', summary.month, 'today', summary.today),
      'entries', coalesce((select jsonb_agg(page.item order by page.date desc, page.id desc) from page), '[]'::jsonb))
    from summary
  $query$, v_table, v_currency_filter, v_currency_json)
  into v_result using v_account_id, p_month_start, p_month_end, p_day_start,
    p_day_end, v_currency, v_share.allow_change_proposals,
    v_share.allow_image_changes, least(greatest(coalesce(p_limit, 30), 1), 30);
  return v_result;
end;
$$;

revoke all on function public.set_my_ledger_share_image_permission(uuid,boolean),
  public.can_change_shared_ledger_image(uuid),
  public.update_my_shared_ledger_image(uuid,text,text) from public, anon;
grant execute on function public.set_my_ledger_share_image_permission(uuid,boolean),
  public.can_change_shared_ledger_image(uuid),
  public.update_my_shared_ledger_image(uuid,text,text) to authenticated;
revoke all on function public.list_my_shared_ledger_overview_window(text,integer,integer,integer,timestamptz,timestamptz,timestamptz,timestamptz),
  public.get_my_shared_ledger_detail_first_page(uuid,integer,timestamptz,timestamptz,timestamptz,timestamptz)
  from public, anon;
grant execute on function public.list_my_shared_ledger_overview_window(text,integer,integer,integer,timestamptz,timestamptz,timestamptz,timestamptz),
  public.get_my_shared_ledger_detail_first_page(uuid,integer,timestamptz,timestamptz,timestamptz,timestamptz)
  to authenticated;

notify pgrst, 'reload schema';
commit;
