報修登記系統
用於新增報修需求並查看報修清單。
雲端任務測試

- [報修欄位表（Excel）](文件/報修欄位表.xlsx)
- [報修登記網頁](https://annieyu-create.github.io/Repair-system/)（GitHub Pages，原始碼為根目錄的 index.html、style.css、app.js、config.js）
- [展覽訪客登錄（手機 App）](https://annieyu-create.github.io/Repair-system/visitor.html)（原始碼為 visitor.html、visitor.css、visitor.js，共用 style.css、config.js）
- [展覽訪客登錄 QR Code](文件/展覽訪客登錄_QRCode.png)（掃描直接開啟手機登錄頁）
- [訪客名單匯出（電腦下載 Excel）](https://annieyu-create.github.io/Repair-system/visitor-admin.html)（原始碼為 visitor-admin.html、visitor-admin.js）

## 變更紀錄

### 報修清單依緊急程度篩選
- 清單上方新增「全部／高／中／低」篩選按鈕，預設「全部」；選到的按鈕以藍底白字標示。
- 篩選只套用在網頁已讀到的最近 20 筆，不會另外查詢資料庫；按「重新整理」或送出新報修後，仍保留目前的篩選。
- 緊急程度為「高」的標籤改為紅底白字。
- 只修改網頁（index.html、app.js、style.css），資料庫與 `supabase/` 資料夾未變更。

### 修正手機看不到篩選功能
- 網頁引用 `style.css`、`config.js`、`app.js` 時加上版本號（`?v=…`），避免手機瀏覽器沿用舊版快取，導致篩選按鈕沒反應、「高」標籤不是紅色。
- 之後每次修改這三個檔案，請一併更新 `index.html` 裡的版本號。

### 加上大海底圖
- 新增自繪向量底圖 `images/ocean-bg.svg`（天空、太陽、海浪），固定在畫面後方，捲動時不動，手機與電腦都適用。
- 標題列改為半透明深藍，讓底圖透出；表單與清單維持白底卡片，確保文字好讀。
- `index.html` 的版本號更新為 `?v=20261112-3`。

### 做成 PWA（可加入主畫面）
- 新增 `manifest.webmanifest`、`sw.js`（Service Worker）與 `icons/`（海洋底＋扳手圖示）。
- 手機可把網頁「加入主畫面」，之後像 App 一樣全螢幕開啟；沒有網路時仍能打開頁面，但送出報修與讀取清單需要連線。
- 快取策略：網頁檔案先抓網路最新版、離線才用快取；Supabase 資料一律即時讀取、不快取。
- 之後修改網頁檔案時，請同時更新 `index.html` 的 `?v=` 版本號，以及 `sw.js` 的 `CACHE_VERSION` 與 `APP_SHELL` 中的版本號。

### 新增國外展覽訪客登錄表單
- 新增 `visitor.html`：欄位為公司名稱、國別、人名、電話、公司網站、公司性質、有興趣的品項、討論事項；登錄時間由資料庫自動產生。
- 必填：公司名稱、國別、人名、公司性質；其餘選填。標籤為中英對照，方便國外訪客自行填寫。
- 國別可直接輸入，也可從常見國家清單選擇；公司性質為固定選項（製造商、貿易商／進口商、經銷商／代理商、零售商、品牌商、其他）。
- 訪客資料含姓名與電話，因此網頁**只能新增、不能讀取**名單；頁面只列出這台裝置本次送出的公司。完整名單請到 Supabase 後台查看。
- 使用前請先在 Supabase SQL Editor 執行 `supabase/expo_visitors.sql` 建立 `expo_visitors` 資料表與存取規則。

### 展覽訪客：產品類別、多支手機、匯出 Excel
- 「有興趣的品項」改為產品類別複選：Scaffolding Accessories、Ring System Scaffolding、Formwork Accessories、System Formwork、Others；勾 Others 時可填品項說明。
- 新增「登錄人員」欄位（選填），每支手機填一次後會自動記住，Excel 可看出是誰登錄的。
- 手機 App：用手機瀏覽器開啟訪客登錄頁，選「加入主畫面」即可像 App 一樣使用（圖示為藍底訪客名牌）。
- 多支手機：所有手機都寫入同一個 Supabase 資料表，不需要另外合併。
- 展場網路不穩：送出時若沒有網路，資料先存在該手機，恢復連線或下次開啟時自動補上傳；每筆資料有唯一編號，重送不會重複。
- 匯出 Excel：用電腦開啟 `visitor-admin.html`，以授權帳號登入，可選日期範圍，下載 `expo-visitors_日期_時間.xlsx`。
- `sw.js` 的 `CACHE_VERSION` 更新為 `repair-v20261117-2`，並加入訪客登錄頁檔案。

#### 第一次設定（在 Supabase 後台）
1. SQL Editor 整段執行 `supabase/expo_visitors_setup.sql`。不論還沒建表或已建過舊版都適用，會自動升級到最新版，重複執行也不會出錯。（`expo_visitors.sql` 只能用在還沒建表時；`expo_visitors_upgrade_v2.sql`、`expo_visitors_upgrade_v3.sql` 為舊的分段升級檔，已由 setup 取代。）
2. Authentication → Users → Add user，建立要下載 Excel 的帳號（Email＋密碼）。
3. SQL Editor 執行：`insert into public.expo_admins (user_id) select id from auth.users where email = '該帳號 email';`
4. 建議到 Authentication → Sign In / Providers 關閉「Allow new users to sign up」，避免陌生人自行註冊（即使註冊了，沒加進 expo_admins 也讀不到名單）。

### 展覽訪客：新增編號、日期，公司性質改為訪客性質
- 新增「編號」：由資料庫依上傳順序自動產生 1、2、3…，手機不需填寫；Excel 第一欄即為編號，並依編號排序。
- 新增「日期」（拜訪日期，必填）：手機預設帶入當天，可修改；連續登錄時會保留上一筆的日期。
- 「公司性質」改為「訪客性質」，選項為：採購、經銷商、鷹架公司、模板公司。
- 匯出頁的日期範圍改用「日期」欄位篩選；Excel 欄位順序：編號、日期、公司名稱、國別、人名、電話、公司網站、訪客性質、有興趣的品項、其他品項說明、討論事項、登錄人員、登錄時間。
- 離線暫存的資料在上傳時才取得編號，所以編號代表「上傳順序」，不一定等於拜訪的先後。
- 新增 `supabase/expo_visitors_upgrade_v3.sql`：已建表者用來補上編號（舊資料依登錄時間編號）與日期，並把舊的「經銷商／代理商」改為「經銷商」。

### 一鍵設定 SQL
- 新增 `supabase/expo_visitors_setup.sql`：自動判斷資料表目前是「未建立／第一版／第二版／最新版」，補齊缺少的欄位、權限與 RLS 政策，可重複執行。
- 起因：已建過資料表時再執行 `expo_visitors.sql` 會出現 `relation "expo_visitors" already exists`。
- 已用 PGlite（WASM 版 PostgreSQL 16）測試四種起始狀態各執行兩次：舊資料保留並補上編號與日期；anon 只能新增、不能讀取或修改；未授權的登入帳號讀不到資料，授權帳號可讀取全部。
