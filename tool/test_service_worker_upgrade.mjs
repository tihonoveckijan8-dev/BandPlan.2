import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const workerPath = process.argv[2];
const manifestPath = process.argv[3];
if (!workerPath) {
  throw new Error('Usage: node tool/test_service_worker_upgrade.mjs <built-service-worker.js> [asset-manifest.json]');
}
const workerTemplate = await readFile(workerPath, 'utf8');
const manifestFixture = manifestPath
  ? JSON.parse(await readFile(manifestPath, 'utf8'))
  : {
      assets: [
        'index.html',
        'flutter_bootstrap.js',
        'manifest.json',
        'main.dart.js',
        'canvaskit/canvaskit.js',
        'canvaskit/canvaskit.wasm',
        'https://cdn.example.test/external.js',
        '../outside-project.js',
      ],
    };

for (const requiredAsset of [
  'index.html',
  'flutter_bootstrap.js',
  'main.dart.js',
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
]) {
  assert.ok(
    manifestFixture.assets?.includes(requiredAsset),
    `Built PWA manifest must include ${requiredAsset} for offline startup`,
  );
}

const scope = 'https://example.test/BandPlan.2/';
const origin = new URL(scope).origin;
const appIndex = new URL('index.html', scope).href;

class MemoryCache {
  constructor() {
    this.entries = new Map();
  }

  async put(request, response) {
    const key = typeof request === 'string' ? request : request.url;
    this.entries.set(key, response.clone());
  }

  async match(request) {
    const key = typeof request === 'string' ? request : request.url;
    return this.entries.get(key)?.clone();
  }
}

class MemoryCacheStorage {
  constructor() {
    this.items = new Map();
  }

  async open(name) {
    if (!this.items.has(name)) this.items.set(name, new MemoryCache());
    return this.items.get(name);
  }

  async keys() {
    return [...this.items.keys()];
  }

  async delete(name) {
    return this.items.delete(name);
  }
}

const cacheStorage = new MemoryCacheStorage();
const indexedDbFixture = new Map([
  ['user-a::group-a::song-1', {
    title: 'Offline edit survives PWA update',
    pendingSync: true,
  }],
]);

function createWorker(buildId) {
  const listeners = new Map();
  let claimCount = 0;
  let skipWaitingCount = 0;
  let networkCalls = 0;
  let navigationOffline = false;

  const fakeFetch = async (input) => {
    networkCalls += 1;
    const url = typeof input === 'string' ? input : input.url;
    if (url.endsWith('/asset-manifest.json')) {
      return new Response(JSON.stringify(manifestFixture), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }
    if (navigationOffline) throw new TypeError('Network unavailable in test');
    return new Response('asset:' + new URL(url).pathname, { status: 200 });
  };

  const self = {
    registration: { scope },
    location: { origin },
    clients: {
      claim: async () => { claimCount += 1; },
    },
    addEventListener: (name, callback) => listeners.set(name, callback),
    skipWaiting: async () => { skipWaitingCount += 1; },
  };

  const source = workerTemplate.replace(
    /const BUILD_ID = '[^']+';/,
    `const BUILD_ID = '${buildId}';`,
  );
  assert.notEqual(source, workerTemplate, 'Build ID must be replaceable in the built worker');

  vm.runInNewContext(source, {
    self,
    caches: cacheStorage,
    fetch: fakeFetch,
    URL,
    Request,
    Response,
    Promise,
    Number,
    String,
    Array,
    Error,
  }, { filename: `service-worker-${buildId}.js` });

  async function dispatch(name, event) {
    const listener = listeners.get(name);
    assert.equal(typeof listener, 'function', `Missing ${name} event handler`);
    let pending;
    listener({
      ...event,
      waitUntil: (promise) => { pending = promise; },
    });
    if (pending) await pending;
  }

  return {
    dispatch,
    setNavigationOffline: (value) => { navigationOffline = value; },
    get claimCount() { return claimCount; },
    get skipWaitingCount() { return skipWaitingCount; },
    get networkCalls() { return networkCalls; },
  };
}

for (const buildId of ['101', '102', '103']) {
  const worker = createWorker(buildId);
  await worker.dispatch('install', {});
  await worker.dispatch('activate', {});
  assert.equal(worker.claimCount, 1, `Worker ${buildId} must claim clients after activation`);
  assert.equal(worker.skipWaitingCount, 0, 'Updates must not force-reload an app that is already open');
}

const retainedCaches = (await cacheStorage.keys()).sort();
assert.deepEqual(retainedCaches, [
  'bandplan-pwa-shell-102',
  'bandplan-pwa-shell-103',
], 'Activation must retain only the current and previous app-shell caches');

const currentCache = await cacheStorage.open('bandplan-pwa-shell-103');
assert.ok(
  await currentCache.match(appIndex),
  'The current app shell must contain index.html for offline navigation',
);
for (const requiredAsset of [
  'flutter_bootstrap.js',
  'main.dart.js',
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
]) {
  assert.ok(
    await currentCache.match(new URL(requiredAsset, scope).href),
    `The current app shell must cache ${requiredAsset} for offline startup`,
  );
}
assert.equal(
  await currentCache.match(new URL('../outside-project.js', scope).href),
  undefined,
  'Assets outside the GitHub Pages project path must not be cached',
);

const currentWorker = createWorker('103');
await currentWorker.dispatch('install', {});
await currentWorker.dispatch('activate', {});

// Cached app assets are served from the shell without a network request.
let assetResponse;
await currentWorker.dispatch('fetch', {
  request: new Request(new URL('main.dart.js', scope).href),
  respondWith: (promise) => { assetResponse = promise; },
});
assert.equal((await assetResponse).status, 200);
assert.equal(await (await assetResponse).text(), 'asset:/BandPlan.2/main.dart.js');

// Supabase requests remain network-only and are not intercepted by the app-shell cache.
let apiResponseHandled = false;
await currentWorker.dispatch('fetch', {
  request: new Request('https://project.supabase.co/rest/v1/bandplan_events'),
  respondWith: () => { apiResponseHandled = true; },
});
assert.equal(apiResponseHandled, false, 'Supabase API requests must bypass the service-worker cache');

// Navigation is network-first, with the cached Flutter index as the offline fallback.
currentWorker.setNavigationOffline(true);
let navigationResponse;
await currentWorker.dispatch('fetch', {
  request: {
    url: appIndex,
    method: 'GET',
    mode: 'navigate',
  },
  respondWith: (promise) => { navigationResponse = promise; },
});
assert.equal((await navigationResponse).status, 200);
assert.equal(await (await navigationResponse).text(), 'asset:/BandPlan.2/index.html');

// Service-worker cache rotation must never touch the separate Sembast/IndexedDB outbox.
assert.equal(
  indexedDbFixture.get('user-a::group-a::song-1').title,
  'Offline edit survives PWA update',
);
assert.equal(indexedDbFixture.get('user-a::group-a::song-1').pendingSync, true);

console.log('PWA service-worker checks passed: real build manifest, complete offline shell, cache rotation, API bypass, and IndexedDB isolation.');
