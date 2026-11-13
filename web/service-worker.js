/* BandPlan app-shell cache. Supabase/API requests are intentionally never cached. */
const CACHE_PREFIX = 'bandplan-pwa-shell-';
const BUILD_ID = '__BUILD_ID__';
const CACHE_NAME = CACHE_PREFIX + BUILD_ID;
const MAX_RETAINED_CACHES = 2;
const APP_SCOPE = self.registration.scope;
const APP_INDEX = new URL('index.html', APP_SCOPE).href;
const ASSET_MANIFEST = new URL('asset-manifest.json', APP_SCOPE).href;

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    try {
      const manifestResponse = await fetch(ASSET_MANIFEST, { cache: 'no-store' });
      if (!manifestResponse.ok) {
        throw new Error('BandPlan PWA asset manifest could not be loaded.');
      }

      const manifest = await manifestResponse.json();
      if (!Array.isArray(manifest.assets) || manifest.assets.length === 0) {
        throw new Error('BandPlan PWA asset manifest is empty.');
      }

      const cache = await caches.open(CACHE_NAME);
      for (const path of manifest.assets) {
        if (typeof path !== 'string') continue;
        const assetUrl = new URL(path, APP_SCOPE);
        // WHY: Never cache off-site URLs or requests outside the GitHub Pages project path.
        if (assetUrl.origin !== self.location.origin ||
            !assetUrl.href.startsWith(APP_SCOPE)) {
          continue;
        }

        const request = new Request(assetUrl.href, { cache: 'reload' });
        const response = await fetch(request);
        if (!response.ok) {
          throw new Error('BandPlan PWA asset failed to cache: ' + path);
        }
        await cache.put(request, response);
      }

      // WHY: Do not call skipWaiting here. The browser activates this fully
      // downloaded worker after pages controlled by the old worker are closed,
      // so an active rehearsal/session is never interrupted by an update.
    } catch (error) {
      // WHY: A partial update must not occupy a retained-cache slot and
      // displace the last complete app shell during a later successful update.
      await caches.delete(CACHE_NAME);
      throw error;
    }
  })());
});

// WHY: Activate a fully downloaded update only after an explicit user action.
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'BANDPLAN_SKIP_WAITING') {
    event.waitUntil(self.skipWaiting());
  }
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const cacheNames = (await caches.keys())
      .filter((name) => name.startsWith(CACHE_PREFIX))
      .sort((left, right) => {
        const leftId = Number(left.slice(CACHE_PREFIX.length));
        const rightId = Number(right.slice(CACHE_PREFIX.length));
        return rightId - leftId;
      });

    // Keep the previous shell as a short rollback cushion; avoid unbounded storage growth.
    await Promise.all(
      cacheNames.slice(MAX_RETAINED_CACHES).map((name) => caches.delete(name)),
    );
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const requestUrl = new URL(request.url);

  // WHY: Auth, Supabase, uploads and all other API traffic must remain network-only.
  if (request.method !== 'GET' ||
      requestUrl.origin !== self.location.origin ||
      !requestUrl.href.startsWith(APP_SCOPE)) {
    return;
  }

  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      const cache = await caches.open(CACHE_NAME);

      // WHY: The cached index can contain an older update watcher, creating a
      // deadlock: it cannot display the update that would replace that index.
      // Fetch fresh HTML on every online entry, but keep the cached shell as
      // the offline fallback so the PWA still relaunches without a connection.
      try {
        const freshPage = await fetch(request, { cache: 'no-store' });
        if (freshPage.ok) return freshPage;
      } catch (_) {
        // Offline launch continues with the last complete app shell below.
      }

      const cachedShell = await cache.match(APP_INDEX) || await cache.match(request);
      if (cachedShell) return cachedShell;

      return new Response(
        'BandPlan is unavailable offline. Open the app once while online.',
        { status: 503, headers: { 'Content-Type': 'text/plain; charset=utf-8' } },
      );
    })());
    return;
  }

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(request);
    return cached || fetch(request);
  })());
});
