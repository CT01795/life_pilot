create or replace function public.get_question_bank_group_counts(
  p_table_name text,
  p_level bigint,
  p_question_bank text default 'mine'
)
returns table(question_group text, question_count bigint)
language plpgsql
stable
set search_path = ''
as $function$
declare
  target_owner uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  if p_table_name not in ('game_grammar', 'game_sentence', 'game_translation') then
    raise exception 'unsupported_question_table';
  end if;

  if p_question_bank not in ('admin', 'mine') then
    raise exception 'unsupported_question_bank';
  end if;

  target_owner := case
    when p_question_bank = 'admin'
      then 'cd55646b-7924-4413-9cd0-b75de0b9f605'::uuid
    else auth.uid()
  end;

  return query execute format(
    'select coalesce("group", ''''), count(*)::bigint
       from public.%I
      where owner_id = $1
        and is_active = true
        and coalesce(level, 1) <= $2
      group by coalesce("group", '''')',
    p_table_name
  ) using target_owner, p_level;
end;
$function$;

revoke all on function public.get_question_bank_group_counts(text, bigint, text)
  from public, anon;
grant execute on function public.get_question_bank_group_counts(text, bigint, text)
  to authenticated;
