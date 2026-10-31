# BandPlan 2.0

A new cross-platform Flutter application for managing a music group: calendar, repertoire, setlists, stage mode, musician tools, and group workspaces.

## Product direction
- New Flutter application in this repository, independent from legacy grouppp.
- Reuse the existing BandPlan Supabase project and data; do not create a replacement database.
- Preserve existing accounts, memberships, songs, events, setlists, and personal data.
- Keep the legacy app operational during development.
- Target Android, iOS, Windows, macOS, and Web.

## Project status
Phase 0 — product and backend discovery. See:
- [Roadmap](docs/ROADMAP.md)
- [UX specification](docs/UX_SPEC.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Supabase integration](docs/SUPABASE_INTEGRATION.md)

## Data safety rules
1. No production schema changes without an explicit, reviewed migration and approval.
2. Never commit secrets, service-role keys, or real user data.
3. Respect existing Supabase RLS and RPC contracts.
4. Verify tables, columns, RPC signatures, and policies before implementing repositories.
5. Preserve legacy song/chord formats and unknown fields during initial compatibility work.

## Planned stack
Flutter/Dart, supabase_flutter, Riverpod, go_router, feature-first architecture. Exact versions and platform scaffolding are set in Phase 1 after checking the available Flutter SDK.