begin;

create or replace function public.get_my_question_management_page(
  p_table_name text,
  p_game_name text,
  p_keyword text default '',
  p_group text default null,
  p_status text default 'all',
  p_offset integer default 0,
  p_limit integer default 20
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'rows', coalesce((
      select jsonb_agg(
        to_jsonb(page_row) - 'ordinality'
        order by page_row.ordinality
      )
      from public.get_my_questions_page(
        p_table_name,
        p_game_name,
        p_keyword,
        p_group,
        p_status,
        p_offset,
        p_limit
      ) with ordinality as page_row(
        id,
        question,
        answer,
        question_group,
        level,
        is_active,
        options,
        total_count,
        ordinality
      )
    ), '[]'::jsonb),
    'groups', coalesce((
      select jsonb_agg(group_row.question_group order by group_row.question_group)
      from public.get_my_question_groups_for_management(p_table_name) group_row
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.get_my_question_management_page(
  text, text, text, text, text, integer, integer
) from public, anon;
grant execute on function public.get_my_question_management_page(
  text, text, text, text, text, integer, integer
) to authenticated, service_role;

notify pgrst, 'reload schema';

commit;
