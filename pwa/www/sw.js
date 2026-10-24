// Service worker minimal : rend l'app installable et affiche une page hors-ligne.
// Il ne met JAMAIS en cache les réponses de l'API : les données de trading sont toujours fraîches.
const CACHE = "freqtrade-pwa-v1";
const OFFLINE_URL = "/pwa/offline.html";
const PRECACHE = [OFFLINE_URL, "/pwa/icons/icon-192.png"];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(PRECACHE)));
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  if (event.request.mode !== "navigate") return; // API, assets, websocket : réseau direct
  event.respondWith(fetch(event.request).catch(() => caches.match(OFFLINE_URL)));
});
