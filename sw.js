// 報修登記 PWA Service Worker
// 策略：
// - 網頁本身的檔案（HTML/CSS/JS/圖示）：先抓網路最新版，失敗（離線）才用快取，避免手機一直看到舊版。
// - CDN 上固定版本的 supabase-js：版本不會變，優先用快取。
// - Supabase 資料 API：一律走網路、不快取，清單與送出都是即時資料。
// 修改網頁檔案後，請一併更新 CACHE_VERSION。
const CACHE_VERSION = "repair-v20261112-4";
const APP_SHELL = [
  "./",
  "./index.html",
  "./style.css?v=20261112-4",
  "./config.js?v=20261112-4",
  "./app.js?v=20261112-4",
  "./manifest.webmanifest",
  "./images/ocean-bg.svg?v=1",
  "./icons/icon-192.png",
  "./icons/icon-512.png",
  "./icons/apple-touch-icon.png",
];
const SUPABASE_JS = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.js";

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION).then(async (cache) => {
      await cache.addAll(APP_SHELL);
      // CDN 檔案抓不到不影響安裝
      try { await cache.add(SUPABASE_JS); } catch (e) { /* 略過 */ }
    })
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);

  // Supabase 資料：不攔截，直接走網路
  if (url.hostname.endsWith(".supabase.co")) return;

  // 固定版本的 CDN 檔案：快取優先
  if (req.url === SUPABASE_JS) {
    event.respondWith(
      caches.match(req).then((hit) => hit || fetch(req).then((res) => {
        const copy = res.clone();
        caches.open(CACHE_VERSION).then((c) => c.put(req, copy));
        return res;
      }))
    );
    return;
  }

  // 同網站的檔案：網路優先，離線時改用快取
  if (url.origin === self.location.origin) {
    event.respondWith(
      fetch(req)
        .then((res) => {
          if (res.ok) {
            const copy = res.clone();
            caches.open(CACHE_VERSION).then((c) => c.put(req, copy));
          }
          return res;
        })
        .catch(() =>
          caches.match(req).then((hit) => hit || (req.mode === "navigate" ? caches.match("./index.html") : undefined))
        )
    );
  }
});
