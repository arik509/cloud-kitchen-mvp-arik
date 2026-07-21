# cloud_kitchen_mvp

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Supabase configuration

The current MVP source contains a Supabase project URL and a publishable client
key. A Supabase publishable key is intended for client applications and is not a
`service_role` secret, but keeping project configuration hard-coded makes it
easy to point development builds at the wrong environment.

Before feature development, migrate the URL and publishable key to compile-time
Flutter values such as `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`, supplied
with `--dart-define` or `--dart-define-from-file`. Local define files must remain
untracked. Never place a Supabase `service_role` key, database password, or
other private credential in Flutter client code or a committed configuration
file.
