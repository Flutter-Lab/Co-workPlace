import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/app/theme/theme_mode_provider.dart';
import 'package:coworkplace/core/notifications/notification_service.dart';
import 'package:coworkplace/features/auth/providers/auth_providers.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const _timezoneOptions = [
    _TimezoneOption(value: 'Asia/Dhaka', label: 'Bangladesh (Asia/Dhaka)'),
    _TimezoneOption(
      value: 'America/New_York',
      label: 'New York (America/New_York)',
    ),
  ];

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _kNotifKey = 'notif_daily_enabled';

  bool _notifEnabled = false;

  @override
  void initState() {
    super.initState();
    final box = Hive.box<int>('app_prefs');
    _notifEnabled = (box.get(_kNotifKey, defaultValue: 0)! == 1);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider).valueOrNull;
    final profile = session?.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.manage_accounts,
                color: Color(0xFF3B82F6),
              ),
              title: const Text('Profile Settings'),
              subtitle: Text(
                profile == null
                    ? 'Display name and timezone settings.'
                    : '${profile.displayName} • ${profile.timezone}',
              ),
              onTap: () => _showProfileSettingsDialog(context, profile),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile.adaptive(
              secondary: const Icon(
                Icons.notifications_outlined,
                color: Color(0xFF8B5CF6),
              ),
              title: const Text('Daily Reminder'),
              subtitle: const Text('Get a notification before the day resets.'),
              value: _notifEnabled,
              onChanged: (value) => _toggleDailyReminder(value),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(
                _themeModeIcon(ref.watch(themeModeProvider)),
                color: const Color(0xFFF59E0B),
              ),
              title: const Text('Theme'),
              subtitle: Text(_themeModeName(ref.watch(themeModeProvider))),
              trailing: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode, size: 16),
                  ),
                ],
                selected: {ref.watch(themeModeProvider)},
                onSelectionChanged: (modes) {
                  ref.read(themeModeProvider.notifier).setMode(modes.first);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.mood_outlined,
                color: Color(0xFF8B5CF6),
              ),
              title: const Text('Current Mode Presets'),
              subtitle: const Text(
                'Manage preset options for daily mood/status updates.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
              title: const Text('Logout'),
              subtitle: const Text('Sign out and return to login options.'),
              onTap: () async {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) {
                    return AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Do you want to sign out now?'),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: const Text('Logout'),
                        ),
                      ],
                    );
                  },
                );

                if (shouldLogout != true) {
                  return;
                }

                try {
                  await ref.read(authRepositoryProvider).signOut();
                } catch (error) {
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to logout: $error')),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _themeModeName(ThemeMode m) => switch (m) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    _ => 'System',
  };

  static IconData _themeModeIcon(ThemeMode m) => switch (m) {
    ThemeMode.light => Icons.light_mode,
    ThemeMode.dark => Icons.dark_mode,
    _ => Icons.brightness_auto,
  };

  Future<void> _toggleDailyReminder(bool enable) async {
    if (enable) {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notification permission denied. Please enable it in settings.',
              ),
            ),
          );
        }
        return;
      }
      await NotificationService.scheduleDailyReminder();
    } else {
      await NotificationService.cancelDailyReminder();
    }
    final box = Hive.box<int>('app_prefs');
    await box.put(_kNotifKey, enable ? 1 : 0);
    if (mounted) setState(() => _notifEnabled = enable);
  }

  Future<void> _showProfileSettingsDialog(
    BuildContext context,
    UserProfile? profile,
  ) async {
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile is not ready yet.')),
      );
      return;
    }

    final displayNameController = TextEditingController(
      text: profile.displayName,
    );
    var selectedTimezone = profile.timezone;

    final draft = await showModalBottomSheet<_ProfileSettingsDraft>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Settings',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTimezone,
                      decoration: const InputDecoration(
                        labelText: 'Timezone',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final option in SettingsScreen._timezoneOptions)
                          DropdownMenuItem(
                            value: option.value,
                            child: Text(option.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setModalState(() {
                          selectedTimezone = value;
                        });
                      },
                    ),

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(sheetContext).pop(
                                _ProfileSettingsDraft(
                                  displayName: displayNameController.text
                                      .trim(),
                                  timezone: selectedTimezone,
                                ),
                              );
                            },
                            child: const Text('Save Changes'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (draft == null) {
      return;
    }

    if (draft.displayName.isEmpty) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name cannot be empty.')),
      );
      return;
    }

    final updated = profile.copyWith(
      displayName: draft.displayName,
      timezone: draft.timezone,
    );

    try {
      await ref.read(userProfileRepositoryProvider).upsert(updated);
      ref.invalidate(appSessionProvider);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile settings updated.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile settings: $error')),
      );
    }
  }
}

class _TimezoneOption {
  const _TimezoneOption({required this.value, required this.label});

  final String value;
  final String label;
}

class _ProfileSettingsDraft {
  const _ProfileSettingsDraft({
    required this.displayName,
    required this.timezone,
  });

  final String displayName;
  final String timezone;
}
