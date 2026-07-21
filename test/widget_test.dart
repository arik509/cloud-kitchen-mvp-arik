import 'package:cloud_kitchen_mvp/app/cloud_kitchen_app.dart';
import 'package:cloud_kitchen_mvp/core/config/supabase_config.dart';
import 'package:cloud_kitchen_mvp/features/auth/data/auth_repository.dart';
import 'package:cloud_kitchen_mvp/features/profile/data/profile_repository.dart';
import 'package:cloud_kitchen_mvp/features/profile/domain/user_role.dart';
import 'package:cloud_kitchen_mvp/features/profile/presentation/role_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts valid compile-time Supabase values', () {
    final config = SupabaseConfig.fromValues(
      url: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_example',
    );

    expect(config.url.host, 'example.supabase.co');
    expect(config.publishableKey, 'sb_publishable_example');
  });

  test('rejects missing Supabase values', () {
    expect(
      () => SupabaseConfig.fromValues(url: '', publishableKey: ''),
      throwsA(isA<ConfigurationException>()),
    );
  });

  testWidgets(
    'renders the signed-out builder without Supabase initialization',
    (tester) async {
      await tester.pumpWidget(
        CloudKitchenApp(
          authRepository: const FakeAuthRepository(),
          profileRepository: SequenceProfileRepository(const []),
          signedOutBuilder: (_) =>
              const Scaffold(body: Center(child: Text('Test sign in'))),
          roleHomeBuilder: (_, role) => Text(role.name),
        ),
      );

      expect(find.text('Test sign in'), findsOneWidget);
    },
  );

  testWidgets('retries a temporarily missing profile for the current user', (
    tester,
  ) async {
    final profiles = SequenceProfileRepository([null, null, UserRole.customer]);

    await tester.pumpWidget(
      MaterialApp(
        home: RoleRouter(
          userId: 'authenticated-user',
          authRepository: const FakeAuthRepository(
            session: AuthSession(userId: 'authenticated-user'),
          ),
          profileRepository: profiles,
          retryDelay: Duration.zero,
          homeBuilder: (_, role) => Text('Home: ${role.name}'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home: customer'), findsOneWidget);
    expect(profiles.requestedUserIds, [
      'authenticated-user',
      'authenticated-user',
      'authenticated-user',
    ]);
  });

  testWidgets('shows an accurate missing-profile state after bounded retries', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RoleRouter(
          userId: 'authenticated-user',
          authRepository: const FakeAuthRepository(
            session: AuthSession(userId: 'authenticated-user'),
          ),
          profileRepository: SequenceProfileRepository([null, null]),
          maxAttempts: 2,
          retryDelay: Duration.zero,
          homeBuilder: (_, role) => Text(role.name),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile is not ready'), findsOneWidget);
  });

  testWidgets('shows unsupported roles separately from database errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RoleRouter(
          userId: 'authenticated-user',
          authRepository: const FakeAuthRepository(
            session: AuthSession(userId: 'authenticated-user'),
          ),
          profileRepository: SequenceProfileRepository([
            const UnsupportedUserRoleException('admin'),
          ]),
          retryDelay: Duration.zero,
          homeBuilder: (_, role) => Text(role.name),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unsupported account role'), findsOneWidget);
  });
}

class FakeAuthRepository implements AuthRepository {
  const FakeAuthRepository({this.session});

  final AuthSession? session;

  @override
  AuthSession? get currentSession => session;

  @override
  Stream<AuthSession?> get sessionChanges => Stream<AuthSession?>.empty();

  @override
  Future<void> signOut() async {}
}

class SequenceProfileRepository implements ProfileRepository {
  SequenceProfileRepository(List<Object?> results)
    : _results = List<Object?>.from(results);

  final List<Object?> _results;
  final List<String> requestedUserIds = [];

  @override
  Future<UserRole?> fetchRole(String userId) async {
    requestedUserIds.add(userId);
    final result = _results.isEmpty ? null : _results.removeAt(0);
    if (result is Exception) throw result;
    return result as UserRole?;
  }
}
