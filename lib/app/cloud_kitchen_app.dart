import 'package:flutter/material.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/profile/presentation/role_router.dart';

class CloudKitchenApp extends StatelessWidget {
  const CloudKitchenApp({
    required this.authRepository,
    required this.profileRepository,
    required this.signedOutBuilder,
    required this.roleHomeBuilder,
    super.key,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final WidgetBuilder signedOutBuilder;
  final RoleHomeBuilder roleHomeBuilder;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Cloud Kitchen',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xffd35400)),
      useMaterial3: true,
    ),
    home: AuthGate(
      authRepository: authRepository,
      profileRepository: profileRepository,
      signedOutBuilder: signedOutBuilder,
      roleHomeBuilder: roleHomeBuilder,
    ),
  );
}
