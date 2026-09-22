begin;

create or replace function public.get_user_game_highest_passed_level(
  p_game_type text,
  p_game_name text
)
returns integer
language sql
stable
security invoker
set search_path = ''
as $function$
  select coalesce(max(gl.level), 0)::integer
  from public.game_user gu
  join public.game_list gl on gl.id = gu.game_id
  where gu.owner_id = auth.uid()
    and gu.is_pass is true
    and gl.game_type = p_game_type
    and gl.game_name = p_game_name;
$function$;

revoke all on function public.get_user_game_highest_passed_level(text, text)
from public, anon;
grant execute on function public.get_user_game_highest_passed_level(text, text)
to authenticated;

commit;
