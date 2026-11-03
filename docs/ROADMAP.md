# BandPlan 2.0 — roadmap

## Goal
Rebuild BandPlan from scratch in Flutter while reusing the existing Supabase project, accounts, and records. The legacy grouppp app remains operational during migration.

## Rules
- This repository is the new application; grouppp is the legacy reference.
- No unapproved production schema changes.
- Small milestones with observable acceptance criteria.
- Never commit secrets or production user data.
- Do not mark a feature complete until verified on target platforms.

## Phase 0 — product and backend discovery
- [x] Confirm new repository and main branch.
- [x] Establish scope and migration principles.
- [x] Add initial UX, architecture, and Supabase integration docs.
- [ ] Inventory every legacy screen, action, form, and UI state.
- [ ] Audit exact tables, columns, constraints, indexes, RLS, triggers, RPCs, and Realtime.
- [ ] Document song/chord/setlist/event payload formats.
- [ ] Resolve open product decisions.
Exit: verified UX inventory and backend contract.

## Phase 1 — Flutter foundation
- [ ] Generate Flutter platform folders for Android, iOS, Windows, macOS, and Web.
- [ ] Pin Flutter/Dart and package versions.
- [ ] Add format/analyze/test CI.
- [ ] Add safe build-time environment configuration.
- [ ] Add bootstrap, theme tokens, responsive layout, routing, and error handling.
- [ ] Initialize Supabase using the existing project and public client key.
- [ ] Verify session restoration without changing existing records.
Exit: clean supported builds and safe connection to existing Supabase.

## Phase 2 — identity and workspaces (P0)
- [ ] Email/password, confirmation, reset, Google OAuth.
- [ ] Session restoration and expiry.
- [ ] Profile and onboarding.
- [ ] List/switch/create/join/leave/rename groups using verified RPC contracts.
- [ ] Membership roles and permissions.
Exit: existing users see their current groups and profile; no duplicate accounts/groups.

## Phase 3 — core music workflows (P1)
- [ ] Calendar and event CRUD.
- [ ] Participation and conflict handling.
- [ ] Group and personal song libraries.
- [ ] Song editor with structured chord anchors.
- [ ] Transposition.
- [ ] Group/personal setlists and event links.
Exit: core workflows work with existing records without destructive conversion.

## Phase 4 — performance and tools (P2)
- [ ] Stage mode and performance settings.
- [ ] Guitar and violin tuners.
- [ ] Metronome.
- [ ] Guitar/piano chord libraries.
- [ ] Audio tempo/time-signature analysis as a separately scoped feature.
Exit: real-device performance workflows and correct audio resource lifecycle.

## Phase 5 — offline and polish (P3)
- [x] Cross-platform local database (IndexedDB on Web, file-backed storage on native).
- [x] Local-first repositories for songs, events, setlists, profile, and group snapshots.
- [ ] Durable, account-scoped mutation queue with idempotent operation IDs.
- [ ] Sync engine with retry/backoff, server reconciliation, and per-entity conflict policies.
- [ ] Realtime invalidation without treating Realtime as durable sync.
- [ ] Themes, accessibility, export, diagnostics.
- [ ] Airplane-mode, restart, multi-device, and platform QA.
Exit: cached data remains readable offline and offline edits are durably queued without changing the Supabase schema or auth contract.

## Phase 6 — release
- [ ] Android, iOS, Windows, macOS packages.
- [ ] Web build and hosting decision.
- [ ] Signing, store metadata, privacy disclosures.
- [ ] Staged rollout while legacy remains available.

## Immediate next tasks
1. Complete legacy UX inventory.
2. Complete Supabase schema/RPC/RLS audit.
3. Freeze first data contracts.
4. Generate Flutter scaffold.
5. Implement Auth and workspace selection first.