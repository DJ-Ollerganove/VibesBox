const CACHE_NAME = 'dj-wunschbox-v13';

// Install: alten Cache leeren, sofort aktivieren
self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.keys().then((names) =>
      Promise.all(names.map((name) => caches.delete(name)))
    )
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) =>
      Promise.all(
        cacheNames
          .filter((cacheName) => cacheName !== CACHE_NAME)
          .map((cacheName) => caches.delete(cacheName))
      )
    ).then(() => self.clients.claim())
  );
});

// JS / Lang-Pakete: immer Netzwerk (nie stale i18n-Keys wie suggestions_auto_appear).
// Andere Assets: Netzwerk zuerst, Cache nur als Offline-Fallback.
self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  let path = '';
  try {
    path = new URL(req.url).pathname || '';
  } catch (e) {
    return;
  }

  const noStore =
    path.indexOf('/vb/lang/') === 0 ||
    path.indexOf('/vb/scripts/') === 0 ||
    path.endsWith('/vb/app.js') ||
    path.endsWith('/vb/service-worker.js') ||
    path.endsWith('.js');

  if (noStore) {
    event.respondWith(fetch(req));
    return;
  }

  event.respondWith(
    fetch(req)
      .then((response) => response)
      .catch(() => caches.match(req))
  );
});
