# Flutter foundation

The initial Flutter application foundation is now present on `main`.

## Current source structure
- `pubspec.yaml` — Flutter package manifest with Riverpod, GoRouter, and Supabase Flutter dependencies.
- `analysis_options.yaml` — Flutter lint configuration.
- `lib/main.dart` — initializes Flutter and Supabase, then starts the Riverpod application.
- `lib/app/bandplan_app.dart` — Material 3 app shell and theme registration.
- `lib/app/router.dart` — initial GoRouter route and route-error fallback.
- `lib/core/theme/bandplan_theme.dart` — light, dark, and AMOLED theme foundations.
- `lib/core/config/app_config.dart` — compile-time Supabase URL and publishable-key configuration.
- `lib/core/supabase/supabase_bootstrap.dart` — Supabase initialization using PKCE.

## Configuration

Pass the public Supabase project URL and publishable key at build time. Do not commit secrets or service-role keys.

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

When configuration is absent, the bootstrap skips Supabase initialization so the shell can still start. Authentication and data access are not implemented yet.

## Important limits
- This is not yet a complete Flutter platform project. Android, iOS, Windows, and macOS runner folders have not been generated.
- Authentication screens, OAuth callbacks, data repositories, realtime subscriptions, and offline synchronization have not been implemented.
- No production database writes, migrations, or schema changes have been made.
- Flutter SDK and dependency resolution have not been run in this environment. Verify with `flutter pub get`, `flutter analyze`, and `flutter test` before treating this foundation as build-verified.

## Next implementation step
Add an explicit auth/session state layer and sign-in, sign-up, password-reset, and email-confirmation flows. Then connect the multi-group workspace workflows to the existing RPC and JSON contracts without changing the live database schema.
