begin;

alter table public.accounting_detail
  drop constraint if exists accounting_detail_primary_category_check;
alter table public.accounting_detail
  add constraint accounting_detail_primary_category_check check (
    primary_category in (
      'uncategorized', 'reserved', 'food', 'clothing', 'housing',
      'transportation', 'education', 'entertainment'
    )
  );

alter table public.point_record_detail
  drop constraint if exists point_record_detail_primary_category_check;
alter table public.point_record_detail
  add constraint point_record_detail_primary_category_check check (
    primary_category in (
      'uncategorized', 'reserved', 'virtue', 'intelligence',
      'fitness', 'social', 'arts'
    )
  );

update public.accounting_detail
set primary_category = 'reserved'
where description ilike '%餘%'
  and primary_category is distinct from 'reserved';

create index if not exists accounting_detail_account_type_date_idx
  on public.accounting_detail (account_id, type, date desc);
create index if not exists point_record_detail_account_type_date_idx
  on public.point_record_detail (account_id, type, date desc);
create index if not exists game_user_owner_created_game_idx
  on public.game_user (owner_id, created_at desc, game_id);

commit;
