// Service worker de MyRapFr : rend le site installable et utilisable un minimum hors ligne.
// Règles :
//  - les pages (HTML) viennent toujours du réseau : elles contiennent tes données, elles ne sont
//    jamais mises en cache ; sans réseau, on affiche la page « hors ligne » ;
//  - l'API n'est jamais mise en cache ;
//  - les fichiers du site (CSS, JS, polices, icônes, pochettes) sont gardés et rafraîchis en arrière-plan.
const VERSION = '__VERSION__';
const STATIC = `mrf-static-${VERSION}`;
const IMAGES = 'mrf-images';
const PRECACHE = ['/hors-ligne', '/css/main.css', '/img/icons.svg', '/img/icon-192.png', '/fonts/inter-var.woff2'];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(STATIC).then((c) => c.addAll(PRECACHE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(caches.keys()
    .then((keys) => Promise.all(keys.filter((k) => k.startsWith('mrf-static-') && k !== STATIC).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

// Garde au plus `max` images (les plus anciennes partent d'abord).
async function trim(cacheName, max) {
  const cache = await caches.open(cacheName);
  const keys = await cache.keys();
  for (const key of keys.slice(0, Math.max(0, keys.length - max))) await cache.delete(key);
}

async function staleWhileRevalidate(request, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request);
  const network = fetch(request).then((res) => {
    if (res.ok && res.type === 'basic') cache.put(request, res.clone()).then(() => cacheName === IMAGES && trim(IMAGES, 400));
    return res;
  }).catch(() => cached);
  return cached || network;
}

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin || url.pathname.startsWith('/api/')) return;

  if (request.mode === 'navigate') {
    event.respondWith(fetch(request).catch(() => caches.match('/hors-ligne')));
    return;
  }
  if (/^\/img\/(covers|artists|avatars)\//.test(url.pathname)) {
    event.respondWith(staleWhileRevalidate(request, IMAGES));
    return;
  }
  if (/^\/(css|js|vendor|fonts|img)\//.test(url.pathname)) {
    event.respondWith(staleWhileRevalidate(request, STATIC));
  }
});
