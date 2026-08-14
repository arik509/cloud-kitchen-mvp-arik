import 'package:flutter/material.dart';

import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/role_router.dart';
import '../data/auth_repository.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
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
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Stream<AuthSession?> _sessionChanges;

  @override
  void initState() {
    super.initState();
    _sessionChanges = widget.authRepository.sessionChanges;
  }

  @override
  void didUpdateWidget(covariant AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authRepository != widget.authRepository) {
      _sessionChanges = widget.authRepository.sessionChanges;
    }
  }

  void _retryAuthState() {
    setState(() {
      _sessionChanges = widget.authRepository.sessionChanges;
    });
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthSession?>(
    initialData: widget.authRepository.currentSession,
    stream: _sessionChanges,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _AuthStateFailureScreen(onRetry: _retryAuthState);
      }
      final session = snapshot.data;
      if (session == null) {
        return widget.signedOutBuilder(context);
      }
      if (session.userId.trim().isEmpty) {
        return _AuthStateFailureScreen(onRetry: _retryAuthState);
      }
      return RoleRouter(
        userId: session.userId,
        authRepository: widget.authRepository,
        profileRepository: widget.profileRepository,
        homeBuilder: widget.roleHomeBuilder,
      );
    },
  );
}

class _AuthStateFailureScreen extends StatelessWidget {
  const _AuthStateFailureScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_clock_outlined, size: 72),
              const SizedBox(height: 16),
              Text(
                'Authentication state unavailable',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'The app could not confirm your current session. '
                'Check your connection and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
