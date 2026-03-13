import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/app/theme/app_theme.dart';
import 'package:coworkplace/core/bootstrap/bootstrap_provider.dart';
import 'package:coworkplace/core/bootstrap/bootstrap_state.dart';
import 'package:coworkplace/features/groups/presentation/group_setup_screen.dart';
import 'package:coworkplace/features/home/presentation/home_shell_screen.dart';
import 'package:coworkplace/features/profile/presentation/profile_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoworkplaceApp extends ConsumerWidget {
  const CoworkplaceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(appBootstrapProvider);

    return bootstrap.when(
      loading: () =>
          MaterialApp(theme: AppTheme.light(), home: const _SplashScreen()),
      error: (error, stackTrace) => MaterialApp(
        theme: AppTheme.light(),
        home: _StartupErrorScreen(message: error.toString()),
      ),
      data: (state) => _SessionGate(bootstrapState: state),
    );
  }
}

class _SessionGate extends ConsumerWidget {
  const _SessionGate({required this.bootstrapState});

  final BootstrapState bootstrapState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);

    return MaterialApp(
      title: 'Coworkplace',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: session.when(
        loading: () => const _SplashScreen(),
        error: (error, stackTrace) =>
            _StartupErrorScreen(message: 'Session error: $error'),
        data: (state) {
          if (!state.isAuthenticated) {
            return const _SplashScreen();
          }

          if (!state.hasProfile) {
            return const ProfileSetupScreen();
          }

          if (!state.hasActiveGroup) {
            return const GroupSetupScreen();
          }

          return const HomeShellScreen();
        },
      ),
      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }

        return _BootstrapWarningOverlay(state: bootstrapState, child: child);
      },
    );
  }
}

class _BootstrapWarningOverlay extends StatelessWidget {
  const _BootstrapWarningOverlay({required this.state, required this.child});

  final BootstrapState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (state.firebaseReady) {
      return child;
    }

    return Stack(
      children: [
        child,
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Material(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Firebase is not configured yet. Add platform Firebase config files before building data features.\n${state.errorMessage ?? ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Startup error: $message', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
