begin;

create or replace function public.get_feedback_summary_page(
  p_statuses text[],
  p_before_created_at timestamptz default null,
  p_before_id bigint default null,
  p_limit integer default 51
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(to_jsonb(page_rows) order by page_rows.created_at desc nulls last, page_rows.id desc), '[]'::jsonb)
  from (
    select
      f.id,
      f.subject,
      left(coalesce(f.content, ''), 240) as content,
      false as content_loaded,
      f.created_by,
      f.created_at,
      f.is_ok,
      f.deal_by,
      f.deal_at,
      f.status
    from public.feedback f
    where case
      when f.status is not null then f.status = any(p_statuses)
      when f.is_ok is true then 'completed' = any(p_statuses)
      else 'pending' = any(p_statuses)
    end
      and (
        p_before_id is null
        or (p_before_created_at is null and f.created_at is null and f.id < p_before_id)
        or (p_before_created_at is not null and (
          f.created_at < p_before_created_at
          or (f.created_at = p_before_created_at and f.id < p_before_id)
          or f.created_at is null
        ))
      )
    order by f.created_at desc nulls last, f.id desc
    limit least(greatest(coalesce(p_limit, 51), 1), 101)
  ) page_rows;
$$;

revoke all on function public.get_feedback_summary_page(text[],timestamptz,bigint,integer) from public, anon;
grant execute on function public.get_feedback_summary_page(text[],timestamptz,bigint,integer) to authenticated, service_role;

notify pgrst, 'reload schema';
commit;
