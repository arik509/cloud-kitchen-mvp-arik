import 'package:flutter/material.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/profile/presentation/role_router.dart';
import '../features/notifications/application/push_notification_service.dart';
import '../core/theme/app_theme.dart';

class CloudKitchenApp extends StatefulWidget {
  const CloudKitchenApp({
    required this.authRepository,
    required this.profileRepository,
    required this.signedOutBuilder,
    required this.roleHomeBuilder,
    required this.notificationService,
    super.key,
  });

  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final WidgetBuilder signedOutBuilder;
  final RoleHomeBuilder roleHomeBuilder;
  final PushNotificationService notificationService;

  @override
  State<CloudKitchenApp> createState() => _CloudKitchenAppState();
}

class _CloudKitchenAppState extends State<CloudKitchenApp> {
  @override
  void initState() {
    super.initState();
    widget.notificationService.initialize();
  }

  @override
  void dispose() {
    widget.notificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Cloud Kitchen',
    theme: AppTheme.light,
    home: AuthGate(
      authRepository: widget.authRepository,
      profileRepository: widget.profileRepository,
      signedOutBuilder: widget.signedOutBuilder,
      roleHomeBuilder: widget.roleHomeBuilder,
    ),
  );
}
