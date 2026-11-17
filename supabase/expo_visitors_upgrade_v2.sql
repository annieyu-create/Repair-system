-- =============================================================
-- 國外展覽訪客登錄｜升級 SQL（v1 → v2）
-- 只有「已經執行過舊版 expo_visitors.sql」才需要執行本檔；
-- 尚未建表的話，直接執行新版 expo_visitors.sql 即可。
-- 變更：有興趣的品項改為產品類別複選、新增「其他品項說明」「登錄人員」、
--       手機可自帶 id（離線重送不重複）、新增匯出帳號清單與讀取權限。
-- =============================================================

begin;

alter table public.expo_visitors
  drop constraint if exists expo_visitors_interested_items_len;

-- 舊版自由填寫的品項內容移到「其他品項說明」，並勾選 Others
alter table public.expo_visitors add column interested_other text
  constraint expo_visitors_interested_other_len
  check (interested_other is null or char_length(interested_other) <= 200);
update public.expo_visitors
  set interested_other = left(interested_items, 200)
  where interested_items is not null;

alter table public.expo_visitors
  alter column interested_items type text[]
    using case when interested_items is null then '{}'::text[] else array['Others'] end,
  alter column interested_items set default '{}',
  alter column interested_items set not null,
  add constraint expo_visitors_interested_items_valid
    check (interested_items <@ array[
      'Scaffolding Accessories', 'Ring System Scaffolding',
      'Formwork Accessories', 'System Formwork', 'Others'
    ]::text[]);

alter table public.expo_visitors add column staff_name text
  constraint expo_visitors_staff_name_len
  check (staff_name is null or char_length(staff_name) <= 50);

create table public.expo_admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);
comment on table public.expo_admins is '可讀取與匯出展覽訪客名單的帳號';

revoke all on table public.expo_visitors from public, anon, authenticated;
revoke all on table public.expo_admins from public, anon, authenticated;
grant usage on schema public to anon, authenticated;
grant insert (id, company_name, country, contact_name, phone, website,
              company_type, interested_items, interested_other, discussion, staff_name)
  on table public.expo_visitors to anon;
grant select on table public.expo_visitors to authenticated;
grant select on table public.expo_admins to authenticated;

alter table public.expo_admins enable row level security;

create policy "匯出帳號可讀取展覽訪客"
  on public.expo_visitors
  for select
  to authenticated
  using (exists (select 1 from public.expo_admins a where a.user_id = auth.uid()));

create policy "登入者可查看自己的匯出權限"
  on public.expo_admins
  for select
  to authenticated
  using (user_id = auth.uid());

commit;
