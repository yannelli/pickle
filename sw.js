/* Bump CACHE_VERSION with every deploy so installed apps pick up new files. */
const CACHE_VERSION = 'little-dill-v10';
const PRECACHE = [
  './',
  './save-codec.js',
  './audio.js',
  './pet-life.js',
  './pet-art.js',
  './reminders.js',
  './site.webmanifest',
  './favicon.svg',
  './favicon.ico',
  './apple-touch-icon.png',
  './assets/brand/logo.svg',
  './assets/icons/icon-192.png',
  './assets/icons/icon-512.png',
  './assets/icons/maskable-512.png'
];

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE_VERSION).then(cache => cache.addAll(PRECACHE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', event => {
  event.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(key => key.startsWith('little-dill-') && key !== CACHE_VERSION).map(key => caches.delete(key))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', event => {
  const { request } = event;
  if (new URL(request.url).pathname.startsWith('/api/')) return;
  if (request.method !== 'GET' || new URL(request.url).origin !== self.location.origin) return;
  event.respondWith(request.mode === 'navigate' ? networkFirst(request) : staleWhileRevalidate(request));
});

async function networkFirst(request) {
  const cache = await caches.open(CACHE_VERSION);
  try {
    const response = await fetch(request);
    if (response.ok) cache.put(request, response.clone());
    return response;
  } catch {
    return (await cache.match(request)) || (await cache.match('./')) || Response.error();
  }
}

async function staleWhileRevalidate(request) {
  const cache = await caches.open(CACHE_VERSION);
  const cached = await cache.match(request);
  const network = fetch(request).then(response => {
    if (response.ok) cache.put(request, response.clone());
    return response;
  }).catch(() => cached || Response.error());
  return cached || network;
}

self.addEventListener('push', event => {
  event.waitUntil(self.registration.showNotification('A little brine, when you have a moment.', {
    body: 'Your pocket pickle would love a quick check-in. A snack, a game, a little love.',
    icon: './assets/icons/icon-192.png', badge: './assets/icons/icon-192.png',
    tag: 'little-dill-care', renotify: false, silent: true,
    data: { url: self.registration.scope }
  }));
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const app = windows.find(client => client.url.startsWith(self.registration.scope));
    if (app) return app.focus();
    return self.clients.openWindow(self.registration.scope);
  })());
});
