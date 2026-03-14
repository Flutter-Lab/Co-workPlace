import 'package:coworkplace/features/profile/presentation/personal_profile_screen.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('My Profile & Tasks'),
            subtitle: const Text('Open personal profile and manage your own tasks.'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PersonalProfileScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(Icons.manage_accounts),
            title: Text('Profile Settings'),
            subtitle: Text('Display name, timezone, and day start settings.'),
          ),
        ),
        SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(Icons.mood_outlined),
            title: Text('Current Mode Presets'),
            subtitle: Text(
              'Manage preset options for daily mood/status updates.',
            ),
          ),
        ),
      ],
    );
  }
}
