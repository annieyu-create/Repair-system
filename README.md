報修登記系統
用於新增報修需求並查看報修清單。
雲端任務測試

- [報修欄位表（Excel）](文件/報修欄位表.xlsx)
- [報修登記網頁](https://annieyu-create.github.io/Repair-system/)（GitHub Pages，原始碼為根目錄的 index.html、style.css、app.js、config.js）
- [展覽訪客登錄網頁](https://annieyu-create.github.io/Repair-system/visitor.html)（原始碼為 visitor.html、visitor.css、visitor.js，共用 style.css、config.js）

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
