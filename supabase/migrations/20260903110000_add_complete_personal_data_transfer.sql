begin;

drop function if exists public.restore_local_personal_record_admin(text, jsonb);

create or replace function public.export_my_cloud_data_for_local()
returns table(table_name text, record jsonb)
language sql
stable
security definer
set search_path = ''
as $function$
  select 'calendar_events', to_jsonb(t) from public.calendar_events t
    where lower(trim(t.account)) = public.life_pilot_user_email()
  union all select 'memory_trace', to_jsonb(t) from public.memory_trace t
    where lower(trim(t.account)) = public.life_pilot_user_email()
  union all select 'accounting_account', to_jsonb(t) from public.accounting_account t
    where lower(trim(t.created_by)) = public.life_pilot_user_email()
  union all select 'accounting_detail', to_jsonb(d)
    from public.accounting_detail d join public.accounting_account a on a.id = d.account_id
    where lower(trim(a.created_by)) = public.life_pilot_user_email()
  union all select 'point_record_account', to_jsonb(t) from public.point_record_account t
    where lower(trim(t.created_by)) = public.life_pilot_user_email()
  union all select 'point_record_detail', to_jsonb(d)
    from public.point_record_detail d join public.point_record_account a on a.id = d.account_id
    where lower(trim(a.created_by)) = public.life_pilot_user_email()
  union all select 'game_grammar', to_jsonb(t) from public.game_grammar t where t.owner_id = auth.uid()
  union all select 'game_sentence', to_jsonb(t) from public.game_sentence t where t.owner_id = auth.uid()
  union all select 'game_translation', to_jsonb(t) from public.game_translation t where t.owner_id = auth.uid()
  union all select 'game_social_scenarios', to_jsonb(t) || jsonb_build_object(
      'choices', coalesce((select jsonb_agg(to_jsonb(c) order by c.created_at, c.id)
        from public.game_social_choices c where c.scenario_id = t.id), '[]'::jsonb))
    from public.game_social_scenarios t where t.owner_id = auth.uid()
  union all select 'game_grammar_user', to_jsonb(t) from public.game_grammar_user t where t.owner_id = auth.uid()
  union all select 'game_sentence_user', to_jsonb(t) from public.game_sentence_user t where t.owner_id = auth.uid()
  union all select 'game_speaking_user', to_jsonb(t) from public.game_speaking_user t where t.owner_id = auth.uid()
  union all select 'game_social_user', to_jsonb(t) from public.game_social_user t where t.owner_id = auth.uid()
  union all select 'game_translation_user', to_jsonb(t) from public.game_translation_user t where t.owner_id = auth.uid()
  union all select 'game_word_search_user', to_jsonb(t) from public.game_word_search_user t where t.owner_id = auth.uid()
  union all select 'game_user', to_jsonb(t) from public.game_user t where t.owner_id = auth.uid();
$function$;

create or replace function public.delete_cloud_records_after_local_copy(p_records jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare deleted_count integer := 0; affected integer; resource_name text;
begin
  if auth.uid() is null or jsonb_typeof(p_records) <> 'array' then
    raise exception 'invalid_local_move_payload';
  end if;
  if exists (select 1 from jsonb_array_elements(p_records) x
      where x ->> 'table_name' not in (
        'calendar_events','memory_trace','accounting_account','accounting_detail',
        'point_record_account','point_record_detail','game_grammar','game_sentence',
        'game_translation','game_social_scenarios','game_grammar_user',
        'game_sentence_user','game_speaking_user','game_social_user',
        'game_translation_user','game_word_search_user','game_user')) then
    raise exception 'unsupported_local_resource';
  end if;

  delete from public.game_grammar_user t where t.owner_id = auth.uid() and t.id::text in
    (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='game_grammar_user');
  get diagnostics affected=row_count; deleted_count:=deleted_count+affected;
  delete from public.game_sentence_user t where t.owner_id = auth.uid() and t.id::text in
    (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='game_sentence_user');
  get diagnostics affected=row_count; deleted_count:=deleted_count+affected;
  delete from public.game_speaking_user t where t.owner_id = auth.uid() and t.id::text in
    (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='game_speaking_user');
  get diagnostics affected=row_count; deleted_count:=deleted_count+affected;
  delete from public.game_social_user t where t.owner_id = auth.uid() and t.id::text in
    (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='game_social_user');
  get diagnostics affected=row_count; deleted_count:=deleted_count+affected;
  delete from public.game_translation_user t where t.owner_id = auth.uid() and t.id::text in
    (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='game_translation_user');
  get diagnostics affected=row_count; deleted_count:=deleted_count+affected;
  delete from public.game_word_search_user t where t.owner_id = auth.uid() and t.id::text in
    (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='game_word_search_user');
  get diagnostics affected=row_count; deleted_count:=deleted_count+affected;

  delete from public.accounting_detail d using public.accounting_account a
    where d.account_id=a.id and lower(trim(a.created_by))=public.life_pilot_user_email()
      and d.id::text in (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='accounting_detail');
  get diagnostics affected=row_count; deleted_count:=deleted_count+affected;
  delete from public.point_record_detail d using public.point_record_account a
    where d.account_id=a.id and lower(trim(a.created_by))=public.life_pilot_user_email()
      and d.id::text in (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='point_record_detail');
  get diagnostics affected=row_count; deleted_count:=deleted_count+affected;

  delete from public.game_grammar t where t.owner_id=auth.uid() and t.id::text in
    (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='game_grammar');
  get diagnostics affected=row_count; deleted_count:=deleted_count+affected;
  delete from public.game_sentence t where t.owner_id=auth.uid() and t.id::text in
    (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='game_sentence');
  get diagnostics affected=row_count; deleted_count:=deleted_count+affected;
  delete from public.game_translation t where t.owner_id=auth.uid() and t.id::text in
    (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='game_translation');
  get diagnostics affected=row_count; deleted_count:=deleted_count+affected;
  delete from public.game_social_scenarios t where t.owner_id=auth.uid() and t.id::text in
    (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='game_social_scenarios');
  get diagnostics affected=row_count; deleted_count:=deleted_count+affected;
  delete from public.game_user t where t.owner_id=auth.uid() and t.id::text in
    (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='game_user');
  get diagnostics affected=row_count; deleted_count:=deleted_count+affected;

  update public.dashboard_setting set
    accounting_account_id = null, accounting_account_name = null
  where accounting_account_id::text in
    (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='accounting_account');
  update public.dashboard_setting set
    point_account_id = null, point_account_name = null
  where point_account_id::text in
    (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='point_record_account');
  delete from public.accounting_balance_by_currency b
  where b.account_id::text in
    (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='accounting_account');

  delete from public.accounting_account t where lower(trim(t.created_by))=public.life_pilot_user_email()
    and t.id::text in (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='accounting_account');
  get diagnostics affected=row_count; deleted_count:=deleted_count+affected;
  delete from public.point_record_account t where lower(trim(t.created_by))=public.life_pilot_user_email()
    and t.id::text in (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='point_record_account');
  get diagnostics affected=row_count; deleted_count:=deleted_count+affected;
  delete from public.calendar_events t where lower(trim(t.account))=public.life_pilot_user_email()
    and t.id::text in (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='calendar_events');
  get diagnostics affected=row_count; deleted_count:=deleted_count+affected;
  delete from public.memory_trace t where lower(trim(t.account))=public.life_pilot_user_email()
    and t.id::text in (select x->>'id' from jsonb_array_elements(p_records) x where x->>'table_name'='memory_trace');
  get diagnostics affected=row_count; deleted_count:=deleted_count+affected;

  if deleted_count <> jsonb_array_length(p_records) then
    raise exception 'cloud_delete_count_mismatch:%:%', deleted_count, jsonb_array_length(p_records);
  end if;
  return deleted_count;
end;
$function$;

create or replace function public.restore_local_personal_records_admin(p_records jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare item jsonb; r jsonb; resource_name text; incoming_count bigint;
  used_count bigint; quota_count bigint; restored_count integer := 0;
begin
  if auth.uid() is null or jsonb_typeof(p_records) <> 'array' then
    raise exception 'invalid_local_upload_payload';
  end if;
  if exists (select 1 from jsonb_array_elements(p_records) x
      where x ->> 'table_name' not in (
        'calendar_events','memory_trace','accounting_account','accounting_detail',
        'point_record_account','point_record_detail','game_grammar','game_sentence',
        'game_translation','game_social_scenarios','game_grammar_user',
        'game_sentence_user','game_speaking_user','game_social_user',
        'game_translation_user','game_word_search_user','game_user')) then
    raise exception 'unsupported_local_resource';
  end if;

  for resource_name in select unnest(array[
    'calendar_events','memory_trace','accounting_detail','point_record_detail']) loop
    select count(*) into incoming_count from jsonb_array_elements(p_records) x
      where x->>'table_name'=resource_name;
    used_count := public.life_pilot_my_usage(resource_name);
    quota_count := public.life_pilot_plan_limit(resource_name);
    if used_count + incoming_count > quota_count then
      raise exception 'local_upload_quota_exceeded:%:%:%:%',
        resource_name, used_count, incoming_count, quota_count;
    end if;
  end loop;
  select count(*) into incoming_count from jsonb_array_elements(p_records) x
    where x->>'table_name' in ('game_grammar','game_sentence','game_translation','game_social_scenarios');
  used_count := public.life_pilot_my_usage('game_questions');
  quota_count := public.life_pilot_plan_limit('game_questions');
  if used_count + incoming_count > quota_count then
    raise exception 'local_upload_quota_exceeded:game_questions:%:%:%', used_count, incoming_count, quota_count;
  end if;

  for item in select value from jsonb_array_elements(p_records) x
    where x.value->>'table_name' in ('accounting_account','point_record_account')
    order by case x.value->>'table_name' when 'accounting_account' then 1 else 2 end loop
    r := item->'record';
    if lower(trim(coalesce(r->>'created_by',''))) <> public.life_pilot_user_email() then raise exception 'local_upload_owner_mismatch'; end if;
    if item->>'table_name'='accounting_account' then
      insert into public.accounting_account select * from jsonb_populate_record(null::public.accounting_account,r);
    else
      insert into public.point_record_account select * from jsonb_populate_record(null::public.point_record_account,r);
    end if;
    restored_count:=restored_count+1;
  end loop;

  for item in select value from jsonb_array_elements(p_records) x
    where x.value->>'table_name' in ('calendar_events','memory_trace','game_grammar','game_sentence','game_translation','game_social_scenarios') loop
    r:=item->'record'; resource_name:=item->>'table_name';
    if resource_name in ('calendar_events','memory_trace') and lower(trim(coalesce(r->>'account','')))<>public.life_pilot_user_email() then raise exception 'local_upload_owner_mismatch'; end if;
    if resource_name like 'game_%' and coalesce(r->>'owner_id','')<>auth.uid()::text then raise exception 'local_upload_owner_mismatch'; end if;
    case resource_name
      when 'calendar_events' then insert into public.calendar_events select * from jsonb_populate_record(null::public.calendar_events,r);
      when 'memory_trace' then insert into public.memory_trace select * from jsonb_populate_record(null::public.memory_trace,r);
      when 'game_grammar' then insert into public.game_grammar select * from jsonb_populate_record(null::public.game_grammar,r);
      when 'game_sentence' then insert into public.game_sentence select * from jsonb_populate_record(null::public.game_sentence,r);
      when 'game_translation' then insert into public.game_translation select * from jsonb_populate_record(null::public.game_translation,r);
      when 'game_social_scenarios' then
        insert into public.game_social_scenarios select * from jsonb_populate_record(null::public.game_social_scenarios,r - 'choices');
        insert into public.game_social_choices
          select * from jsonb_populate_recordset(null::public.game_social_choices,coalesce(r->'choices','[]'::jsonb));
    end case;
    restored_count:=restored_count+1;
  end loop;

  for item in select value from jsonb_array_elements(p_records) x
    where x.value->>'table_name' in ('accounting_detail','point_record_detail','game_grammar_user','game_sentence_user','game_speaking_user','game_social_user','game_translation_user','game_word_search_user','game_user') loop
    r:=item->'record'; resource_name:=item->>'table_name';
    if resource_name like 'game_%' and coalesce(r->>'owner_id','')<>auth.uid()::text then raise exception 'local_upload_owner_mismatch'; end if;
    case resource_name
      when 'accounting_detail' then
        if not exists(select 1 from public.accounting_account a where a.id::text=r->>'account_id' and lower(trim(a.created_by))=public.life_pilot_user_email()) then raise exception 'local_upload_owner_mismatch'; end if;
        insert into public.accounting_detail select * from jsonb_populate_record(null::public.accounting_detail,r);
      when 'point_record_detail' then
        if not exists(select 1 from public.point_record_account a where a.id::text=r->>'account_id' and lower(trim(a.created_by))=public.life_pilot_user_email()) then raise exception 'local_upload_owner_mismatch'; end if;
        insert into public.point_record_detail select * from jsonb_populate_record(null::public.point_record_detail,r);
      when 'game_grammar_user' then insert into public.game_grammar_user select * from jsonb_populate_record(null::public.game_grammar_user,r);
      when 'game_sentence_user' then insert into public.game_sentence_user select * from jsonb_populate_record(null::public.game_sentence_user,r);
      when 'game_speaking_user' then insert into public.game_speaking_user select * from jsonb_populate_record(null::public.game_speaking_user,r);
      when 'game_social_user' then insert into public.game_social_user select * from jsonb_populate_record(null::public.game_social_user,r);
      when 'game_translation_user' then insert into public.game_translation_user select * from jsonb_populate_record(null::public.game_translation_user,r);
      when 'game_word_search_user' then insert into public.game_word_search_user select * from jsonb_populate_record(null::public.game_word_search_user,r);
      when 'game_user' then insert into public.game_user select * from jsonb_populate_record(null::public.game_user,r);
    end case;
    restored_count:=restored_count+1;
  end loop;
  return restored_count;
end;
$function$;

revoke all on function public.export_my_cloud_data_for_local() from public, anon;
grant execute on function public.export_my_cloud_data_for_local() to authenticated;
revoke all on function public.delete_cloud_records_after_local_copy(jsonb) from public, anon;
grant execute on function public.delete_cloud_records_after_local_copy(jsonb) to authenticated;
revoke all on function public.restore_local_personal_records_admin(jsonb) from public, anon;
grant execute on function public.restore_local_personal_records_admin(jsonb) to authenticated;

commit;
