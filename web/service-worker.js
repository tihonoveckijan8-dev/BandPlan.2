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
  })());
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
      // WHY: A launch must not wait for GitHub Pages or the network. The
      // versioned index is installed before this worker can become active.
      const cachedShell = await cache.match(APP_INDEX) || await cache.match(request);
      if (cachedShell) return cachedShell;

      // WHY: Network is only a first-visit fallback; an active worker should
      // always have a complete app shell available for offline relaunches.
      try {
        return await fetch(request);
      } catch (_) {
        return new Response(
          'BandPlan is unavailable offline. Open the app once while online.',
          { status: 503, headers: { 'Content-Type': 'text/plain; charset=utf-8' } },
        );
      }
    })());
    return;
  }

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(request);
    return cached || fetch(request);
  })());
});
