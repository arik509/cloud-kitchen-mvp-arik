import 'app/cloud_kitchen_app.dart';
import 'app/legacy_app_shell.dart';
import 'bootstrap.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/notifications/application/push_notification_service.dart';
import 'features/notifications/data/push_token_repository.dart';
import 'features/profile/data/profile_repository.dart';

Future<void> main() async {
  final firebaseConfigured = await initializeFirebaseForNotifications();
  await bootstrap(
    appBuilder: (client) {
      final notifications = firebaseConfigured
          ? FirebasePushNotificationService(
              tokenRepository: SupabasePushTokenRepository(client),
            )
          : DisabledPushNotificationService();
      return CloudKitchenApp(
        authRepository: SupabaseAuthRepository(client),
        profileRepository: SupabaseProfileRepository(client),
        notificationService: notifications,
        signedOutBuilder: (_) => const LoginScreen(),
        roleHomeBuilder: (_, role) => HomeScreen(
          role: role,
          client: client,
          notificationService: notifications,
        ),
      );
    },
  );
}
