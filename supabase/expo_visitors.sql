-- =============================================================
-- 國外展覽訪客登錄｜Supabase 建表／升級 SQL
-- （與 expo_visitors_setup.sql 內容相同，兩個檔案擇一執行即可）
-- 不論目前是「還沒建表」「第一版」「第二版」或「已是最新版」，
-- 都可以直接整段執行；會自動補齊缺少的部分，重複執行也不會出錯。
-- 執行後資料表即為最新版：編號、日期、訪客性質、產品類別複選、登錄人員、匯出帳號。
-- =============================================================

begin;

-- -------------------------------------------------------------
-- 1. 還沒建表時，直接建立最新版資料表
-- -------------------------------------------------------------
create table if not exists public.expo_visitors (
  id uuid primary key default gen_random_uuid(),
  visitor_no bigint generated always as identity unique,
  visit_date date not null default current_date,
  created_at timestamptz not null default now(),
  company_name text not null
    constraint expo_visitors_company_name_len
    check (char_length(btrim(company_name)) between 1 and 100),
  country text not null
    constraint expo_visitors_country_len
    check (char_length(btrim(country)) between 1 and 50),
  contact_name text not null
    constraint expo_visitors_contact_name_len
    check (char_length(btrim(contact_name)) between 1 and 50),
  phone text
    constraint expo_visitors_phone_len
    check (phone is null or char_length(phone) <= 30),
  website text
    constraint expo_visitors_website_len
    check (website is null or char_length(website) <= 200),
  visitor_type text not null
    constraint expo_visitors_visitor_type_valid
    check (visitor_type in ('採購', '經銷商', '鷹架公司', '模板公司')),
  interested_items text[] not null default '{}'
    constraint expo_visitors_interested_items_valid
    check (interested_items <@ array[
      'Scaffolding Accessories', 'Ring System Scaffolding',
      'Formwork Accessories', 'System Formwork', 'Others'
    ]::text[]),
  interested_other text
    constraint expo_visitors_interested_other_len
    check (interested_other is null or char_length(interested_other) <= 200),
  discussion text
    constraint expo_visitors_discussion_len
    check (discussion is null or char_length(discussion) <= 2000),
  staff_name text
    constraint expo_visitors_staff_name_len
    check (staff_name is null or char_length(staff_name) <= 50)
);

comment on table public.expo_visitors is '國外展覽訪客登錄（示範用，內容皆為虛構）';

-- -------------------------------------------------------------
-- 2. 舊版資料表：補上缺少的欄位
-- -------------------------------------------------------------

-- 其他品項說明、登錄人員（第一版沒有）
alter table public.expo_visitors add column if not exists interested_other text
  constraint expo_visitors_interested_other_len
  check (interested_other is null or char_length(interested_other) <= 200);
alter table public.expo_visitors add column if not exists staff_name text
  constraint expo_visitors_staff_name_len
  check (staff_name is null or char_length(staff_name) <= 50);

-- 有興趣的品項：第一版是自由文字，改為產品類別複選；
-- 舊的文字內容移到「其他品項說明」，並勾選 Others
do $$
begin
  if (select data_type from information_schema.columns
      where table_schema = 'public' and table_name = 'expo_visitors'
        and column_name = 'interested_items') = 'text' then
    alter table public.expo_visitors drop constraint if exists expo_visitors_interested_items_len;
    update public.expo_visitors
      set interested_other = coalesce(interested_other, left(interested_items, 200))
      where interested_items is not null;
    alter table public.expo_visitors
      alter column interested_items type text[]
        using case when interested_items is null then '{}'::text[] else array['Others'] end;
    alter table public.expo_visitors
      alter column interested_items set default '{}',
      alter column interested_items set not null,
      add constraint expo_visitors_interested_items_valid
        check (interested_items <@ array[
          'Scaffolding Accessories', 'Ring System Scaffolding',
          'Formwork Accessories', 'System Formwork', 'Others'
        ]::text[]);
  end if;
end $$;

-- 日期：舊資料以登錄時間（台灣時間）的日期補上
alter table public.expo_visitors add column if not exists visit_date date;
update public.expo_visitors
  set visit_date = (created_at at time zone 'Asia/Taipei')::date
  where visit_date is null;
alter table public.expo_visitors
  alter column visit_date set default current_date,
  alter column visit_date set not null;

-- 編號：舊資料依登錄時間先後編 1、2、3…，之後新增的接續往下編
do $$
declare next_no bigint;
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'expo_visitors'
                   and column_name = 'visitor_no') then
    alter table public.expo_visitors add column visitor_no bigint;
    update public.expo_visitors v
      set visitor_no = n.rn
      from (select id, row_number() over (order by created_at, id) as rn
            from public.expo_visitors) n
      where v.id = n.id;
    alter table public.expo_visitors
      alter column visitor_no set not null,
      add constraint expo_visitors_visitor_no_key unique (visitor_no);
    select coalesce(max(visitor_no), 0) + 1 into next_no from public.expo_visitors;
    execute format(
      'alter table public.expo_visitors alter column visitor_no add generated always as identity (start with %s)',
      next_no);
  end if;
end $$;

-- 公司性質 → 訪客性質
-- 舊的「經銷商／代理商」改為「經銷商」；其他舊選項保留原值，
-- 新規則只檢查之後新增的資料（not valid），請到後台手動改成新選項。
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'expo_visitors'
               and column_name = 'company_type') then
    alter table public.expo_visitors rename column company_type to visitor_type;
    alter table public.expo_visitors drop constraint if exists expo_visitors_company_type_valid;
    update public.expo_visitors set visitor_type = '經銷商' where visitor_type = '經銷商／代理商';
  end if;
  if not exists (select 1 from pg_constraint
                 where conname = 'expo_visitors_visitor_type_valid'
                   and conrelid = 'public.expo_visitors'::regclass) then
    alter table public.expo_visitors
      add constraint expo_visitors_visitor_type_valid
      check (visitor_type in ('採購', '經銷商', '鷹架公司', '模板公司')) not valid;
  end if;
end $$;

create index if not exists expo_visitors_created_at_idx
  on public.expo_visitors (created_at desc);
create index if not exists expo_visitors_visit_date_idx
  on public.expo_visitors (visit_date);

-- -------------------------------------------------------------
-- 3. 可匯出名單的帳號清單
-- -------------------------------------------------------------
create table if not exists public.expo_admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);
comment on table public.expo_admins is '可讀取與匯出展覽訪客名單的帳號';

-- -------------------------------------------------------------
-- 4. 權限（每次都重設為正確狀態）
-- -------------------------------------------------------------
revoke all on table public.expo_visitors from public, anon, authenticated;
revoke all on table public.expo_admins from public, anon, authenticated;
grant usage on schema public to anon, authenticated;

-- 手機（anon）：只能新增使用者要填的欄位與手機產生的 id
grant insert (id, visit_date, company_name, country, contact_name, phone, website,
              visitor_type, interested_items, interested_other, discussion, staff_name)
  on table public.expo_visitors to anon;

-- 登入的帳號：可讀取（實際能否讀到由 RLS 決定）
grant select on table public.expo_visitors to authenticated;
grant select on table public.expo_admins to authenticated;

-- -------------------------------------------------------------
-- 5. RLS（政策先刪再建，確保內容是最新的）
-- -------------------------------------------------------------
alter table public.expo_visitors enable row level security;
alter table public.expo_admins enable row level security;

drop policy if exists "anon 可新增展覽訪客" on public.expo_visitors;
create policy "anon 可新增展覽訪客"
  on public.expo_visitors
  for insert
  to anon
  with check (true);

drop policy if exists "匯出帳號可讀取展覽訪客" on public.expo_visitors;
create policy "匯出帳號可讀取展覽訪客"
  on public.expo_visitors
  for select
  to authenticated
  using (exists (select 1 from public.expo_admins a where a.user_id = auth.uid()));

drop policy if exists "登入者可查看自己的匯出權限" on public.expo_admins;
create policy "登入者可查看自己的匯出權限"
  on public.expo_admins
  for select
  to authenticated
  using (user_id = auth.uid());

commit;
