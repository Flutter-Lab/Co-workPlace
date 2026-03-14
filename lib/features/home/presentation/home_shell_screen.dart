import 'package:coworkplace/features/friends/presentation/friends_screen.dart';
import 'package:coworkplace/features/home/presentation/home_screen.dart';
import 'package:coworkplace/features/profile/presentation/personal_profile_screen.dart';
import 'package:coworkplace/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _index = 0;

  static const _titles = ['Coworkplace', 'Friends', 'Settings', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _index == 3 ? null : AppBar(title: Text(_titles[_index])),
      body: _buildPage(_index),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          setState(() {
            _index = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Friends',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const FriendsScreen();
      case 2:
        return const SettingsScreen();
      case 3:
        return const PersonalProfileScreen();
      default:
        return const HomeScreen();
    }
  }
}
