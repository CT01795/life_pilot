begin;

create or replace function public.get_business_plan_detail(p_plan_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $function$
  select jsonb_build_object(
    'id', p.id,
    'title', p.title,
    'status', p.status,
    'created_at', p.created_at,
    'sections', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', s.id,
            'title', s.title,
            'sort_order', s.sort_order,
            'questions', coalesce(
              (
                select jsonb_agg(
                  jsonb_build_object(
                    'id', q.id,
                    'prompt', q.prompt,
                    'sort_order', q.sort_order,
                    'answer', a.answer
                  )
                  order by q.sort_order
                )
                from public.business_plan_question q
                left join public.business_plan_answer a
                  on a.question_id = q.id
                 and a.plan_id = p_plan_id
                where q.section_id = s.id
              ),
              '[]'::jsonb
            )
          )
          order by s.sort_order
        )
        from public.business_plan_section s
        where s.plan_id = p.id
      ),
      '[]'::jsonb
    )
  )
  from public.business_plan p
  where p.id = p_plan_id;
$function$;

revoke all on function public.get_business_plan_detail(uuid)
  from public, anon;
grant execute on function public.get_business_plan_detail(uuid)
  to authenticated;

commit;
