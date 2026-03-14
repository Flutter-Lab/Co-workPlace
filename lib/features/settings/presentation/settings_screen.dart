import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/features/auth/providers/auth_providers.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _timezoneOptions = [
    _TimezoneOption(value: 'Asia/Dhaka', label: 'Bangladesh (Asia/Dhaka)'),
    _TimezoneOption(value: 'America/New_York', label: 'New York (America/New_York)'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider).valueOrNull;
    final profile = session?.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: const Text('Profile Settings'),
              subtitle: Text(
                profile == null
                    ? 'Display name, timezone, and day start settings.'
                    : '${profile.displayName} • ${profile.timezone} • ${_formatDayStart(profile.dayStartHour)}',
              ),
              onTap: () => _showProfileSettingsDialog(context, ref, profile),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: const ListTile(
              leading: Icon(Icons.mood_outlined),
              title: Text('Current Mode Presets'),
              subtitle: Text(
                'Manage preset options for daily mood/status updates.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout),
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
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(dialogContext).pop(true),
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

  Future<void> _showProfileSettingsDialog(
    BuildContext context,
    WidgetRef ref,
    UserProfile? profile,
  ) async {
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile is not ready yet.')),
      );
      return;
    }

    final displayNameController = TextEditingController(text: profile.displayName);
    var selectedTimezone = profile.timezone;
    var selectedDayStartHour = profile.dayStartHour;

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
                        for (final option in _timezoneOptions)
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
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('Day Start Time'),
                      subtitle: Text(_formatDayStart(selectedDayStartHour)),
                      trailing: TextButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: sheetContext,
                            initialTime: TimeOfDay(hour: selectedDayStartHour, minute: 0),
                          );
                          if (picked == null) {
                            return;
                          }
                          setModalState(() {
                            selectedDayStartHour = picked.hour;
                          });
                        },
                        child: const Text('Change'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(sheetContext).pop(
                                _ProfileSettingsDraft(
                                  displayName: displayNameController.text.trim(),
                                  timezone: selectedTimezone,
                                  dayStartHour: selectedDayStartHour,
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
      dayStartHour: draft.dayStartHour,
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

  static String _formatDayStart(int dayStartHour) {
    final dt = DateTime(2000, 1, 1, dayStartHour, 0);
    return DateFormat('hh:mm a').format(dt);
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
    required this.dayStartHour,
  });

  final String displayName;
  final String timezone;
  final int dayStartHour;
}
