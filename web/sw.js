'use strict';

// Eigener Service Worker – Flutters eingebauter SW ist deprecated und cached
// nichts mehr. Dieser hier gibt der PWA wieder Offline-Faehigkeit UND saubere
// Updates:
//  - network-first: online liefert immer die neueste Version (ein Reload
//    genuegt), offline wird aus dem Cache bedient.
//  - App-Shell wird nach dem ersten Online-Besuch gecacht -> PWA startet offline.
//  - skipWaiting + clients.claim(): ein neuer SW uebernimmt sofort.
//  - /caldav/ (CalDAV-Proxy) wird NIE angefasst – muss immer ans Netz.
const CACHE = 'tickdone-shell-v1';

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    // Alte Cache-Versionen aufraeumen.
    const keys = await caches.keys();
    await Promise.all(
      keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)),
    );
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  // Den CalDAV-Proxy NIE anfassen (muss immer ans Netz, darf nie aus dem Cache).
  if (url.origin === self.location.origin && url.pathname.startsWith('/caldav/')) {
    return;
  }

  // Network-first: online frisch, offline aus dem Cache. Auch Fremd-Ressourcen
  // (z.B. lokal gebuendeltes CanvasKit ist same-origin; Schriften ggf. extern)
  // werden gecacht, damit die App offline vollstaendig laedt.
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    try {
      const frisch = await fetch(req);
      if (frisch && (frisch.ok || frisch.type === 'opaque')) {
        cache.put(req, frisch.clone());
      }
      return frisch;
    } catch (e) {
      const gecacht = await cache.match(req);
      if (gecacht) return gecacht;
      if (req.mode === 'navigate') {
        const shell =
          (await cache.match('/index.html')) || (await cache.match('/'));
        if (shell) return shell;
      }
      throw e;
    }
  })());
});
