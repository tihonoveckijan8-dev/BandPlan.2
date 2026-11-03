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
## Android APK signing

The Android workflow supports a persistent upload keystore. Without it, the workflow still creates a test APK, but a later APK may not install as an update over that build.

To enable update-safe releases, create a private JKS/PKCS12 upload keystore locally and add these repository **Actions secrets** under **Settings → Secrets and variables → Actions**:

- `ANDROID_KEYSTORE_BASE64` — base64-encoded keystore file (for example, `base64 -w 0 upload-keystore.jks` on Linux).
- `ANDROID_KEYSTORE_PASSWORD` — keystore password.
- `ANDROID_KEY_ALIAS` — key alias.
- `ANDROID_KEY_PASSWORD` — key password.

Never commit the keystore or passwords. Keep a secure offline backup of the keystore: losing it prevents publishing compatible updates signed with the same key. Once all four secrets are configured, the Android workflow automatically signs release APKs with that key.
