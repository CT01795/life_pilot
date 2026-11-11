begin;
create or replace function public.get_my_game_progress_window(
  p_game_type text, p_game_name text, p_from timestamptz,
  p_until timestamptz, p_include_latest boolean default false
) returns jsonb language sql stable security invoker set search_path='' as $$
  with matching as materialized (
    select gu.id,gu.name,gu.game_id,gu.score,gu.created_at,gu.is_pass,
           gl.game_type,gl.game_name,gl.level
    from public.game_user gu join public.game_list gl on gl.id=gu.game_id
    where gu.owner_id=auth.uid() and gl.game_type=p_game_type and gl.game_name=p_game_name
  ), page as (
    select * from matching where created_at>=p_from and created_at<p_until
    order by created_at desc
  ), fallback as (
    select * from matching where p_include_latest and not exists(select 1 from page)
    order by created_at desc limit 1
  ), shown as (select * from page union all select * from fallback),
  boundary as (select least(p_from,(select created_at from fallback)) value)
  select jsonb_build_object(
    'highest_passed_level',coalesce((select max(level) from matching where is_pass),0),
    'rows',coalesce((select jsonb_agg(to_jsonb(s) order by created_at desc) from shown s),'[]'::jsonb),
    'next_date',(select max(created_at) from matching where created_at<(select value from boundary))
  );
$$;
revoke all on function public.get_my_game_progress_window(text,text,timestamptz,timestamptz,boolean) from public,anon;
grant execute on function public.get_my_game_progress_window(text,text,timestamptz,timestamptz,boolean) to authenticated,service_role;
notify pgrst,'reload schema';
commit;
