# BandPlan 2.0 — application architecture

## Goals
- One Flutter codebase for Android, iOS, Windows, macOS, and Web.
- Feature-first organization with domain/data/presentation boundaries.
- Existing Supabase remains the backend and source of truth.
- No legacy schema changes as part of routine client work.
- Testable business logic independent of widgets.
- Responsive UI and shared design tokens.
- Offline behavior introduced entity by entity.

## Proposed stack
- Flutter stable / Dart stable; pin exact SDK.
- supabase_flutter for Auth, Postgres Data API, Realtime, and RPC.
- Riverpod for dependency injection/state.
- go_router for navigation/deep links.
- Flutter foundations plus custom BandPlan design system.
Use stable compatible package versions, not prereleases, unless explicitly approved.

## Feature-first layout
lib/
  app/ (app.dart, bootstrap.dart, router/, lifecycle/)
  core/ (config/, errors/, logging/, network/, permissions/, responsive/, theme/, widgets/)
  data/ (supabase/, local/, sync/)
  features/
    auth/ (data/, domain/, presentation/)
    onboarding/
    workspaces/
    calendar/
    songs/
    setlists/
    stage/
    tools/
    profile/
    settings/
  main.dart
assets/ (fonts/, icons/, audio/)
test/ (unit/, widget/, integration/)

Each feature may contain domain entities/value objects, repository interfaces, use cases, data models/mappers, Supabase/local implementations, providers, screens/widgets, and tests.

## Data flow
UI → feature controller/provider → use case/domain rule → repository interface → Supabase/local data source.
Widgets must not issue raw Supabase queries. Repositories own query/RPC details. Mappers translate legacy shapes into domain models; domain models do not need to mirror database naming.

## Auth and workspace context
Supabase Auth owns identity/session lifecycle. A session provider observes auth changes. Profile and membership repositories load account context. Workspace state resolves active group using verified legacy behavior. Switching group invalidates group-scoped providers and Realtime subscriptions. Personal data remains independent. Group queries are scoped and protected by RLS.

## Supabase boundary
One configured client. Project URL and public anon/publishable key are build-time configuration. Never ship service-role credentials.
For every table/view/RPC record schema, keys, nullability/defaults, RLS/grants, triggers, result shape, ownership, offline policy, and legacy JSON mapping.

## Offline and Realtime
Do not build a generic sync engine before entity semantics are understood. For each entity define cache, local format, queue operation, idempotency, retry, conflict resolution, deletion/tombstone, and Realtime invalidation. Realtime is not a substitute for durable writes. Queued mutations must be safely retryable.

## Audio/platform services
Wrap microphone, audio playback, keep-screen-awake, file picker, and file storage behind platform interfaces. Handle permissions, app lifecycle, route changes, and disposal. Keep DSP separate from widgets.

## Design system
Centralized color/spacing/radius/elevation/type tokens; Manrope after licensed assets are copied; light/dark/AMOLED; blue default #1554FF; soft-clay depth without glass blur/decorative gradients; responsive navigation; participation colors stable across themes.

## Quality gates
dart format; flutter analyze; unit tests for domain/mappers; widget tests for forms/navigation/states; integration tests for Auth/workspace/core flows in a safe environment; platform build checks. Never run destructive tests against production data.

## Security
Use only anon/publishable key in clients. Enforce authorization through RLS/server RPCs, not hidden controls. Do not log tokens, passwords, auth links, or private song content. Never commit secrets or real user records.