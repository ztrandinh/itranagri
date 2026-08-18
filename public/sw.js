// ITRAN OS service worker: cache shell + static; network-first cho trang; API không cache (queue offline lo phần ghi)
const V = "itran-v1";
const PRECACHE = ["/offline", "/manifest.webmanifest", "/icon.svg"];
self.addEventListener("install", (e) => { self.skipWaiting(); e.waitUntil(caches.open(V).then((c) => c.addAll(PRECACHE).catch(() => {}))); });
self.addEventListener("activate", (e) => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== V).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener("fetch", (e) => {
  const u = new URL(e.request.url);
  if (e.request.method !== "GET" || u.pathname.startsWith("/api/")) return;
  if (u.pathname.startsWith("/_next/static") || u.pathname.startsWith("/uploads/") || /\.(svg|png|ico|webmanifest)$/.test(u.pathname)) {
    e.respondWith(caches.open(V).then(async c => (await c.match(e.request)) || fetch(e.request).then(r => { c.put(e.request, r.clone()); return r; })));
    return;
  }
  e.respondWith(fetch(e.request).then(r => { const cp = r.clone(); caches.open(V).then(c => c.put(e.request, cp)); return r; }).catch(() => caches.match(e.request).then(r => r || caches.match("/offline"))));
});
