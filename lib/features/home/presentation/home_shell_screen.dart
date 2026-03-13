import 'package:coworkplace/features/home/presentation/home_screen.dart';
import 'package:coworkplace/features/mode/domain/default_mode_presets.dart';
import 'package:coworkplace/features/members/presentation/members_screen.dart';
import 'package:coworkplace/features/profile/domain/user_profile.dart';
import 'package:coworkplace/features/profile/providers/profile_providers.dart';
import 'package:coworkplace/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coworkplace/app/session/app_session_provider.dart';

class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  int _index = 0;

  static const _pages = [HomeScreen(), MembersScreen(), SettingsScreen()];

  static const _titles = ['Coworkplace', 'Members', 'Settings'];

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider).valueOrNull;
    final currentModeLabel = session?.profile?.currentMode?.label;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (_index == 0)
            TextButton.icon(
              onPressed: () => _editCurrentMode(),
              icon: const Icon(Icons.mood, size: 18),
              label: Text(currentModeLabel ?? 'Set Mode'),
            ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
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
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Members',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Future<void> _editCurrentMode() async {
    final session = ref.read(appSessionProvider).valueOrNull;
    final profile = session?.profile;
    if (session?.userId == null || profile == null) {
      _showSnack('Profile is not ready yet.');
      return;
    }

    final modeDetailController = TextEditingController();
    var selectedPresetId =
        profile.currentMode?.presetId ?? defaultModePresets.first.id;

    final savedLabel = profile.currentMode?.label;
    final selectedPreset = defaultModePresets.firstWhere(
      (preset) => preset.id == selectedPresetId,
      orElse: () => defaultModePresets.first,
    );

    if (savedLabel != null && savedLabel.startsWith('${selectedPreset.label} - ')) {
      modeDetailController.text =
          savedLabel.substring('${selectedPreset.label} - '.length).trim();
    }

    final result = await showModalBottomSheet<_ModeDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Update Current Mode', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final preset in defaultModePresets)
                          ChoiceChip(
                            label: Text(preset.label),
                            selected: selectedPresetId == preset.id,
                            onSelected: (_) {
                              setModalState(() {
                                selectedPresetId = preset.id;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: modeDetailController,
                      decoration: const InputDecoration(
                        labelText: 'Mode Detail (Optional)',
                        hintText: 'Add short context',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(context).pop(
                                _ModeDraft(
                                  selectedPresetId: selectedPresetId,
                                  detail: modeDetailController.text.trim(),
                                ),
                              );
                            },
                            child: const Text('Save Mode'),
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

    if (result == null) {
      return;
    }

    final preset = defaultModePresets.firstWhere((p) => p.id == result.selectedPresetId);
    final modeLabel = result.detail.isEmpty ? preset.label : '${preset.label} - ${result.detail}';

    final updatedProfile = profile.copyWith(
      currentMode: UserCurrentMode(
        label: modeLabel,
        presetId: preset.id,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );

    try {
      final repository = ref.read(userProfileRepositoryProvider);
      await repository.upsert(updatedProfile);
      ref.invalidate(appSessionProvider);
      if (!mounted) {
        return;
      }
      _showSnack('Current mode updated.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('Failed to update mode: $error');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ModeDraft {
  const _ModeDraft({required this.selectedPresetId, required this.detail});

  final String selectedPresetId;
  final String detail;
}
