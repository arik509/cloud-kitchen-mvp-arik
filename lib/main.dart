import 'app/cloud_kitchen_app.dart';
import 'app/legacy_app_shell.dart';
import 'bootstrap.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/profile/data/profile_repository.dart';

Future<void> main() => bootstrap(
  appBuilder: (client) => CloudKitchenApp(
    authRepository: SupabaseAuthRepository(client),
    profileRepository: SupabaseProfileRepository(client),
    signedOutBuilder: (_) => const LoginScreen(),
    roleHomeBuilder: (_, role) => HomeScreen(role: role, client: client),
  ),
);
