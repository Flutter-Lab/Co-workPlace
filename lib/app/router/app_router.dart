import 'package:coworkplace/features/groups/presentation/group_setup_screen.dart';
import 'package:coworkplace/features/home/presentation/home_shell_screen.dart';
import 'package:coworkplace/features/profile/presentation/profile_setup_screen.dart';
import 'package:go_router/go_router.dart';

class AppRoutes {
  static const home = '/';
  static const profileSetup = '/profile-setup';
  static const groupSetup = '/group-setup';
}

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeShellScreen(),
    ),
    GoRoute(
      path: AppRoutes.profileSetup,
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    GoRoute(
      path: AppRoutes.groupSetup,
      builder: (context, state) => const GroupSetupScreen(),
    ),
  ],
);
