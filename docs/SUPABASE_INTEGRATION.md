# Existing Supabase — integration and migration contract

**Status:** discovery required. This document intentionally does not invent a schema.

## Source of truth
The existing BandPlan Supabase project remains the backend for BandPlan 2.0. The legacy repository tihonoveckijan8-dev/grouppp is the reference for current client behavior and data contracts. Its migrations and current schema must be inspected before implementing queries.
Known project reference: oczcjphvzoadfqntoqlc. Confirm project URL and public client key from project configuration before wiring the app. No service-role key belongs in Flutter.

## RPC names observed in legacy client
- bandplan_get_my_groups
- bandplan_set_active_group
- bandplan_create_group
- bandplan_join_group
- bandplan_get_invite_code
- bandplan_leave_group
- bandplan_rename_group
- bandplan_sync_group
- bandplan_set_event_participation
- bandplan_delete_my_account

Inventory only: record exact argument names/types, return shape, authorization, side effects, and error behavior from SQL migrations and live schema. Do not infer contracts from names.

## Required schema audit
For each table/view: exact name, columns/types/defaults/nullability; PK/FK/unique constraints/delete behavior; RLS policies and grants; triggers and side effects; RPC signatures/return types/security mode; Realtime publication/filtering; JSON format/version; offline policy; user/group ownership.

## Legacy behaviors to preserve
- Supabase Auth email/password and Google OAuth.
- Email-confirmation pending state and password reset.
- Per-account local snapshot and durable pending sync queue.
- Personal songs and personal setlists separate from group data.
- Multiple group memberships and active-group switching.
- Group-scoped data and Realtime subscriptions.
- Event participation updates and conflict handling.
- Offline copies of event-related songs.
- Account deletion and membership cleanup.

Preserve externally visible behavior and data compatibility, not browser-specific IndexedDB/localStorage implementation details.

## Compatibility rules
1. Read records before designing Dart models.
2. Preserve nullable and unknown fields when round-tripping legacy JSON.
3. Do not rewrite lyrics/chord content during initial migration.
4. Do not create duplicate auth users.
5. Do not create duplicate groups on onboarding retries.
6. Client-supplied IDs are not authorization proof.
7. Never bypass RLS with privileged credentials.
8. No production schema changes without a separately reviewed migration and explicit approval.

## Required data contract deliverable
Create docs/SUPABASE_DATA_CONTRACT.md with verified details for Auth/profile, groups/memberships, invitations, group state/sync payload, personal state, songs/chord documents, events/participation, setlists/entries, settings/preferences, RPC signatures, RLS, and Realtime.
For every item, cite the source migration/file and mark whether confirmed from migration source, live schema, or runtime behavior.

## Cutover
- Legacy app remains available.
- Flutter initially reads existing data.
- Enable writes feature by feature after compatibility verification.
- No bulk conversion or destructive cleanup in early releases.
- Maintain rollback to legacy client.
- New schema requirements are proposed as additive backward-compatible migrations and reviewed separately.