# Flutter foundation

The initial Flutter application foundation and email/password auth flow are present on `main`.

## Current source structure
- `pubspec.yaml` — Flutter package manifest with Riverpod, GoRouter, and Supabase Flutter dependencies.
- `analysis_options.yaml` — Flutter lint configuration.
- `lib/main.dart` — initializes Flutter and Supabase, then starts the Riverpod application.
- `lib/app/bandplan_app.dart` — Material 3 app shell and theme registration.
- `lib/app/router.dart` — initial GoRouter route and route-error fallback.
- `lib/app/auth_gate_page.dart` — checks runtime Supabase configuration and current auth session.
- `lib/core/theme/bandplan_theme.dart` — light, dark, and AMOLED theme foundations.
- `lib/core/config/app_config.dart` — compile-time Supabase URL and publishable-key configuration.
- `lib/core/supabase/supabase_bootstrap.dart` — Supabase initialization using PKCE.
- `lib/features/auth/data/auth_repository.dart` — email/password sign-in, sign-up, password reset, confirmation resend, and sign-out operations.
- `lib/features/auth/application/auth_providers.dart` — Riverpod access to the auth repository and auth-state stream.
- `lib/features/auth/presentation/auth_page.dart` — initial email/password sign-in, sign-up, and password-reset UI.
- `lib/features/groups/data/group_repository.dart` — adapter for the existing list/create/join/activate/invite/leave/rename group RPCs.
- `lib/features/groups/application/group_providers.dart` — Riverpod group repository and membership-list providers.
- `lib/features/groups/presentation/group_workspace_page.dart` — initial group list, create/join dialogs, active-group selection, invite-code copy, and leave action.

## Configuration

Pass the public Supabase project URL and publishable key at build time. Do not commit secrets or service-role keys.

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

When configuration is absent, Supabase initialization is skipped and the app displays a setup message. The auth UI supports email/password operations. OAuth provider setup, deep-link callbacks, and platform-specific redirect configuration are not implemented yet.

## Important limits
- This is not yet a complete Flutter platform project. Android, iOS, Windows, and macOS runner folders have not been generated.
- A successful sign-in opens the initial group workspace. Onboarding and account profile screens are not implemented.
- Realtime subscriptions, data repositories for songs/events/setlists, and offline synchronization have not been implemented.
- No production database writes, migrations, or schema changes have been made.
- Flutter SDK and dependency resolution have not been run in this environment. Verify with `flutter pub get`, `flutter analyze`, and `flutter test` before treating this foundation as build-verified.

## Next implementation step
Harden the group workflow with active-group restoration, typed RPC response models, member roster, group rename, and reliable error states. Then implement the shared song/event/setlist data layer. Preserve the live database schema and existing RPC behavior.
