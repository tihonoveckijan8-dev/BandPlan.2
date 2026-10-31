# Legacy-to-Flutter migration map

**Status:** discovery artifact, based on the legacy client and read-only live Supabase catalog inspection on 2026-10-31. This is not an import script and does not authorize production writes.

## 1. Identity and workspace

| Legacy concept | Live source | Flutter domain | Notes |
|---|---|---|---|
| Authenticated user | Supabase Auth | `UserIdentity` | UUID is authoritative; email is not a stable ID. |
| Account display name and roles | `bandplan_accounts` | `AccountProfile` | Fields: `display_name`, `roles[]`, `personal_settings`. |
| Workspace | `bandplan_groups` | `BandGroup` | UUID ID, name, owner ID. |
| Membership | `bandplan_group_members` | `GroupMembership` | Composite identity (group ID, user ID); users can belong to many groups. |
| Active workspace | `bandplan_user_state.state.activeGroupId` | `ActiveGroupSelection` | User preference, not membership proof. Always verify membership with backend. |
| Roster snapshot | `bandplan_group_state.state.members[]` | `GroupRosterSnapshot` | Cache/presentation only; authoritative membership is the membership table/RPC. |
| Invite | `bandplan_group_invites` + RPC | `GroupInvite` | Create/join/leave/rename via existing RPCs; no direct client table mutation. |

## 2. Personal and group collections

| Concept | Personal scope | Group scope | Reference behavior |
|---|---|---|---|
| Songs | `user_state.state.personalSongs[]` | `bandplan_songs.data` / group state `songs[]` | Independent records; copying between scopes creates a new ID. |
| Setlists | `user_state.state.personalSetlists[]` | `bandplan_setlists.data` / group state `setlists[]` | Items contain `songId`; resolve within same scope. |
| Events | No personal event collection verified | `bandplan_events.data` / group state `events[]` | Group events only in inspected client hydration. |
| Participation | Not personal collection data | `bandplan_event_participation` | Separate row per group/event/user; statuses yes/maybe/no. |

## 3. Song import shape

Fields directly observed in UI use:
- Required identity/content candidates: `id`, `title`, `lyrics`.
- Common optional fields: `artist`, `key`, `fav`, `dynamics`, `tags`.
- Copy/provenance fields observed: `groupSourceId`, `personalSourceId`, `addedAt`.

Import rule: retain the original JSON object, including unrecognized keys. Preserve the exact `lyrics` string. The legacy format stores chord tokens inline as `[Chord]` and supports chord-only rows; section headings such as `[Куплет]` are not chords. A future typed representation must distinguish section markers, chord anchors, and lyric text and serialize back without changing whitespace or line breaks.

## 4. Event import shape

Events are stored as JSON objects in the group event collection. Verified compatibility fields:
- `id` is used as the event identity.
- `participation` may exist as a legacy per-user map in event JSON.
- `myStatus` is a client convenience field and may be overlaid during hydration.
- Normalized participation is stored separately and returned by the cloud adapter.

Import rule: keep unknown event fields. Do not trust JSON `participation` or `myStatus` as the source of truth when normalized participation rows are available.

## 5. Setlist import shape

- Setlists have an `id` and `items[]`.
- Each item references a song using `songId`.
- Template conversion/import copies songs into the destination scope and rewrites `songId` to the copied song's new ID.
- This is a deliberate independent-copy workflow, not a live foreign-key relationship between personal and group libraries.

Import rule: preserve setlist/item unknown fields and validate all song references within the correct scope. Report unresolved references instead of silently dropping items.

## 6. Preferences

Legacy user state includes `profile`, `settings`, `onboardingDone`, `personalSongs`, and `personalSetlists`. The settings keys currently observed are documented in [SUPABASE_DATA_CONTRACT.md](SUPABASE_DATA_CONTRACT.md).

Import rule: map known preferences explicitly; preserve unknown keys in a compatibility payload until their disposition is decided. The new app may use a refreshed design system, but should not silently erase stored preferences.

## 7. Backend operations that must remain server-mediated

Use existing authenticated RPCs for:
- listing memberships and selecting active group;
- creating/joining/leaving/renaming a group and managing invite codes;
- syncing group song/event/setlist deltas;
- changing event participation;
- deleting the account (after a separate full body/security review).

Do not implement direct client writes to membership, invite, ownership, or recycle-bin tables. Do not call admin cleanup or metadata RPCs from the client.

## 8. Migration safety sequence

1. Read the authenticated user's state and memberships.
2. Load personal collections separately from the selected group's collections.
3. Preserve raw JSON and lyrics before mapping typed fields.
4. Resolve setlist references within their source scope.
5. Hydrate normalized event participation independently.
6. Write only through verified RPC/repository contracts.
7. Re-read and compare counts/IDs after any future migration write.
8. Never delete or overwrite legacy data as part of the first Flutter rollout.

## 9. Remaining discovery blockers

- Exact exhaustive song/event/setlist JSON shapes and all editor write paths.
- Full `bandplan_create_group`, `bandplan_create_group_and_invite`, invite retrieval, account deletion, and cleanup function bodies.
- Auth provider settings and native deep-link allowlists.
- Recycle-bin server-side workflows and retention policy.
- Full offline queue semantics and safe conflict resolution.
