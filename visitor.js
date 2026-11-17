(function () {
  "use strict";

  const { supabaseUrl, supabaseKey } = window.APP_CONFIG || {};
  const form = document.getElementById("visitor-form");
  const submitBtn = document.getElementById("submit-btn");
  const formMessage = document.getElementById("form-message");
  const recentList = document.getElementById("recent-list");
  const staffInput = document.getElementById("staff_name");
  const othersBox = document.getElementById("items-others");
  const otherInput = document.getElementById("interested_other");
  const pendingBar = document.getElementById("pending-bar");
  const pendingText = document.getElementById("pending-text");
  const syncBtn = document.getElementById("sync-btn");

  // 文字欄位與中文名稱；required 為必填
  const TEXT_FIELDS = {
    company_name: { label: "公司名稱", required: true },
    country: { label: "國別", required: true },
    contact_name: { label: "人名", required: true },
    phone: { label: "電話", required: false },
    website: { label: "公司網站", required: false },
    company_type: { label: "公司性質", required: true },
    discussion: { label: "討論事項", required: false },
    staff_name: { label: "登錄人員", required: false },
  };

  const STAFF_KEY = "expo-visitor-staff";
  const QUEUE_KEY = "expo-visitor-queue";

  function showMessage(text, type) {
    formMessage.textContent = text;
    formMessage.className = "message " + type;
    formMessage.hidden = false;
  }

  // localStorage 在私密瀏覽等情況可能無法使用，一律包 try/catch
  function storeGet(key, fallback) {
    try {
      const raw = localStorage.getItem(key);
      return raw === null ? fallback : JSON.parse(raw);
    } catch (e) {
      return fallback;
    }
  }
  function storeSet(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
      return true;
    } catch (e) {
      return false;
    }
  }

  // 登錄人員：這支手機填過一次就記住
  staffInput.value = storeGet(STAFF_KEY, "");

  othersBox.addEventListener("change", () => {
    otherInput.hidden = !othersBox.checked;
    if (othersBox.checked) otherInput.focus();
  });

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

  function newId() {
    if (window.crypto && crypto.randomUUID) return crypto.randomUUID();
    // 舊瀏覽器備援：產生 UUID v4
    return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
      const r = (crypto.getRandomValues(new Uint8Array(1))[0] & 15);
      return (c === "x" ? r : (r & 3) | 8).toString(16);
    });
  }

  function readForm() {
    const fd = new FormData(form);
    const payload = { id: newId() };
    const missing = [];
    for (const [key, def] of Object.entries(TEXT_FIELDS)) {
      const value = String(fd.get(key) || "").trim();
      if (def.required && !value) missing.push(key);
      // 選填欄位留白時存成 null
      payload[key] = value || null;
    }
    payload.interested_items = fd.getAll("interested_items").map(String);
    const other = String(fd.get("interested_other") || "").trim();
    payload.interested_other = payload.interested_items.includes("Others") && other ? other : null;
    return { payload, missing };
  }

  // 上傳一筆；同一個 id 已存在（之前其實已送達）也算成功
  async function upload(payload) {
    const { error } = await db.from("expo_visitors").insert(payload);
    if (!error || error.code === "23505") return { ok: true };
    // 沒有 code 通常是網路問題，可稍後重送；有 code 是資料被資料庫拒絕
    return { ok: false, retry: !error.code, message: error.message };
  }

  // ---------- 離線暫存佇列 ----------
  function getQueue() { return storeGet(QUEUE_KEY, []); }

  function renderPending() {
    const n = getQueue().length;
    pendingBar.hidden = n === 0;
    pendingText.textContent = "這支手機有 " + n + " 筆尚未上傳";
  }

  let syncing = false;
  async function syncQueue() {
    if (syncing) return;
    const queue = getQueue();
    if (queue.length === 0) return renderPending();
    syncing = true;
    syncBtn.disabled = true;
    const remaining = [];
    let uploaded = 0;
    for (const item of queue) {
      const result = await upload(item);
      if (result.ok) {
        uploaded += 1;
        markUploaded(item.id);
      } else {
        remaining.push(item);
      }
    }
    storeSet(QUEUE_KEY, remaining);
    syncing = false;
    syncBtn.disabled = false;
    renderPending();
    if (uploaded > 0) {
      showMessage("已補上傳 " + uploaded + " 筆暫存資料。", "success");
    } else if (remaining.length > 0 && navigator.onLine) {
      showMessage("暫存資料仍無法上傳，請稍後再按「立即上傳」。", "error");
    }
  }

  // ---------- 本機登錄紀錄 ----------
  function addRecent(payload, pending) {
    const li = document.createElement("li");
    li.dataset.id = payload.id;
    const name = document.createElement("strong");
    name.textContent = payload.company_name;
    const tag = document.createElement("span");
    tag.className = "tag" + (pending ? " pending" : "");
    tag.textContent = pending ? "待上傳" : "已上傳";
    name.append(tag);
    const meta = document.createElement("div");
    meta.className = "meta";
    meta.textContent = payload.contact_name + "・" + payload.country + "・" + timeFormat.format(new Date());
    li.append(name, meta);
    recentList.prepend(li);
  }

  function markUploaded(id) {
    const tag = recentList.querySelector('li[data-id="' + id + '"] .tag');
    if (tag) {
      tag.className = "tag";
      tag.textContent = "已上傳";
    }
  }

  function resetForm(staff) {
    form.reset();
    staffInput.value = staff || "";
    otherInput.hidden = true;
    document.getElementById("company_name").focus();
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const { payload, missing } = readForm();
    if (missing.length > 0) {
      showMessage("請填寫：" + missing.map((k) => TEXT_FIELDS[k].label).join("、"), "error");
      document.getElementById(missing[0]).focus();
      return;
    }
    storeSet(STAFF_KEY, payload.staff_name || "");

    submitBtn.disabled = true;
    submitBtn.textContent = "送出中…";
    const result = navigator.onLine ? await upload(payload) : { ok: false, retry: true };
    submitBtn.disabled = false;
    submitBtn.textContent = "送出登錄";

    if (result.ok) {
      showMessage("已登錄「" + payload.company_name + "」，謝謝！", "success");
      addRecent(payload, false);
      resetForm(payload.staff_name);
      syncQueue();
      return;
    }
    if (result.retry) {
      // 網路不通：先存在這支手機，恢復連線後自動上傳
      const queue = getQueue();
      queue.push(payload);
      if (!storeSet(QUEUE_KEY, queue)) {
        showMessage("目前無法連線，且這支手機無法暫存資料，請恢復網路後再送出。", "error");
        return;
      }
      showMessage("目前無法連線，已先存在這支手機，恢復網路後會自動上傳。", "info");
      addRecent(payload, true);
      renderPending();
      resetForm(payload.staff_name);
      return;
    }
    showMessage("送出失敗：" + result.message, "error");
  });

  syncBtn.addEventListener("click", syncQueue);
  window.addEventListener("offline", () => {
    showMessage("目前沒有網路，仍可繼續登錄，資料會先存在這支手機。", "info");
  });
  window.addEventListener("online", syncQueue);

  renderPending();
  syncQueue();
})();

// PWA：註冊 Service Worker（可加入主畫面、離線時仍能開啟頁面）
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("sw.js").catch(() => {});
  });
}
