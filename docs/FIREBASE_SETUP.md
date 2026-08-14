# Firebase Cloud Messaging setup

The Phase 7 notification code is deliberately disabled until valid Firebase
client and server configuration is provided. Chat and all other app features
continue to work when notification setup is absent.

## Android client configuration

1. Create or select a Firebase project and register an Android app with the
   package name `com.cloudkitchen.cloud_kitchen_mvp`.
2. Download its `google-services.json` to `android/app/google-services.json`.
   This local file is ignored by Git in this repository.
3. Enable the Firebase Cloud Messaging API (HTTP v1) for that project.

The Android Gradle build applies the Google Services plugin automatically only
when that file exists. Never substitute a service-account file for
`google-services.json`.

## Supabase server configuration

Create a least-privilege Google service account that can send FCM messages,
download its JSON once, and add the complete JSON document as the Supabase Edge
Function secret `FIREBASE_SERVICE_ACCOUNT_JSON`. Never place that JSON file in
Flutter, this repository, or `config/dart_define.local.json`.

Deploy `send-chat-notification` with JWT verification enabled. The function
authenticates the sender, reads the server-derived event/recipient, and sends
through FCM HTTP v1. It cannot accept a recipient ID from Flutter.

## Physical verification before release

Use separate authenticated Customer and Kitchen Owner Android devices. Verify
both directions, notification taps, background delivery, and terminated-app
delivery for the same eligible order chat. A Phase 7 release must not be made
until these checks pass.
