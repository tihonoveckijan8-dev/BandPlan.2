# Flutter foundation

The initial Flutter source scaffold has been started on `main`.

## Current files
- `pubspec.yaml` — Flutter package manifest with Riverpod, GoRouter, and Supabase Flutter dependencies.
- `lib/main.dart` — minimal application entry point and initial BandPlan screen.

## Important limits
- This is not yet a complete Flutter platform project. Android, iOS, Windows, and macOS runner folders have not been generated.
- Supabase initialization, authentication, OAuth callbacks, data repositories, and offline synchronization have not been implemented.
- No production database writes or schema changes have been made.
- Flutter SDK, dependency resolution, analysis, and tests have not been run in this environment. Verify with `flutter pub get`, `flutter analyze`, and `flutter test` before expanding the scaffold.

The next implementation step is to establish the theme, routing, runtime configuration, and Supabase bootstrap, then add authentication and group-workspace workflows against the audited contracts.
