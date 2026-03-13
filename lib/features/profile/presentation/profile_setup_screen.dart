import 'package:coworkplace/app/session/app_session_provider.dart';
import 'package:coworkplace/features/mode/domain/default_mode_presets.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  static const _timezoneOptions = [
    _TimezoneOption(
      value: 'Asia/Dhaka',
      label: 'Bangladesh (Asia/Dhaka)',
    ),
    _TimezoneOption(
      value: 'America/New_York',
      label: 'New York (America/New_York)',
    ),
  ];

  final _displayNameController = TextEditingController();
  final _modeDetailController = TextEditingController();

  int _dayStartHour = 4;
  String _selectedTimezone = _timezoneOptions.first.value;
  String _selectedPresetId = defaultModePresets.first.id;
  bool _isSaving = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _modeDetailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final session = ref.read(appSessionProvider).valueOrNull;
    if (session == null || session.userId == null) {
      _showSnack('User session is not ready yet.');
      return;
    }

    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      _showSnack('Please enter a display name.');
      return;
    }

    final timezone = _selectedTimezone;

    final modeDetail = _modeDetailController.text.trim();
    final selectedPreset = defaultModePresets.firstWhere(
      (preset) => preset.id == _selectedPresetId,
    );

    final modeLabel = modeDetail.isNotEmpty
        ? '${selectedPreset.label} - $modeDetail'
        : selectedPreset.label;

    final existingProfile = session.profile;
    final profile = UserProfile(
      id: session.userId!,
      displayName: displayName,
      timezone: timezone,
      dayStartHour: _dayStartHour,
      groupIds: existingProfile?.groupIds ?? const [],
      activeGroupId: existingProfile?.activeGroupId,
      currentMode: UserCurrentMode(
        label: modeLabel,
        presetId: selectedPreset.id,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(userProfileRepositoryProvider);
      await repository.upsert(profile);
      ref.invalidate(appSessionProvider);

      if (!mounted) {
        return;
      }
      _showSnack('Profile saved.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('Failed to save profile: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final modePresets = defaultModePresets;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile Setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _displayNameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedTimezone,
            decoration: const InputDecoration(
              labelText: 'Timezone',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final option in _timezoneOptions)
                DropdownMenuItem(value: option.value, child: Text(option.label)),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _selectedTimezone = value;
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _dayStartHour,
            decoration: const InputDecoration(
              labelText: 'Day Start Hour',
              border: OutlineInputBorder(),
            ),
            items: List.generate(
              24,
              (hour) => DropdownMenuItem(value: hour, child: Text('$hour:00')),
            ),
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _dayStartHour = value;
              });
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Current Mode Preset',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in modePresets)
                ChoiceChip(
                  label: Text(preset.label),
                  selected: _selectedPresetId == preset.id,
                  onSelected: (_) {
                    setState(() {
                      _selectedPresetId = preset.id;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modeDetailController,
            decoration: const InputDecoration(
              labelText: 'Mode Detail (Optional)',
              hintText: 'Add short context, e.g. Planning sprint tasks',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: Text(_isSaving ? 'Saving...' : 'Save Profile'),
          ),
        ],
      ),
    );
  }
}

class _TimezoneOption {
  const _TimezoneOption({required this.value, required this.label});

  final String value;
  final String label;
}
