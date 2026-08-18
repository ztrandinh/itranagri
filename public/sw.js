// ITRAN AGRI service worker: cache shell + static; network-first cho trang; API không cache (queue offline lo phần ghi)
const V = "itran-v4";
const PRECACHE = ["/offline", "/manifest.webmanifest", "/icon.svg"];
self.addEventListener("install", (e) => { self.skipWaiting(); e.waitUntil(caches.open(V).then((c) => c.addAll(PRECACHE).catch(() => {}))); });
self.addEventListener("activate", (e) => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== V && k !== V + "-api").map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener("fetch", (e) => {
  const u = new URL(e.request.url);
  if (e.request.method !== "GET") return;
  if (u.pathname.startsWith("/api/")) {
    // Đọc offline: /api/data, /api/series, /api/list, /api/admin (GET) → network-first, rơi về cache khi mất mạng
    if (/^\/api\/(data|series|list|admin|notifications|search)/.test(u.pathname)) e.respondWith(fetch(e.request).then(r => { if (r.ok) { const cp = r.clone(); caches.open(V + "-api").then(c => c.put(e.request, cp)); } return r; }).catch(() => caches.match(e.request).then(r => r || new Response(JSON.stringify({ rows: [], offline: true }), { headers: { "content-type": "application/json" } }))));
    return;
  }
  // static: STALE-WHILE-REVALIDATE (trả cache ngay nhưng luôn tải bản mới) — tránh kẹt CSS/JS cũ khi build đổi; CSS/JS dev không cache
  if (u.pathname.startsWith("/_next/static") || u.pathname.startsWith("/uploads/") || /\.(svg|png|ico|webmanifest)$/.test(u.pathname)) {
    if (u.pathname.startsWith("/_next/static/chunks/") && !/\-[a-f0-9]{8,}\./.test(u.pathname)) return; // chunk dev không có hash → không cache
    e.respondWith(caches.open(V).then(async c => { const hit = await c.match(e.request); const net = fetch(e.request).then(r => { if (r.ok) c.put(e.request, r.clone()); return r; }).catch(() => hit); return hit || net; }));
    return;
  }
  e.respondWith(fetch(e.request).then(r => { const cp = r.clone(); caches.open(V).then(c => c.put(e.request, cp)); return r; }).catch(() => caches.match(e.request).then(r => r || caches.match("/offline"))));
});

// WEB PUSH: hiện thông báo nổi + mở đúng trang khi bấm
self.addEventListener("push", (e) => { let d = {}; try { d = e.data ? e.data.json() : {}; } catch { d = { title: "ITRAN AGRI", body: e.data && e.data.text() }; }
  e.waitUntil(self.registration.showNotification(d.title || "ITRAN AGRI", { body: d.body || "", icon: "/icon.svg", badge: "/icon.svg", tag: d.id || undefined, data: { url: d.url || "/" }, vibrate: d.level === "DO" ? [200, 100, 200] : [80], requireInteraction: d.level === "DO" })); });
self.addEventListener("notificationclick", (e) => { e.notification.close(); const url = (e.notification.data && e.notification.data.url) || "/"; e.waitUntil(clients.matchAll({ type: "window", includeUncontrolled: true }).then((ws) => { for (const w of ws) { if ("focus" in w) { w.navigate(url); return w.focus(); } } return clients.openWindow(url); })); });
