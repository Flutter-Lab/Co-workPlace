import 'dart:async';

import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/app/theme/app_theme.dart';
import 'package:coworkplace/core/bootstrap/bootstrap_provider.dart';
import 'package:coworkplace/core/bootstrap/bootstrap_state.dart';
import 'package:coworkplace/features/auth/presentation/auth_entry_screen.dart';
import 'package:coworkplace/features/home/presentation/home_shell_screen.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:coworkplace/core/widgets/vote_ticker.dart';
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
            return const AuthEntryScreen();
          }

          if (!state.hasProfile) {
            return const ProfileSetupScreen();
          }

          return _PresenceHeartbeat(
            userId: state.userId!,
            child: const HomeShellScreen(),
          );
        },
      ),
      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }

        // Place the global VoteTicker above all screens so vote announcements
        // appear regardless of current route.
        final stacked = Stack(
          children: [
            child,
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: SafeArea(child: VoteTicker()),
            ),
          ],
        );

        return _BootstrapWarningOverlay(state: bootstrapState, child: stacked);
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

class _PresenceHeartbeat extends ConsumerStatefulWidget {
  const _PresenceHeartbeat({required this.userId, required this.child});

  final String userId;
  final Widget child;

  @override
  ConsumerState<_PresenceHeartbeat> createState() => _PresenceHeartbeatState();
}

class _PresenceHeartbeatState extends ConsumerState<_PresenceHeartbeat>
    with WidgetsBindingObserver {
  static const _heartbeatInterval = Duration(seconds: 25);

  Timer? _timer;
  DateTime? _lastHeartbeatUtc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOnlineAndHeartbeat();
    _timer = Timer.periodic(_heartbeatInterval, (_) {
      _setOnlineAndHeartbeat();
    });
  }

  @override
  void didUpdateWidget(covariant _PresenceHeartbeat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _lastHeartbeatUtc = null;
      _setOnlineAndHeartbeat(force: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnlineAndHeartbeat(force: true);
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _setOffline();
    }
  }

  Future<void> _setOnlineAndHeartbeat({bool force = false}) async {
    final now = DateTime.now().toUtc();
    if (!force && _lastHeartbeatUtc != null) {
      final elapsed = now.difference(_lastHeartbeatUtc!);
      if (elapsed < const Duration(seconds: 15)) {
        return;
      }
    }

    _lastHeartbeatUtc = now;
    try {
      await ref
          .read(userProfileRepositoryProvider)
          .setPresence(userId: widget.userId, isOnline: true, seenAtUtc: now);
    } catch (_) {
      // Presence should not crash the UI.
    }
  }

  Future<void> _setOffline() async {
    try {
      await ref
          .read(userProfileRepositoryProvider)
          .setPresence(
            userId: widget.userId,
            isOnline: false,
            seenAtUtc: DateTime.now().toUtc(),
          );
    } catch (_) {
      // Presence should not crash the UI.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _setOffline();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
