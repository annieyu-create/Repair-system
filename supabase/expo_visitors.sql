-- =============================================================
-- 國外展覽訪客登錄｜Supabase 建表 SQL
-- 說明：本檔只供檢閱與手動執行，請在 Supabase SQL Editor 中整段執行。
-- 存取規則：
--   - 手機（anon，未登入）：只能「新增」訪客，不能讀取、修改、刪除。
--   - 匯出 Excel：須用 Supabase 帳號登入，且該帳號列在 expo_admins 才能讀取名單。
-- =============================================================

begin;

-- -------------------------------------------------------------
-- 訪客資料表
-- -------------------------------------------------------------
create table public.expo_visitors (
  -- 主鍵：由手機產生（離線暫存後重送時，可避免同一筆重複寫入）；沒給時由資料庫產生
  id uuid primary key default gen_random_uuid(),

  -- 編號：由資料庫依新增順序自動產生 1、2、3…（不能由手機指定）
  visitor_no bigint generated always as identity unique,

  -- 日期：拜訪日期，手機預設帶入當天，可修改
  visit_date date not null default current_date,

  -- 登錄時間：由資料庫自動產生
  created_at timestamptz not null default now(),

  -- 公司名稱（必填，最多 100 字）
  company_name text not null
    constraint expo_visitors_company_name_len
    check (char_length(btrim(company_name)) between 1 and 100),

  -- 國別（必填，最多 50 字）
  country text not null
    constraint expo_visitors_country_len
    check (char_length(btrim(country)) between 1 and 50),

  -- 人名（必填，最多 50 字）
  contact_name text not null
    constraint expo_visitors_contact_name_len
    check (char_length(btrim(contact_name)) between 1 and 50),

  -- 電話（選填，最多 30 字）
  phone text
    constraint expo_visitors_phone_len
    check (phone is null or char_length(phone) <= 30),

  -- 公司網站（選填，最多 200 字）
  website text
    constraint expo_visitors_website_len
    check (website is null or char_length(website) <= 200),

  -- 訪客性質（必填，固定選項）
  visitor_type text not null
    constraint expo_visitors_visitor_type_valid
    check (visitor_type in ('採購', '經銷商', '鷹架公司', '模板公司')),

  -- 有興趣的品項（可複選，只能是下列產品類別）
  interested_items text[] not null default '{}'
    constraint expo_visitors_interested_items_valid
    check (interested_items <@ array[
      'Scaffolding Accessories', 'Ring System Scaffolding',
      'Formwork Accessories', 'System Formwork', 'Others'
    ]::text[]),

  -- 選 Others 時的品項說明（選填，最多 200 字）
  interested_other text
    constraint expo_visitors_interested_other_len
    check (interested_other is null or char_length(interested_other) <= 200),

  -- 討論事項（選填，最多 2000 字）
  discussion text
    constraint expo_visitors_discussion_len
    check (discussion is null or char_length(discussion) <= 2000),

  -- 登錄人員：哪位同仁用哪支手機登錄（選填，最多 50 字）
  staff_name text
    constraint expo_visitors_staff_name_len
    check (staff_name is null or char_length(staff_name) <= 50)
);

comment on table public.expo_visitors is '國外展覽訪客登錄（示範用，內容皆為虛構）';

create index expo_visitors_created_at_idx
  on public.expo_visitors (created_at desc);
create index expo_visitors_visit_date_idx
  on public.expo_visitors (visit_date);

-- -------------------------------------------------------------
-- 可匯出名單的帳號清單
-- 帳號請在 Supabase 後台 Authentication → Users → Add user 建立，
-- 再執行本檔最後的 insert，把該帳號加進來。
-- -------------------------------------------------------------
create table public.expo_admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);

comment on table public.expo_admins is '可讀取與匯出展覽訪客名單的帳號';

-- -------------------------------------------------------------
-- GRANT
-- -------------------------------------------------------------
revoke all on table public.expo_visitors from public, anon, authenticated;
revoke all on table public.expo_admins from public, anon, authenticated;

grant usage on schema public to anon, authenticated;

-- 手機（anon）：只能新增使用者要填的欄位與手機產生的 id（編號、登錄時間由資料庫產生）
grant insert (id, visit_date, company_name, country, contact_name, phone, website,
              visitor_type, interested_items, interested_other, discussion, staff_name)
  on table public.expo_visitors to anon;

-- 登入的帳號：可讀取（實際能否讀到由下方 RLS 決定）
grant select on table public.expo_visitors to authenticated;
grant select on table public.expo_admins to authenticated;

-- -------------------------------------------------------------
-- RLS
-- -------------------------------------------------------------
alter table public.expo_visitors enable row level security;
alter table public.expo_admins enable row level security;

create policy "anon 可新增展覽訪客"
  on public.expo_visitors
  for insert
  to anon
  with check (true);

-- 只有列在 expo_admins 的帳號能讀取名單；其他登入者讀到的是空的
create policy "匯出帳號可讀取展覽訪客"
  on public.expo_visitors
  for select
  to authenticated
  using (exists (select 1 from public.expo_admins a where a.user_id = auth.uid()));

-- 登入者只能看到自己是否在 expo_admins 中
create policy "登入者可查看自己的匯出權限"
  on public.expo_admins
  for select
  to authenticated
  using (user_id = auth.uid());

-- 刻意不建立 update、delete 政策：任何人都無法經由網頁修改或刪除訪客資料

commit;

-- =============================================================
-- 建立帳號後，執行下面這行把它加入匯出名單（把 email 換成實際帳號）：
--
-- insert into public.expo_admins (user_id)
--   select id from auth.users where email = 'your-account@example.com';
-- =============================================================
