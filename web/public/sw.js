// Prompt-Armor Service Worker
// Cache version is injected by the GitHub Actions workflow on each deploy.
// Fallback value used during local development.
const CACHE_VERSION = '__SW_CACHE_VERSION__';
const CACHE_NAME = `prompt-armor-${CACHE_VERSION}`;

const BASE_PATH = '/Prompt_Copyrighting';

// Assets to pre-cache on install
const PRECACHE_URLS = [
  `${BASE_PATH}/`,
  `${BASE_PATH}/manifest.json`,
  `${BASE_PATH}/icon-192.png`,
  `${BASE_PATH}/icon-512.png`,
  `${BASE_PATH}/version.json`,
];

// ─── Install ───
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(PRECACHE_URLS);
    })
  );
  // Activate immediately instead of waiting
  self.skipWaiting();
});

// ─── Activate: clean old caches ───
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys
          .filter((key) => key.startsWith('prompt-armor-') && key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      );
    }).then(() => {
      // Notify all clients that a new version is active
      return self.clients.matchAll({ type: 'window' }).then((clients) => {
        clients.forEach((client) => {
          client.postMessage({
            type: 'SW_UPDATED',
            version: CACHE_VERSION,
          });
        });
      });
    })
  );
  // Take control of all pages immediately
  self.clients.claim();
});

// ─── Fetch: stale-while-revalidate for pages, cache-first for assets ───
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Skip non-GET and cross-origin requests
  if (event.request.method !== 'GET' || url.origin !== self.location.origin) {
    return;
  }

  // version.json: always network-first so update checks work
  if (url.pathname.endsWith('/version.json')) {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
          return response;
        })
        .catch(() => caches.match(event.request))
    );
    return;
  }

  // Everything else: stale-while-revalidate
  event.respondWith(
    caches.match(event.request).then((cached) => {
      const fetchPromise = fetch(event.request).then((response) => {
        if (response && response.status === 200) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        }
        return response;
      }).catch(() => cached);

      return cached || fetchPromise;
    })
  );
});

// ─── Listen for skip-waiting message from the page ───
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});
