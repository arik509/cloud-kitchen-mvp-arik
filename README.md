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

Supabase configuration is supplied at compile time through `SUPABASE_URL` and
`SUPABASE_PUBLISHABLE_KEY`. Copy
`config/dart_define.example.json` to `config/dart_define.local.json`, replace
the placeholders locally, and run:

```text
flutter run --dart-define-from-file=config/dart_define.local.json
```

Local define files are ignored by Git. A Supabase publishable key is intended
for client applications and is visible in compiled Flutter apps; authorization
must be enforced with Row Level Security. Never place a Supabase
`service_role` key, database password, or private credential in Flutter client
code or a committed configuration file.

## Demo role policy

This demonstration MVP allows users to select `kitchen_owner` or `rider`
during signup. Production deployments must replace self-selected privileged
roles with an administrator approval and verification workflow.
