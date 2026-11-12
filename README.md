報修登記系統
用於新增報修需求並查看報修清單。
雲端任務測試

- [報修欄位表（Excel）](文件/報修欄位表.xlsx)
- [報修登記網頁](https://annieyu-create.github.io/Repair-system/)（GitHub Pages，原始碼為根目錄的 index.html、style.css、app.js、config.js）

## 變更紀錄

### 報修清單依緊急程度篩選
- 清單上方新增「全部／高／中／低」篩選按鈕，預設「全部」；選到的按鈕以藍底白字標示。
- 篩選只套用在網頁已讀到的最近 20 筆，不會另外查詢資料庫；按「重新整理」或送出新報修後，仍保留目前的篩選。
- 緊急程度為「高」的標籤改為紅底白字。
- 只修改網頁（index.html、app.js、style.css），資料庫與 `supabase/` 資料夾未變更。
