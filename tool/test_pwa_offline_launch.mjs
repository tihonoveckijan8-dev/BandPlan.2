import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { access, readFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';

const buildRoot = path.resolve(process.argv[2] ?? 'build/web');
const basePath = '/BandPlan.2/';
const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
};

const requiredFiles = ['index.html', 'service-worker.js', 'asset-manifest.json', 'main.dart.js'];
for (const name of requiredFiles) {
  await readFile(path.join(buildRoot, name));
}

const server = createServer(async (request, response) => {
  try {
    const requestUrl = new URL(request.url, 'http://127.0.0.1');
    if (!requestUrl.pathname.startsWith(basePath)) {
      response.writeHead(404).end('Not found');
      return;
    }
    const relative = decodeURIComponent(requestUrl.pathname.slice(basePath.length));
    const requested = relative ? path.resolve(buildRoot, relative) : path.join(buildRoot, 'index.html');
    if (!requested.startsWith(buildRoot + path.sep) && requested !== path.join(buildRoot, 'index.html')) {
      response.writeHead(403).end('Forbidden');
      return;
    }
    let body;
    try {
      body = await readFile(requested);
    } catch (_) {
      response.writeHead(404).end('Not found');
      return;
    }
    response.writeHead(200, {
      'Content-Type': mimeTypes[path.extname(requested)] ?? 'application/octet-stream',
      'Cache-Control': 'no-store',
      'Service-Worker-Allowed': basePath,
    });
    response.end(body);
  } catch (error) {
    response.writeHead(500).end(String(error));
  }
});

await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const address = server.address();
const appUrl = `http://127.0.0.1:${address.port}${basePath}`;
const profileDir = await mkdtemp(path.join(tmpdir(), 'bandplan-pwa-chrome-'));
async function findChrome() {
  const candidates = [
    process.env.CHROME_BIN,
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
  ].filter(Boolean);
  for (const candidate of candidates) {
    try {
      await access(candidate);
      return candidate;
    } catch (_) {}
  }
  throw new Error('Chrome/Chromium executable not found on the CI runner.');
}
const chromePath = await findChrome();
const chrome = spawn(chromePath, [
  '--headless=new',
  '--no-sandbox',
  '--disable-gpu',
  '--disable-dev-shm-usage',
  '--no-first-run',
  '--no-default-browser-check',
  '--disable-background-networking',
  '--remote-debugging-port=0',
  `--user-data-dir=${profileDir}`,
  'about:blank',
], { stdio: ['ignore', 'ignore', 'pipe'] });

let chromeErrors = '';
chrome.stderr.setEncoding('utf8');
chrome.stderr.on('data', (chunk) => { chromeErrors += chunk; });

let browserSocket;
let serverPort;
let nextId = 0;
let sessionId;
const pending = new Map();
const exceptions = [];

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

try {
  const portFile = path.join(profileDir, 'DevToolsActivePort');
  let portData;
  for (let attempt = 0; attempt < 100; attempt++) {
    try {
      portData = await readFile(portFile, 'utf8');
      break;
    } catch (_) {
      if (chrome.exitCode != null) throw new Error('Chrome exited: ' + chromeErrors);
      await delay(100);
    }
  }
  assert.ok(portData, 'Chrome DevTools did not start: ' + chromeErrors);
  [serverPort] = portData.trim().split('\n');
  const wsPath = portData.trim().split('\n')[1];
  browserSocket = new WebSocket(`ws://127.0.0.1:${serverPort}${wsPath}`);

  await new Promise((resolve, reject) => {
    browserSocket.addEventListener('open', resolve, { once: true });
    browserSocket.addEventListener('error', reject, { once: true });
  });

  browserSocket.addEventListener('message', (event) => {
    const message = JSON.parse(event.data);
    if (message.method === 'Runtime.exceptionThrown') {
      exceptions.push(message.params.exceptionDetails.text || 'Uncaught browser exception');
    }
    if (message.id && pending.has(message.id)) {
      const { resolve, reject } = pending.get(message.id);
      pending.delete(message.id);
      if (message.error) reject(new Error(message.error.message));
      else resolve(message.result ?? {});
    }
  });

  function command(method, params = {}, useSession = true) {
    const id = ++nextId;
    const payload = { id, method, params };
    if (useSession && sessionId) payload.sessionId = sessionId;
    browserSocket.send(JSON.stringify(payload));
    return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
  }

  const { targetId } = await command('Target.createTarget', { url: 'about:blank' }, false);
  const attached = await command('Target.attachToTarget', { targetId, flatten: true }, false);
  sessionId = attached.sessionId;
  await command('Page.enable');
  await command('Runtime.enable');
  await command('Network.enable');
  await command('ServiceWorker.enable');

  await command('Accessibility.enable');

  // WHY: A signed-in session must survive a cold offline relaunch too.
  // Use a local, unexpired fixture session; it is never sent to Supabase.
  const projectUrl = process.env.SUPABASE_URL;
  assert.ok(projectUrl, 'SUPABASE_URL is required for the auth storage key');
  const projectRef = new URL(projectUrl).hostname.split('.')[0];
  const userId = '00000000-0000-4000-8000-000000000042';
  const expiresAt = Math.floor(Date.now() / 1000) + 3600;
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const token = [
    encode({ alg: 'HS256', typ: 'JWT' }),
    encode({
      aud: 'authenticated',
      role: 'authenticated',
      sub: userId,
      exp: expiresAt,
      iat: expiresAt - 3600,
      email: 'offline-test@bandplan.invalid',
      app_metadata: { provider: 'email', providers: ['email'] },
      user_metadata: { bandplan_onboarding_done: true },
    }),
    'offline-test-signature',
  ].join('.');
  const fixtureSession = {
    access_token: token,
    token_type: 'bearer',
    expires_in: 3600,
    expires_at: expiresAt,
    refresh_token: 'offline-test-refresh-token',
    user: {
      id: userId,
      aud: 'authenticated',
      role: 'authenticated',
      email: 'offline-test@bandplan.invalid',
      app_metadata: { provider: 'email', providers: ['email'] },
      user_metadata: { bandplan_onboarding_done: true },
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    },
  };
  await command('Page.addScriptToEvaluateOnNewDocument', {
    source: `localStorage.setItem(${JSON.stringify('sb-' + projectRef + '-auth-token')}, ${JSON.stringify(JSON.stringify(fixtureSession))});`,
  }, false);

  async function evaluate(expression) {
    const result = await command('Runtime.evaluate', {
      expression,
      returnByValue: true,
      awaitPromise: true,
      userGesture: true,
    });
    if (result.exceptionDetails) {
      throw new Error(result.exceptionDetails.text || 'Browser evaluation failed');
    }
    return result.result?.value;
  }

  async function waitFor(expression, description, timeoutMs = 60000) {
    const started = Date.now();
    while (Date.now() - started < timeoutMs) {
      try {
        if (await evaluate(expression)) return;
      } catch (_) {}
      await delay(250);
    }
    throw new Error('Timed out waiting for ' + description);
  }

  await command('Page.navigate', { url: appUrl });
  await waitFor(
    'localStorage.getItem(' + JSON.stringify('sb-' + projectRef + '-auth-token') + ') !== null && !!document.querySelector("flt-glass-pane")',
    'Flutter startup with a persisted signed-in session',
  );
  await waitFor(
    'document.querySelectorAll("flt-semantics").length > 0',
    'Flutter accessibility semantics for the signed-in app',
    10000,
  ).catch(() => {});
  await waitFor(
    'document.readyState === "complete" && !!document.querySelector("flt-glass-pane")',
    'Flutter app shell on first online launch',
  );

  // WHY: Checking the accessibility tree distinguishes the signed-in app
  // from a Flutter shell that merely rendered the email/password screen.
  const signedInTree = await command('Accessibility.getFullAXTree');
  const signedInNames = signedInTree.nodes
    .map((node) => node.name?.value ?? '')
    .filter(Boolean);
  assert.ok(
    signedInNames.includes('Календарь'),
    'The persisted session must pass AuthGate and expose the calendar navigation',
  );
  await evaluate('navigator.serviceWorker.ready.then(() => true)');
  const registration = await evaluate(
    'navigator.serviceWorker.getRegistration().then(r => ({scope:r.scope, state:r.active?.state}))',
  );
  assert.equal(registration.scope, appUrl, 'Service Worker scope must match the GitHub Pages project path');
  assert.equal(registration.state, 'activated', 'The initial worker must finish installation before offline relaunch');

  // WHY: The first document was opened before the worker finished installing.
  // Leaving that client and opening a fresh navigation guarantees Chromium
  // creates a page under the already-active worker's control.
  await command('Page.navigate', { url: 'about:blank' });
  await delay(250);
  await command('Page.navigate', { url: appUrl });
  await waitFor(
    '!!navigator.serviceWorker.controller && !!document.querySelector("flt-glass-pane")',
    'a fresh app navigation controlled by the installed Service Worker',
  );
  const cachedMain = await evaluate(
    'caches.keys().then(async keys => { for (const key of keys) { const cache = await caches.open(key); if (await cache.match(new URL("main.dart.js", location.href))) return true; } return false; })',
  );
  assert.equal(cachedMain, true, 'The app shell cache must contain main.dart.js');

  await command('Network.emulateNetworkConditions', {
    offline: true,
    latency: 0,
    downloadThroughput: 0,
    uploadThroughput: 0,
    connectionType: 'none',
  });
  await command('Page.reload', { ignoreCache: true });
  await waitFor(
    '!!navigator.serviceWorker.controller && !!document.querySelector("flt-glass-pane") && performance.getEntriesByType("resource").some(e => e.name.endsWith("/main.dart.js"))',
    'Flutter to relaunch from the installed PWA cache while offline',
  );

  const offlineTree = await command('Accessibility.getFullAXTree');
  const offlineNames = offlineTree.nodes
    .map((node) => node.name?.value ?? '')
    .filter(Boolean);
  assert.ok(
    offlineNames.includes('Календарь'),
    'The persisted session must still pass AuthGate after offline relaunch',
  );
  assert.deepEqual(exceptions, [], 'Offline relaunch must not throw browser exceptions');
  console.log('Real Chromium PWA check passed: install, control, and relaunch Flutter from cache with network disabled.');
} finally {
  try { browserSocket?.close(); } catch (_) {}
  chrome.kill('SIGTERM');
  await new Promise((resolve) => {
    if (chrome.exitCode != null) resolve();
    else {
      chrome.once('exit', resolve);
      setTimeout(resolve, 3000);
    }
  });
  await new Promise((resolve) => server.close(resolve));
  await rm(profileDir, { recursive: true, force: true });
}
