# FoodCircle

FoodCircle is a Flutter marketplace MVP connecting customers, independent
cloud kitchens, and delivery riders. It targets Android and Web and uses
Supabase for authentication, PostgreSQL, Row Level Security, Storage, database
RPCs, and notification events. Firebase Cloud Messaging provides Android push
notifications.

## Product features

### Customers

- Sign up, sign in, and manage a private profile with Bangladesh phone-number
  validation.
- Grant location permission and discover active kitchens within a configurable
  10 km radius, calculated and sorted in Flutter with the Haversine formula.
- View available menu items, images, ratings, prices, and supported payments.
- Order one distinct menu item with a quantity from 1 to 20, a delivery address,
  and a confirmed map location.
- Pay by manually submitted bKash transaction ID or Cash on Delivery.
- Track separate order and payment states, chat with the kitchen during the
  eligible order lifecycle, receive notifications, and rate delivered orders.

### Kitchen owners

- Create and edit one kitchen, location, cover image, availability, bKash
  receiving number, and COD availability.
- Add, edit, archive, and safely delete menu items with JPEG, PNG, or WebP
  images up to 5 MB.
- Review bKash transaction IDs, reject invalid payments, accept/reject orders,
  progress accepted orders to ready, and use order-specific customer chat.
- View delivered-order revenue accounting: gross sales, the 10% rider share,
  the 5% FoodCircle fee, and 85% owner net earnings.

### Riders

- Browse eligible ready deliveries, atomically claim one, and view pickup and
  delivery locations on a map.
- Mark pickup, securely confirm COD cash collection when applicable, and mark
  the assigned delivery complete.
- View an internal FoodCircle balance, total earnings, completed-delivery count,
  and immutable earnings history based on delivered-order settlements.

## Payments and settlement

Normal customer checkout exposes only bKash and Cash on Delivery. bKash uses
manual transaction-ID review by the kitchen owner; it is not an official bKash
gateway. COD collection is confirmed by the assigned rider.

After an eligible paid order is delivered, one server-authoritative settlement
is recorded atomically from the persisted order total:

- Kitchen owner net: 85%
- Rider earning: 10%
- FoodCircle platform fee: 5%

The settlement ledger records accounting obligations only. It does not transfer
money to bank or bKash accounts. Verified bKash refunds are processed manually
to the customer's registered profile number within three working days.

## Maps, chat, notifications, and ratings

- `geolocator` supplies Android/Web location permission and coordinates.
- `flutter_map` and OpenStreetMap present pickup and delivery locations; external
  navigation can be opened when supported.
- Chat is order-specific and restricted to the customer and kitchen owner.
- Android FCM tokens are private and notification taps route only to validated
  order/chat destinations.
- Customers can submit a one-to-five-star kitchen rating for an eligible
  delivered order.

## Technology

- Flutter 3.44.7 and Dart 3.12.2
- Material 3
- Supabase Auth, PostgreSQL, RLS, Storage, RPCs, and Edge Functions
- Firebase Cloud Messaging and Flutter Local Notifications for Android
- `image_picker`, `geolocator`, `flutter_map`, `latlong2`, and `url_launcher`
- Incremental timestamped migrations under `supabase/migrations/`

## Configuration and builds

Copy `config/dart_define.example.json` to the ignored
`config/dart_define.local.json` and add only the Supabase project URL and
publishable key. Never place a service-role key, database password, Firebase
service-account JSON, or another private credential in Flutter source.

```text
flutter pub get
flutter run --dart-define-from-file=config/dart_define.local.json
flutter build web --no-wasm-dry-run
flutter build apk --release --dart-define-from-file=config/dart_define.local.json
```

The Android application ID remains
`com.cloudkitchen.cloud_kitchen_mvp` because Firebase is registered to that
package. The visible product name is FoodCircle.

`database/schema.sql` is a legacy snapshot and must not be rerun against the
existing project. Apply reviewed timestamped migrations incrementally.

## MVP limitations

- bKash verification and refunds are manual; the app never requests a PIN or
  OTP.
- Settlement is internal accounting only. There is no automatic owner, rider,
  or platform payout and no rider withdrawal system.
- There is no live rider GPS tracking or automatic rider assignment.
- There is no multi-item cart; each order contains one item type with quantity
  1–20.
- There is no large administration portal.
- Kitchen-owner and rider roles are self-selected for this demonstration MVP;
  production use requires an approval and identity-verification workflow.
- Android push notifications are implemented; Web push is not enabled.
