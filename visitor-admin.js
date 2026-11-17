(function () {
  "use strict";

  const { supabaseUrl, supabaseKey } = window.APP_CONFIG || {};
  const $ = (id) => document.getElementById(id);
  const loginCard = $("login-card");
  const exportCard = $("export-card");
  const loginForm = $("login-form");
  const loginBtn = $("login-btn");
  const loginMessage = $("login-message");
  const exportMessage = $("export-message");
  const downloadBtn = $("download-btn");

  // Excel 欄位順序與標題；value 從資料列取出要寫入儲存格的值
  const timeFormat = new Intl.DateTimeFormat("zh-TW", {
    year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", hour12: false,
  });
  const COLUMNS = [
    { title: "編號", width: 8, value: (r) => r.visitor_no },
    { title: "日期", width: 12, value: (r) => r.visit_date },
    { title: "公司名稱", width: 28, value: (r) => r.company_name },
    { title: "國別", width: 16, value: (r) => r.country },
    { title: "人名", width: 18, value: (r) => r.contact_name },
    { title: "電話", width: 18, value: (r) => r.phone || "" },
    { title: "公司網站", width: 26, value: (r) => r.website || "" },
    { title: "訪客性質", width: 16, value: (r) => r.visitor_type },
    { title: "有興趣的品項", width: 40, value: (r) => (r.interested_items || []).join(", ") },
    { title: "其他品項說明", width: 24, value: (r) => r.interested_other || "" },
    { title: "討論事項", width: 50, value: (r) => r.discussion || "" },
    { title: "登錄人員", width: 12, value: (r) => r.staff_name || "" },
    { title: "登錄時間", width: 18, value: (r) => timeFormat.format(new Date(r.created_at)) },
  ];
  const SELECT = "visitor_no, visit_date, created_at, company_name, country, contact_name, phone, website, " +
    "visitor_type, interested_items, interested_other, discussion, staff_name";

  function showMessage(el, text, type) {
    el.textContent = text;
    el.className = "message " + type;
    el.hidden = false;
  }

  if (!window.supabase || !window.XLSX || !supabaseUrl || !supabaseKey) {
    loginCard.hidden = false;
    showMessage(loginMessage, "無法載入必要元件，請確認網路後重新整理頁面。", "error");
    loginBtn.disabled = true;
    return;
  }

  // 電腦端記住登入狀態，下次開啟不必重新登入
  const db = window.supabase.createClient(supabaseUrl, supabaseKey);

  // 依「日期」欄位（拜訪日期）篩選
  function applyDates(query) {
    const from = $("date-from").value;
    const to = $("date-to").value;
    if (from) query = query.gte("visit_date", from);
    if (to) query = query.lte("visit_date", to);
    return query;
  }

  // Supabase 每次最多回傳 1000 筆，分批讀完
  async function fetchAll() {
    const PAGE = 1000;
    const rows = [];
    for (let start = 0; ; start += PAGE) {
      const { data, error } = await applyDates(
        db.from("expo_visitors").select(SELECT).order("visitor_no", { ascending: true })
      ).range(start, start + PAGE - 1);
      if (error) throw error;
      rows.push(...data);
      if (data.length < PAGE) return rows;
    }
  }

  function renderPreview(rows) {
    const head = $("preview-head");
    const body = $("preview-body");
    head.textContent = "";
    body.textContent = "";
    const tr = document.createElement("tr");
    for (const c of COLUMNS) {
      const th = document.createElement("th");
      th.textContent = c.title;
      tr.append(th);
    }
    head.append(tr);
    if (rows.length === 0) {
      const row = document.createElement("tr");
      const td = document.createElement("td");
      td.colSpan = COLUMNS.length;
      td.textContent = "目前沒有資料。";
      row.append(td);
      body.append(row);
      return;
    }
    for (const r of rows) {
      const row = document.createElement("tr");
      for (const c of COLUMNS) {
        const td = document.createElement("td");
        td.textContent = c.value(r);
        row.append(td);
      }
      body.append(row);
    }
  }

  async function loadPreview() {
    const { data, error } = await db.from("expo_visitors").select(SELECT)
      .order("visitor_no", { ascending: false }).limit(10);
    if (error) {
      showMessage(exportMessage, "讀取失敗：" + error.message, "error");
      return;
    }
    renderPreview(data);
  }

  async function checkAdmin(user) {
    const { data, error } = await db.from("expo_admins").select("user_id").eq("user_id", user.id);
    return !error && data.length > 0;
  }

  async function showSignedIn(user) {
    if (!(await checkAdmin(user))) {
      await db.auth.signOut();
      showSignedOut();
      showMessage(loginMessage, "此帳號沒有匯出權限，請聯絡管理員將帳號加入 expo_admins。", "error");
      return;
    }
    loginCard.hidden = true;
    exportCard.hidden = false;
    $("user-email").textContent = "已登入：" + (user.email || "");
    loadPreview();
  }

  function showSignedOut() {
    exportCard.hidden = true;
    loginCard.hidden = false;
  }

  loginForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    const email = $("email").value.trim();
    const password = $("password").value;
    if (!email || !password) {
      showMessage(loginMessage, "請輸入帳號與密碼。", "error");
      return;
    }
    loginBtn.disabled = true;
    loginBtn.textContent = "登入中…";
    const { data, error } = await db.auth.signInWithPassword({ email, password });
    loginBtn.disabled = false;
    loginBtn.textContent = "登入";
    if (error) {
      showMessage(loginMessage, "登入失敗：帳號或密碼錯誤。", "error");
      return;
    }
    loginMessage.hidden = true;
    $("password").value = "";
    showSignedIn(data.user);
  });

  $("logout-btn").addEventListener("click", async () => {
    await db.auth.signOut();
    showSignedOut();
  });

  function fileName() {
    const d = new Date();
    const pad = (n) => String(n).padStart(2, "0");
    return "expo-visitors_" + d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate()) +
      "_" + pad(d.getHours()) + pad(d.getMinutes()) + ".xlsx";
  }

  downloadBtn.addEventListener("click", async () => {
    downloadBtn.disabled = true;
    downloadBtn.textContent = "整理中…";
    try {
      const rows = await fetchAll();
      if (rows.length === 0) {
        showMessage(exportMessage, "所選日期內沒有訪客資料。", "info");
        return;
      }
      const aoa = [COLUMNS.map((c) => c.title), ...rows.map((r) => COLUMNS.map((c) => c.value(r)))];
      const sheet = XLSX.utils.aoa_to_sheet(aoa);
      sheet["!cols"] = COLUMNS.map((c) => ({ wch: c.width }));
      sheet["!autofilter"] = { ref: XLSX.utils.encode_range({ s: { r: 0, c: 0 }, e: { r: rows.length, c: COLUMNS.length - 1 } }) };
      const book = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(book, sheet, "展覽訪客");
      XLSX.writeFile(book, fileName());
      showMessage(exportMessage, "已下載 " + rows.length + " 筆訪客資料。", "success");
    } catch (error) {
      showMessage(exportMessage, "下載失敗：" + (error.message || error), "error");
    } finally {
      downloadBtn.disabled = false;
      downloadBtn.textContent = "下載 Excel";
    }
  });

  db.auth.getSession().then(({ data }) => {
    if (data.session) showSignedIn(data.session.user);
    else showSignedOut();
  });
})();
