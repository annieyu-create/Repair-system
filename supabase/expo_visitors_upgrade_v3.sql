-- =============================================================
-- 國外展覽訪客登錄｜升級 SQL（v2 → v3）
-- 只有「已經建過 expo_visitors 資料表」才需要執行本檔：
--   - 執行過 v1（第一版 expo_visitors.sql）：先執行 expo_visitors_upgrade_v2.sql，再執行本檔。
--   - 執行過 v2：直接執行本檔。
--   - 還沒建表：直接執行最新的 expo_visitors.sql，不需要本檔。
-- 變更：新增「編號」（自動流水號）與「日期」；「公司性質」改為「訪客性質」。
-- =============================================================

begin;

-- 日期：舊資料以登錄時間（台灣時間）的日期補上
alter table public.expo_visitors add column visit_date date;
update public.expo_visitors
  set visit_date = (created_at at time zone 'Asia/Taipei')::date;
alter table public.expo_visitors
  alter column visit_date set default current_date,
  alter column visit_date set not null;
create index expo_visitors_visit_date_idx on public.expo_visitors (visit_date);

-- 編號：舊資料依登錄時間先後編 1、2、3…，之後新增的接續往下編
alter table public.expo_visitors add column visitor_no bigint;
update public.expo_visitors v
  set visitor_no = n.rn
  from (select id, row_number() over (order by created_at, id) as rn
        from public.expo_visitors) n
  where v.id = n.id;
alter table public.expo_visitors
  alter column visitor_no set not null,
  add constraint expo_visitors_visitor_no_key unique (visitor_no);
do $$
declare next_no bigint;
begin
  select coalesce(max(visitor_no), 0) + 1 into next_no from public.expo_visitors;
  execute format(
    'alter table public.expo_visitors alter column visitor_no add generated always as identity (start with %s)',
    next_no);
end $$;

-- 公司性質 → 訪客性質
-- 舊資料的「經銷商／代理商」改為「經銷商」；其他舊選項保留原值，
-- 新規則只檢查之後新增的資料（not valid），請到後台手動改成新選項。
alter table public.expo_visitors rename column company_type to visitor_type;
alter table public.expo_visitors drop constraint expo_visitors_company_type_valid;
update public.expo_visitors set visitor_type = '經銷商' where visitor_type = '經銷商／代理商';
alter table public.expo_visitors
  add constraint expo_visitors_visitor_type_valid
  check (visitor_type in ('採購', '經銷商', '鷹架公司', '模板公司')) not valid;

-- 重新設定手機（anon）可新增的欄位
revoke insert on table public.expo_visitors from anon;
grant insert (id, visit_date, company_name, country, contact_name, phone, website,
              visitor_type, interested_items, interested_other, discussion, staff_name)
  on table public.expo_visitors to anon;

commit;
