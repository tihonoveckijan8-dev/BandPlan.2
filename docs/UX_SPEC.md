# BandPlan 2.0 — UX and functional specification

**Status:** baseline draft; reconcile against legacy behavior before implementation.  
**Platforms:** Android, iOS, Windows, macOS, Web.  
**Backend:** existing BandPlan Supabase project.

## Product principles
- BandPlan is a music-group workspace, not a generic calendar or songbook.
- Active workspace is explicit; group data never leaks across workspaces.
- Personal content and group-shared content remain separate.
- Stage mode prioritizes readability and uninterrupted performance.
- Every data flow defines loading, empty, error, offline, saving, and synced states.
- Support touch, mouse, keyboard, and different window sizes.
- Preserve the visual direction: Manrope, soft-clay depth, no glass/blur surfaces, light/dark/AMOLED themes, blue default accent #1554FF, semantic participation colors.

## Information architecture
Primary: Calendar, Songs, Setlists, Tools, More.
Global: current workspace selector, profile, global search/create where appropriate, sync/offline status.
Secondary: Stage mode, group members/invitations, profile, appearance/settings.
Phone: compact bottom navigation and More surface. Tablet: navigation rail/adaptive sidebar. Desktop: persistent sidebar and flexible content area. Preserve drafts across navigation where expected.

## Authentication and onboarding
- Email/password sign-up and sign-in.
- Email confirmation pending state.
- Google OAuth.
- Password reset/update.
- Session restoration/expiry.
- Sign-out and account deletion subject to verified backend behavior.

Sign-up: collect name/email/password; validate; create Supabase Auth user; show confirmation-pending state if required; restore session after confirmation; load profile/memberships; continue onboarding only if legacy onboarding flag is incomplete.

Sign-in: authenticate; restore session; load profile and memberships; resolve active workspace; load workspace data; open last valid destination or Calendar.

Distinguish invalid credentials, unconfirmed email, rate limit, network failure, OAuth cancellation/failure, expired session, and profile/data loading failure.

Onboarding captures only fields supported by the existing data contract. It must be resumable and must not create duplicate workspaces on retry.

## Workspaces and groups
- List all groups the user belongs to and identify the active group.
- Switch group; refresh group-scoped Calendar, Songs, Setlists, members, and Realtime.
- Personal library and account preferences remain independent of active group.
- Create group, join by invite code, retrieve/share invite code, rename, view members, leave group.
- Account deletion must correctly clean up memberships.
- Use existing RPCs after exact signatures/side effects are verified.
- Leaving one group must not remove other memberships. Failed operations must not leave stale client state.

## Calendar and events
Views: month, week, day; previous/next; Today; date selection; search and filters.
Event types must be reconciled against legacy values. Candidate UX categories: rehearsal, concert/gig, recording, meeting, other.
Candidate fields to verify: title, type, start/end, location, description, recurrence, linked setlist, participation.
Actions: create/edit/view/delete; set participation (yes/maybe/no if confirmed); view member responses; open linked setlist; launch Stage mode.
Recurrence must distinguish one occurrence from a series only if backend supports it.
States: loading, empty, filtered-empty, offline, save pending, saved, error.

## Songs
Separate group repertoire and personal song library. Never merge them implicitly.
List actions: search, sort/filter by supported fields, open/edit, add to setlist, Stage mode, per-song metronome.
Candidate fields to verify: title, artist, key, BPM, duration, tags, lyrics/chords, sections, dynamics, instrument notes.
Chord anchoring must not depend on whitespace. Use a structured document with explicit lyric segments and chord anchors; import legacy format through a compatibility parser. Preserve original source until round-trip compatibility is proven.
Transposition: keep source immutable; calculate a derived view; support enharmonic spelling and notation preferences; avoid cumulative drift.
Song sections and instrument notes are implemented only where legacy data supports them.

## Setlists
Group setlists and personal templates are separate scopes.
Create/edit/duplicate/delete/search; add/remove/reorder songs; per-entry transpose/notes only if supported; calculate song count and estimated duration; represent unknown duration as unknown; link to event; open in Stage mode.

## Stage mode
Display current song/position, lyrics/chord anchors, key/transpose, BPM/duration when available, notes, previous/next.
Controls: font size, auto-scroll speed/start/pause/resume/stop, manual scroll, previous/next, transpose, chord visibility.
Large non-overlapping controls; safe-area aware; keep screen awake where supported; avoid accidental exit; dispose timers/audio/controllers; tolerate missing/offline songs.

## Music tools
Guitar tuner: microphone permission, real-time pitch/frequency, note/cents deviation, flat/in-tune/sharp, standard E2-A2-D3-G3-B3-E4, reference string playback, stop mic on route/background.
Violin tuner: same lifecycle, standard G3-D4-A4-E5.
Metronome: tempo, start/stop, subdivisions, time signature, accent pattern, visual beat, per-song settings if supported.
Chord libraries: guitar diagrams/fingering/open/muted strings; piano keyboard and highlighted chord notes.
Audio-file BPM, changing-tempo, and time-signature analysis is a separate future capability, not assumed stable legacy behavior.

## Profile and settings
Profile identity and musician roles; light/dark/AMOLED; accent; typography/stage preferences; reduced motion/accessibility; note naming if supported; offline storage management; account actions.
Persist only in existing profile/settings contract unless a separately approved migration is made.

## Offline and sync
Cached read access to selected content; durable offline edit queue; visible pending/synced/failed state; retry after reconnect; Realtime updates; per-entity conflict policy; no silent data loss.
Do not assume every entity is safe for offline writes. Define write policy after reviewing RLS, RPCs, triggers, and concurrency.

## Global interaction/accessibility
Consistent dialogs/sheets/confirmations/snackbars; confirm destructive actions; preserve form values on recoverable errors; desktop keyboard focus/shortcuts; screen-reader labels/scalable text; safe areas/reduced motion; actionable empty states; retry only when safe.

## Acceptance baseline
A screen is not complete until loading/success/empty/error/offline states, ownership/scope, permissions, destructive actions, phone/tablet/desktop layouts, accessibility, backend mappings, and success/failure tests are specified.