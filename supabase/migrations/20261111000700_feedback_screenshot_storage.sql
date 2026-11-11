begin;
alter table public.feedback add column if not exists screenshot_paths text[] not null default '{}';

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('feedback-screenshots','feedback-screenshots',false,5242880,array['image/png','image/jpeg','image/webp'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists life_pilot_feedback_screenshot_insert on storage.objects;
create policy life_pilot_feedback_screenshot_insert on storage.objects
for insert to authenticated with check(
  bucket_id='feedback-screenshots'
  and (storage.foldername(name))[1]=auth.uid()::text
);
grant select(screenshot_paths) on table public.feedback to authenticated,service_role;
drop policy if exists life_pilot_feedback_screenshot_select on storage.objects;
create policy life_pilot_feedback_screenshot_select on storage.objects
for select to authenticated using(
  bucket_id='feedback-screenshots'
  and ((storage.foldername(name))[1]=auth.uid()::text or public.life_pilot_is_admin())
);
drop policy if exists life_pilot_feedback_screenshot_delete on storage.objects;
create policy life_pilot_feedback_screenshot_delete on storage.objects
for delete to authenticated using(
  bucket_id='feedback-screenshots'
  and ((storage.foldername(name))[1]=auth.uid()::text or public.life_pilot_is_admin())
);

-- Keep the existing restrictive upload gate, while admitting this private
-- bucket only under the signed-in user's own folder.
drop policy if exists life_pilot_storage_insert_gate on storage.objects;
create policy life_pilot_storage_insert_gate on storage.objects
as restrictive for insert to public with check(
  case
    when auth.uid() is null then false
    when bucket_id='account-images' then true
    when bucket_id='models' then public.life_pilot_is_admin()
    when bucket_id='feedback-screenshots' then
      (storage.foldername(name))[1]=auth.uid()::text
    else false
  end
);
commit;
