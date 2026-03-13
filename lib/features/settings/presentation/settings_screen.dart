import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
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
