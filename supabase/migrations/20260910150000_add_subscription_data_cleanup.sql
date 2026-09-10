begin;

create or replace function public.cleanup_subscription_data(
  p_email text default null,
  p_mode text default 'excess'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  target_id uuid;
  target_email text;
  resource_limit bigint;
  reserved_count bigint;
  keep_regular bigint;
  affected integer;
  candidate record;
  deleted_counts jsonb := '{}'::jsonb;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if p_mode not in ('excess', 'all') then raise exception 'invalid_cleanup_mode'; end if;

  target_email := lower(trim(coalesce(p_email, public.life_pilot_user_email())));
  if target_email = '' then raise exception 'target_email_required'; end if;
  if target_email <> public.life_pilot_user_email()
     and not public.life_pilot_is_admin() then raise exception 'admin_required'; end if;

  select u.id into target_id from auth.users u where lower(u.email) = target_email;
  if target_id is null then raise exception 'user_not_found'; end if;
  perform pg_advisory_xact_lock(hashtext('life_pilot_cleanup:' || target_id::text));

  -- Child answer history must be removed before excess questions.
  if p_mode = 'all' then
    delete from public.game_grammar_user where owner_id = target_id;
    delete from public.game_sentence_user where owner_id = target_id;
    delete from public.game_speaking_user where owner_id = target_id;
    delete from public.game_social_user where owner_id = target_id;
    delete from public.game_translation_user where owner_id = target_id;
    delete from public.game_word_search_user where owner_id = target_id;
    delete from public.game_user where owner_id = target_id;

    delete from public.calendar_share_invitations
      where lower(trim(shared_by)) = target_email
         or lower(trim(invited_email)) = target_email;
    get diagnostics affected = row_count;
    deleted_counts := jsonb_set(deleted_counts, '{calendar_shares}', to_jsonb(affected));

    delete from public.calendar_events where lower(trim(account)) = target_email;
    get diagnostics affected = row_count;
    deleted_counts := jsonb_set(deleted_counts, '{calendar_events}', to_jsonb(affected));
    delete from public.memory_trace where lower(trim(account)) = target_email;
    get diagnostics affected = row_count;
    deleted_counts := jsonb_set(deleted_counts, '{memory_trace}', to_jsonb(affected));

    delete from public.accounting_detail d using public.accounting_account a
      where d.account_id = a.id and lower(trim(a.created_by)) = target_email;
    get diagnostics affected = row_count;
    deleted_counts := jsonb_set(deleted_counts, '{accounting_detail}', to_jsonb(affected));
    delete from public.accounting_balance_by_currency b using public.accounting_account a
      where b.account_id = a.id and lower(trim(a.created_by)) = target_email;
    delete from public.accounting_account where lower(trim(created_by)) = target_email;

    delete from public.point_record_detail d using public.point_record_account a
      where d.account_id = a.id and lower(trim(a.created_by)) = target_email;
    get diagnostics affected = row_count;
    deleted_counts := jsonb_set(deleted_counts, '{point_record_detail}', to_jsonb(affected));
    delete from public.point_record_account where lower(trim(created_by)) = target_email;

    delete from public.game_grammar where owner_id = target_id;
    get diagnostics affected = row_count;
    deleted_counts := jsonb_set(deleted_counts, '{game_questions}', to_jsonb(affected));
    delete from public.game_sentence where owner_id = target_id;
    get diagnostics affected = row_count;
    deleted_counts := jsonb_set(deleted_counts, '{game_questions}',
      to_jsonb(coalesce((deleted_counts->>'game_questions')::integer, 0) + affected));
    delete from public.game_translation where owner_id = target_id;
    get diagnostics affected = row_count;
    deleted_counts := jsonb_set(deleted_counts, '{game_questions}',
      to_jsonb(coalesce((deleted_counts->>'game_questions')::integer, 0) + affected));
    delete from public.game_social_scenarios where owner_id = target_id;
    get diagnostics affected = row_count;
    deleted_counts := jsonb_set(deleted_counts, '{game_questions}',
      to_jsonb(coalesce((deleted_counts->>'game_questions')::integer, 0) + affected));

    update public.dashboard_setting set accounting_account_id = null,
      accounting_account_name = null, point_account_id = null,
      point_account_name = null where lower(trim(account)) = target_email;
  else
    resource_limit := public.life_pilot_user_cloud_limit(target_id, 'calendar_events');
    with ranked as (
      select id, row_number() over(order by coalesce(start_date,end_date) desc nulls last,id desc) n
      from public.calendar_events where lower(trim(account)) = target_email
    ) delete from public.calendar_events e using ranked r
      where e.id=r.id and r.n>resource_limit;
    get diagnostics affected=row_count;
    deleted_counts:=jsonb_set(deleted_counts,'{calendar_events}',to_jsonb(affected));

    resource_limit := public.life_pilot_user_cloud_limit(target_id, 'memory_trace');
    with ranked as (
      select id,row_number() over(order by coalesce(start_date,end_date) desc nulls last,id desc) n
      from public.memory_trace where lower(trim(account))=target_email
    ) delete from public.memory_trace m using ranked r where m.id=r.id and r.n>resource_limit;
    get diagnostics affected=row_count;
    deleted_counts:=jsonb_set(deleted_counts,'{memory_trace}',to_jsonb(affected));

    resource_limit:=public.life_pilot_user_cloud_limit(target_id,'accounting_detail');
    select count(*) into reserved_count from public.accounting_detail d
      join public.accounting_account a on a.id=d.account_id
      where lower(trim(a.created_by))=target_email and d.primary_category='reserved';
    keep_regular:=greatest(resource_limit-reserved_count,0);
    with ranked as (
      select d.id,row_number() over(order by d.date desc nulls last,d.created_at desc,d.id desc) n
      from public.accounting_detail d join public.accounting_account a on a.id=d.account_id
      where lower(trim(a.created_by))=target_email and d.primary_category<>'reserved'
    ) delete from public.accounting_detail d using ranked r where d.id=r.id and r.n>keep_regular;
    get diagnostics affected=row_count;
    deleted_counts:=jsonb_set(deleted_counts,'{accounting_detail}',to_jsonb(affected));

    resource_limit:=public.life_pilot_user_cloud_limit(target_id,'point_record_detail');
    select count(*) into reserved_count from public.point_record_detail d
      join public.point_record_account a on a.id=d.account_id
      where lower(trim(a.created_by))=target_email and d.primary_category='reserved';
    keep_regular:=greatest(resource_limit-reserved_count,0);
    with ranked as (
      select d.id,row_number() over(order by d.date desc nulls last,d.created_at desc,d.id desc) n
      from public.point_record_detail d join public.point_record_account a on a.id=d.account_id
      where lower(trim(a.created_by))=target_email and d.primary_category<>'reserved'
    ) delete from public.point_record_detail d using ranked r where d.id=r.id and r.n>keep_regular;
    get diagnostics affected=row_count;
    deleted_counts:=jsonb_set(deleted_counts,'{point_record_detail}',to_jsonb(affected));

    resource_limit:=public.life_pilot_user_cloud_limit(target_id,'game_questions');
    for candidate in
      with q as (
        select 'game_grammar' t,id,created_at from public.game_grammar where owner_id=target_id
        union all select 'game_sentence',id,created_at from public.game_sentence where owner_id=target_id
        union all select 'game_translation',id,created_at from public.game_translation where owner_id=target_id
        union all select 'game_social_scenarios',id,created_at from public.game_social_scenarios where owner_id=target_id
      ) select t,id from q order by created_at desc nulls last,id desc offset resource_limit
    loop
      if candidate.t='game_grammar' then delete from public.game_grammar_user where question_id=candidate.id; delete from public.game_grammar where id=candidate.id;
      elsif candidate.t='game_sentence' then delete from public.game_sentence_user where question_id=candidate.id; delete from public.game_speaking_user where question_id=candidate.id; delete from public.game_sentence where id=candidate.id;
      elsif candidate.t='game_translation' then delete from public.game_translation_user where question_id=candidate.id; delete from public.game_word_search_user where question_id=candidate.id; delete from public.game_translation where id=candidate.id;
      else delete from public.game_social_user where question_id::text=candidate.id::text; delete from public.game_social_scenarios where id=candidate.id;
      end if;
      affected:=coalesce((deleted_counts->>'game_questions')::integer,0)+1;
      deleted_counts:=jsonb_set(deleted_counts,'{game_questions}',to_jsonb(affected));
    end loop;

    resource_limit:=public.life_pilot_user_cloud_limit(target_id,'calendar_shares');
    with excess as (
      select id from public.calendar_share_invitations
      where lower(trim(shared_by))=target_email and status in ('pending','accepted')
      order by created_at desc nulls last,id desc offset resource_limit
    ) update public.calendar_share_invitations i set status='revoked'
      from excess e where i.id=e.id;
    get diagnostics affected=row_count;
    deleted_counts:=jsonb_set(deleted_counts,'{calendar_shares}',to_jsonb(affected));

    update public.accounting_account a set balance=coalesce((select sum(d.value)
      from public.accounting_detail d where d.account_id=a.id and d.type='balance'
      and d.currency=a.main_currency),0) where lower(trim(a.created_by))=target_email;
    update public.point_record_account a set points=coalesce((select sum(d.value)
      from public.point_record_detail d where d.account_id=a.id and d.type='points'),0)
      where lower(trim(a.created_by))=target_email;
  end if;

  insert into public.subscription_cleanup_audit(user_id,reason,deleted_counts)
    values(target_id,case when p_mode='all' then 'manual_all' else 'manual_excess' end,deleted_counts);
  return jsonb_build_object('target_email',target_email,'mode',p_mode,'deleted',deleted_counts);
end;
$function$;

revoke all on function public.cleanup_subscription_data(text,text) from public,anon;
grant execute on function public.cleanup_subscription_data(text,text) to authenticated,service_role;

commit;
