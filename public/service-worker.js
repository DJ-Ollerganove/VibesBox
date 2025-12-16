const CACHE_NAME = 'dj-wunschbox-v4';
const urlsToCache = [
  '/',
  '/index.html',
  '/styles.css',
  '/manifest.json',
  '/icon-192.png',
  '/icon-512.png'
];

// Install Event - skipWaiting für sofortige Aktivierung
self.addEventListener('install', function(event) {
  self.skipWaiting(); // Sofort aktivieren, ohne auf andere Tabs zu warten
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(function(cache) {
        console.log('Cache geöffnet');
        return cache.addAll(urlsToCache);
      })
  );
});

// Fetch Event - Network First für index.html, Cache First für Assets
self.addEventListener('fetch', function(event) {
  // WICHTIG: POST, PUT, DELETE und andere nicht-GET Requests SOFORT durchleiten, KEIN Caching
  if (event.request.method !== 'GET') {
    event.respondWith(fetch(event.request));
    return;
  }
  
  // Ab hier sind nur noch GET-Requests
  const url = new URL(event.request.url);
  
  // Für index.html: Network First (immer neueste Version)
  if (url.pathname === '/' || url.pathname === '/index.html') {
    event.respondWith(
      fetch(event.request)
        .then(function(response) {
          // Zusätzliche Sicherheit: Nur GET-Requests mit Status 200 cachen
          if (response && response.status === 200 && response.type === 'basic') {
            // Wenn Netzwerk erfolgreich, Cache aktualisieren
            const responseClone = response.clone();
            caches.open(CACHE_NAME).then(function(cache) {
              // Nochmal prüfen, dass es ein GET-Request ist
              if (event.request.method === 'GET') {
                cache.put(event.request, responseClone).catch(function(err) {
                  console.log('Cache put Fehler (ignoriert):', err);
                });
              }
            });
          }
          return response;
        })
        .catch(function() {
          // Fallback auf Cache, wenn Netzwerk fehlschlägt
          return caches.match(event.request);
        })
    );
    return; // Wichtig: return nach dem respondWith
  }
  
  // Für andere Assets: Cache First (nur GET-Requests kommen hier an)
  event.respondWith(
    caches.match(event.request)
      .then(function(response) {
        if (response) {
          return response;
        }
        return fetch(event.request).then(function(response) {
          // Zusätzliche Sicherheit: Nur GET-Requests mit Status 200 cachen
          if (response && response.status === 200 && response.type === 'basic') {
            const responseClone = response.clone();
            caches.open(CACHE_NAME).then(function(cache) {
              // Nochmal prüfen, dass es ein GET-Request ist
              if (event.request.method === 'GET') {
                cache.put(event.request, responseClone).catch(function(err) {
                  console.log('Cache put Fehler (ignoriert):', err);
                });
              }
            });
          }
          return response;
        });
      })
  );
});

// Activate Event - Alte Caches löschen und sofort übernehmen
self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys().then(function(cacheNames) {
      return Promise.all(
        cacheNames.map(function(cacheName) {
          if (cacheName !== CACHE_NAME) {
            console.log('Alter Cache gelöscht:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    }).then(function() {
      // Sofort die Kontrolle über alle Clients übernehmen
      return self.clients.claim();
    })
  );
});
