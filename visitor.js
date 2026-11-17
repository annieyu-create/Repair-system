(function () {
  "use strict";

  const { supabaseUrl, supabaseKey } = window.APP_CONFIG || {};
  const form = document.getElementById("visitor-form");
  const submitBtn = document.getElementById("submit-btn");
  const formMessage = document.getElementById("form-message");
  const recentList = document.getElementById("recent-list");

  // 所有欄位與中文名稱；required 為必填
  const FIELDS = {
    company_name: { label: "公司名稱", required: true },
    country: { label: "國別", required: true },
    contact_name: { label: "人名", required: true },
    phone: { label: "電話", required: false },
    website: { label: "公司網站", required: false },
    company_type: { label: "公司性質", required: true },
    interested_items: { label: "有興趣的品項", required: false },
    discussion: { label: "討論事項", required: false },
  };

  function showMessage(text, type) {
    formMessage.textContent = text;
    formMessage.className = "message " + type;
    formMessage.hidden = false;
  }

  if (!window.supabase || !supabaseUrl || !supabaseKey) {
    showMessage("無法載入連線設定，請稍後重新整理頁面。", "error");
    submitBtn.disabled = true;
    return;
  }

  const db = window.supabase.createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false },
  });

  const timeFormat = new Intl.DateTimeFormat("zh-TW", {
    hour: "2-digit", minute: "2-digit", hour12: false,
  });

  function readForm() {
    const fd = new FormData(form);
    const payload = {};
    const missing = [];
    for (const [key, def] of Object.entries(FIELDS)) {
      const value = String(fd.get(key) || "").trim();
      if (def.required && !value) missing.push(key);
      // 選填欄位留白時存成 null，資料庫比較好篩選
      payload[key] = value || null;
    }
    return { payload, missing };
  }

  function addRecent(payload) {
    const li = document.createElement("li");
    const name = document.createElement("strong");
    name.textContent = payload.company_name;
    const meta = document.createElement("div");
    meta.className = "meta";
    meta.textContent = payload.contact_name + "・" + payload.country + "・" + timeFormat.format(new Date());
    li.append(name, meta);
    recentList.prepend(li);
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const { payload, missing } = readForm();
    if (missing.length > 0) {
      showMessage("請填寫：" + missing.map((k) => FIELDS[k].label).join("、"), "error");
      document.getElementById(missing[0]).focus();
      return;
    }

    submitBtn.disabled = true;
    submitBtn.textContent = "送出中…";
    // anon 沒有讀取權限，只新增、不要求回傳資料
    const { error } = await db.from("expo_visitors").insert(payload);
    submitBtn.disabled = false;
    submitBtn.textContent = "送出登錄";

    if (error) {
      showMessage("送出失敗：" + error.message, "error");
      return;
    }
    showMessage("已登錄「" + payload.company_name + "」，謝謝！", "success");
    addRecent(payload);
    form.reset();
    document.getElementById("company_name").focus();
  });

  window.addEventListener("offline", () => {
    showMessage("目前沒有網路，恢復連線後才能送出登錄。", "error");
  });
  window.addEventListener("online", () => { formMessage.hidden = true; });
})();
