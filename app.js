(function () {
  "use strict";

  const { supabaseUrl, supabaseKey } = window.APP_CONFIG || {};
  const form = document.getElementById("repair-form");
  const submitBtn = document.getElementById("submit-btn");
  const formMessage = document.getElementById("form-message");
  const list = document.getElementById("request-list");
  const listMessage = document.getElementById("list-message");
  const refreshBtn = document.getElementById("refresh-btn");

  const FIELD_LABELS = {
    reporter_name: "報修人",
    location: "地點或部門",
    category: "類別",
    description: "問題說明",
    urgency: "緊急程度",
  };

  function showMessage(el, text, type) {
    el.textContent = text;
    el.className = "message " + type;
    el.hidden = false;
  }

  if (!window.supabase || !supabaseUrl || !supabaseKey) {
    showMessage(formMessage, "無法載入連線設定，請稍後重新整理頁面。", "error");
    submitBtn.disabled = true;
    return;
  }

  const db = window.supabase.createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false },
  });

  const timeFormat = new Intl.DateTimeFormat("zh-TW", {
    year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", hour12: false,
  });

  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function renderList(rows) {
    list.replaceChildren();
    if (rows.length === 0) {
      showMessage(listMessage, "目前還沒有報修紀錄。", "info");
      return;
    }
    listMessage.hidden = true;
    for (const row of rows) {
      const item = el("li", "request");
      const top = el("div", "request-top");
      top.append(
        el("span", "badge category", row.category),
        el("span", "badge urgency urgency-" + row.urgency, "緊急：" + row.urgency),
        el("span", "badge status", row.status)
      );
      item.append(
        top,
        el("p", "request-desc", row.description),
        el("p", "request-meta",
          row.reporter_name + "・" + row.location + "・" + timeFormat.format(new Date(row.created_at)))
      );
      list.append(item);
    }
  }

  async function loadList() {
    refreshBtn.disabled = true;
    const { data, error } = await db
      .from("repair_requests")
      .select("id, created_at, reporter_name, location, category, description, urgency, status")
      .order("created_at", { ascending: false })
      .limit(20);
    refreshBtn.disabled = false;
    if (error) {
      showMessage(listMessage, "清單載入失敗：" + error.message, "error");
      return;
    }
    renderList(data);
  }

  function readForm() {
    const fd = new FormData(form);
    const payload = {};
    for (const key of Object.keys(FIELD_LABELS)) {
      payload[key] = String(fd.get(key) || "").trim();
    }
    const missing = Object.keys(FIELD_LABELS).filter((k) => !payload[k]);
    return { payload, missing };
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const { payload, missing } = readForm();
    if (missing.length > 0) {
      showMessage(formMessage, "請填寫：" + missing.map((k) => FIELD_LABELS[k]).join("、"), "error");
      document.getElementById(missing[0] === "urgency" ? "urgency-mid" : missing[0]).focus();
      return;
    }

    submitBtn.disabled = true;
    submitBtn.textContent = "送出中…";
    // 不送 status，由資料庫預設為「待處理」
    const { error } = await db.from("repair_requests").insert(payload);
    submitBtn.disabled = false;
    submitBtn.textContent = "送出報修";

    if (error) {
      showMessage(formMessage, "送出失敗：" + error.message, "error");
      return;
    }
    showMessage(formMessage, "已送出報修，謝謝！", "success");
    form.reset();
    loadList();
  });

  refreshBtn.addEventListener("click", loadList);
  loadList();
})();
