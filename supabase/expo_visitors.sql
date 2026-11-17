-- =============================================================
-- 國外展覽訪客登錄｜Supabase 建表 SQL
-- 說明：本檔只供檢閱與手動執行，請在 Supabase SQL Editor 中整段執行。
-- 與報修系統不同：訪客資料含姓名、電話等個人資料，
-- 因此前端（anon）只能「新增」，不能讀取、修改或刪除。
-- 查看名單請登入 Supabase 後台（Table Editor）或日後加上登入機制。
-- =============================================================

begin;

create table public.expo_visitors (
  -- 主鍵與登錄時間：由資料庫自動產生
  id uuid primary key default gen_random_uuid(),
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

  -- 公司性質（必填，固定選項）
  company_type text not null
    constraint expo_visitors_company_type_valid
    check (company_type in ('製造商', '貿易商／進口商', '經銷商／代理商', '零售商', '品牌商', '其他')),

  -- 有興趣的品項（選填，最多 500 字）
  interested_items text
    constraint expo_visitors_interested_items_len
    check (interested_items is null or char_length(interested_items) <= 500),

  -- 討論事項（選填，最多 2000 字）
  discussion text
    constraint expo_visitors_discussion_len
    check (discussion is null or char_length(discussion) <= 2000)
);

comment on table public.expo_visitors is '國外展覽訪客登錄（示範用，內容皆為虛構）';

create index expo_visitors_created_at_idx
  on public.expo_visitors (created_at desc);

-- -------------------------------------------------------------
-- GRANT：anon 只能新增使用者要填的欄位，不能讀取、修改、刪除
-- -------------------------------------------------------------
revoke all on table public.expo_visitors from public, anon, authenticated;
grant usage on schema public to anon;
grant insert (company_name, country, contact_name, phone, website,
              company_type, interested_items, discussion)
  on table public.expo_visitors to anon;

-- -------------------------------------------------------------
-- RLS：只建立 insert 政策；沒有 select／update／delete 政策，一律拒絕
-- -------------------------------------------------------------
alter table public.expo_visitors enable row level security;

create policy "anon 可新增展覽訪客"
  on public.expo_visitors
  for insert
  to anon
  with check (true);

commit;
