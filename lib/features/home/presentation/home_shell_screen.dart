import 'package:coworkplace/features/friends/presentation/friends_screen.dart';
import 'package:coworkplace/features/friends/providers/friend_providers.dart';
import 'package:coworkplace/features/goals/presentation/goal_dashboard_screen.dart';
import 'package:coworkplace/features/home/presentation/home_screen.dart';
import 'package:coworkplace/features/profile/presentation/personal_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  int _index = 0;

  static const _titles = ['Coworkplace', 'Goals', 'Friends', 'Profile'];

  @override
  Widget build(BuildContext context) {
    final hasFriendActivity =
        ref.watch(friendActivityBadgeProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: (_index == 1 || _index == 2 || _index == 3)
          ? null
          : AppBar(title: Text(_titles[_index])),
      body: _buildPage(_index),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (index) {
            if (index == 2) {
              recordFriendsTabVisit(ref, DateTime.now().toUtc());
            }
            setState(() {
              _index = index;
            });
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.track_changes_outlined),
              selectedIcon: Icon(Icons.track_changes),
              label: 'Goals',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: hasFriendActivity && _index != 2,
                child: const Icon(Icons.people_outline),
              ),
              selectedIcon: const Icon(Icons.people),
              label: 'Friends',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const GoalDashboardScreen();
      case 2:
        return const FriendsScreen();
      case 3:
        return const PersonalProfileScreen();
      default:
        return const HomeScreen();
    }
  }
}
