-- =============================================================
-- 報修登記系統｜Supabase 建表 SQL
-- 說明：本檔只供檢閱與手動執行，請在 Supabase SQL Editor 中整段執行。
-- 安全設計分三層：
--   1. CHECK：在資料表層級限制欄位值與文字長度
--   2. GRANT：只開放 anon 讀取與新增必要欄位，不開放修改、刪除
--   3. RLS：啟用資料列安全，任何人可讀；新增時 status 只能是「待處理」
-- =============================================================

begin;

-- -------------------------------------------------------------
-- 建立資料表 repair_requests（含第 3 層：CHECK 限制）
-- -------------------------------------------------------------
create table public.repair_requests (
  -- 主鍵：由資料庫自動產生 UUID
  id uuid primary key default gen_random_uuid(),

  -- 建立時間：由資料庫自動產生，使用者不需也不能填寫
  created_at timestamptz not null default now(),

  -- 報修人姓名：去除前後空白後不可為空，最多 50 字
  reporter_name text not null
    constraint repair_requests_reporter_name_len
    check (char_length(btrim(reporter_name)) between 1 and 50),

  -- 地點或部門：去除前後空白後不可為空，最多 100 字
  location text not null
    constraint repair_requests_location_len
    check (char_length(btrim(location)) between 1 and 100),

  -- 類別：只能是 設備／網路／環境／其他
  category text not null
    constraint repair_requests_category_valid
    check (category in ('設備', '網路', '環境', '其他')),

  -- 問題說明：去除前後空白後不可為空，最多 1000 字
  description text not null
    constraint repair_requests_description_len
    check (char_length(btrim(description)) between 1 and 1000),

  -- 緊急程度：只能是 低／中／高，預設「中」
  urgency text not null default '中'
    constraint repair_requests_urgency_valid
    check (urgency in ('低', '中', '高')),

  -- 處理狀態：只能是 待處理／處理中／已完成，預設「待處理」
  status text not null default '待處理'
    constraint repair_requests_status_valid
    check (status in ('待處理', '處理中', '已完成'))
);

comment on table public.repair_requests is '報修登記資料（示範用，內容皆為虛構）';

-- 清單依建立時間由新到舊排序時使用的索引
create index repair_requests_created_at_idx
  on public.repair_requests (created_at desc);

-- -------------------------------------------------------------
-- 第 1 層：GRANT 權限
-- 先收回所有權限，再只開放 anon 需要的最小權限。
-- -------------------------------------------------------------

-- 收回預設可能存在的權限（anon、authenticated 與 public 一律先清空）
revoke all on table public.repair_requests from public, anon, authenticated;

-- anon 需要能使用 public schema 才能存取其中的資料表
grant usage on schema public to anon;

-- anon 可以讀取整張清單
grant select on table public.repair_requests to anon;

-- anon 只能新增使用者要填的欄位；
-- id、created_at 由系統產生，status 一律用預設值「待處理」，皆不開放寫入
grant insert (reporter_name, location, category, description, urgency)
  on table public.repair_requests to anon;

-- 不授予 update、delete、truncate，因此 anon 無法修改或刪除任何資料

-- -------------------------------------------------------------
-- 第 2 層：RLS 資料列安全
-- 啟用後，沒有對應政策的操作（update、delete）一律被拒絕。
-- -------------------------------------------------------------
alter table public.repair_requests enable row level security;

-- 任何人（anon）都可以讀取全部清單
create policy "anon 可讀取報修清單"
  on public.repair_requests
  for select
  to anon
  using (true);

-- 任何人（anon）都可以新增，但新增的資料 status 必須是「待處理」
-- （欄位權限已阻止寫入 status，此政策是第二道防線）
create policy "anon 可新增待處理的報修"
  on public.repair_requests
  for insert
  to anon
  with check (status = '待處理');

-- 刻意不建立 update、delete 政策：即使日後誤開了 GRANT，RLS 仍會拒絕修改與刪除

commit;
