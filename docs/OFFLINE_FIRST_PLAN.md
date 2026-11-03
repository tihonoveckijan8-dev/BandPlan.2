# BandPlan 2.0 — full Offline-First implementation plan

## Product decision

Keep the existing Supabase project, Supabase Auth/session lifecycle, PostgreSQL tables, RLS policies, RPC names and JSON payload formats. Offline support is a local data and synchronization layer inside the Flutter client; it is not a backend migration.

## Audited starting point

- Group song, event, and setlist repositories currently call Supabase directly for reads and writes.
- Profile reads and writes currently call Supabase directly.
- Riverpod providers expose FutureProviders backed by those remote-only repositories.
- The PWA service worker caches the Flutter application shell and same-origin build assets. It deliberately does not cache Supabase/API traffic.
- The legacy browser application used IndexedDB database `bandplan-cloud-v1` (schema version 3), with snapshots and pending queues. This is a separate application implementation and its data format must not be assumed compatible with the Flutter client.
- The live Supabase contract is documented in `SUPABASE_DATA_CONTRACT.md`; some payload and policy details still require verification.

## Storage choice

Use Sembast as the first Flutter-local persistence layer:
- Native platforms: Sembast file-backed database in the application support directory.
- Flutter Web: `sembast_web` backed by browser IndexedDB.
- Store original JSON payloads instead of prematurely normalizing legacy song/event/setlist fields.
- Scope every cached record and queued operation by authenticated user ID and, where applicable, group ID.
- Keep authentication tokens in Supabase's existing auth storage; do not copy credentials into the offline data store.

This choice is intentionally compatible with the current JSONB data contract and avoids introducing generated SQL schema code before payload semantics are fully audited. Re-evaluate Drift/SQLite only if measured query volume or relational local queries justify it.

## Current implementation status (2026-11-03)

- M1 storage foundation is implemented; automated tests and platform builds are running through GitHub Actions.
- M2 local-first reads are implemented for cached groups/active group, group and personal songs, events, setlists, and profile.
- Refresh failures fall back only for recognized transport errors. Supabase authorization, RLS, validation, and other server errors remain visible.
- After a remote refresh, repositories re-read the reconciled cache so a pending local row or delete tombstone cannot disappear behind an older server snapshot.
- M3 offline mutations are not yet enabled. Existing create/edit/delete writes still use the current online Supabase path until the sync engine can safely own their full lifecycle.

## Milestones

### M1 — storage foundation
- [x] Add a platform-specific persistent database factory.
- [x] Add account/group-scoped cache records.
- [x] Add an atomic local-write + durable mutation-queue primitive.
- [x] Add queue inspection and retry metadata primitives.
- [x] Run Flutter tests and Web/Android builds in CI.

### M2 — local-first reads
- [x] Cache remote snapshots for group songs, events, setlists, profile, personal songs, group list, and active group.
- [x] Render cached data immediately; refresh from Supabase when possible.
- [x] Preserve unknown fields in legacy JSON payloads.
- [x] Never allow one account or group to read another scope's local cache.

### M3 — offline writes
- [ ] Save local edits and enqueue their matching Supabase mutation in one local transaction.
- [ ] Add explicit pending/syncing/synced/failed status.
- [ ] Keep group creation, joining, leaving, invite operations, and other server-authoritative RPCs online-only unless a safe server contract is defined.
- [ ] Do not claim an operation synced until Supabase confirms it.

### M4 — synchronization
- [ ] Drain queued operations after startup, resume, and confirmed network recovery.
- [ ] Retry transient failures with bounded exponential backoff.
- [ ] Make retries idempotent and preserve operation order where required.
- [ ] Reconcile remote refreshes with unsynced local changes; never overwrite a dirty local record with a stale snapshot.
- [ ] Define conflict behavior per entity; do not apply a generic last-write-wins policy to all data.
- [ ] Use Realtime as an invalidation/refresh signal, not as the only sync mechanism.

### M5 — release hardening
- [ ] Test first online launch followed by airplane-mode relaunch.
- [ ] Test offline edits, app termination, and reconnect queue drain.
- [ ] Test account switching and group switching for cache isolation.
- [ ] Test concurrent edits from two devices and server permission failures.
- [ ] Test IndexedDB persistence and Service Worker cache upgrades on GitHub Pages.
- [ ] Test Android persistence and app lifecycle on a physical device.

## Safety rules

1. No production Supabase schema changes are required for the client-side storage foundation.
2. Never bypass Supabase Auth or RLS to make offline UI appear functional.
3. Offline access requires a previously authenticated session and data already cached on that device. A first-time login, invite validation, and server-authoritative group membership changes still require connectivity.
4. Pending writes are device-local until the server acknowledges them; uninstalling or clearing browser storage can remove unsynced work.
5. Never import the legacy browser queue as if it were the Flutter queue without a verified migration.
6. A network-availability indicator is only a hint. Every sync operation must handle request failure independently.
7. No destructive cache replacement while pending local mutations exist.

## Acceptance criteria

- A previously authenticated user can reopen the installed app offline and see previously cached songs, events, and setlists.
- Local edits remain after app restart and are visibly marked pending until confirmed by Supabase.
- Reconnection drains the queue without duplicate records or lost edits.
- Switching accounts/groups never leaks locally cached records across scopes.
- Existing online workflows, Supabase Auth, RLS, RPC contracts, and legacy JSON payloads remain unchanged.
