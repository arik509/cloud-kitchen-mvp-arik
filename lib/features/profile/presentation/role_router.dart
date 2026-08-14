import 'package:flutter/material.dart';

import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../domain/user_role.dart';

typedef RoleHomeBuilder = Widget Function(BuildContext context, UserRole role);

class RoleRouter extends StatefulWidget {
  const RoleRouter({
    required this.userId,
    required this.authRepository,
    required this.profileRepository,
    required this.homeBuilder,
    this.maxAttempts = 3,
    this.retryDelay = const Duration(milliseconds: 350),
    super.key,
  });

  final String userId;
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final RoleHomeBuilder homeBuilder;
  final int maxAttempts;
  final Duration retryDelay;

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  late Future<UserRole> _role;

  @override
  void initState() {
    super.initState();
    _role = _loadRole();
  }

  @override
  void didUpdateWidget(covariant RoleRouter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.profileRepository != widget.profileRepository) {
      _role = _loadRole();
    }
  }

  Future<UserRole> _loadRole() async {
    final attempts = widget.maxAttempts < 1 ? 1 : widget.maxAttempts;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      final role = await widget.profileRepository.fetchRole(widget.userId);
      if (role != null) return role;
      if (attempt < attempts) {
        await Future<void>.delayed(widget.retryDelay);
      }
    }
    throw const ProfileMissingException();
  }

  void _retry() {
    setState(() => _role = _loadRole());
  }

  Future<void> _signOut() async {
    try {
      await widget.authRepository.signOut();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign out failed. Check your connection and retry.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<UserRole>(
    future: _role,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasData) {
        return widget.homeBuilder(context, snapshot.data!);
      }

      final error = snapshot.error;
      if (error is ProfileMissingException) {
        return ProfileRouteFailureScreen(
          icon: Icons.person_search_outlined,
          title: 'Profile is not ready',
          message:
              'Your account is signed in, but its profile has not appeared '
              'yet. Retry in a moment or sign out and sign in again.',
          onRetry: _retry,
          onSignOut: _signOut,
        );
      }
      if (error is UnsupportedUserRoleException) {
        return ProfileRouteFailureScreen(
          icon: Icons.manage_accounts_outlined,
          title: 'Unsupported account role',
          message:
              'This account has a role that this app does not support. '
              'Sign out and contact the project administrator.',
          onRetry: _retry,
          onSignOut: _signOut,
        );
      }
      return ProfileRouteFailureScreen(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load your profile',
        message:
            'The profile request failed because of a network or database '
            'problem. Check your connection and try again.',
        onRetry: _retry,
        onSignOut: _signOut,
      );
    },
  );
}

class ProfileRouteFailureScreen extends StatelessWidget {
  const ProfileRouteFailureScreen({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onSignOut,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              TextButton(onPressed: onSignOut, child: const Text('Sign out')),
            ],
          ),
        ),
      ),
    ),
  );
}

class ProfileMissingException implements Exception {
  const ProfileMissingException();
}
