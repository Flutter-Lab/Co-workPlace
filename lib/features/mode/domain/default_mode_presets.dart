import 'package:coworkplace/features/mode/domain/current_mode_preset.dart';

const defaultModePresets = [
  CurrentModePreset(
    id: 'focused',
    label: 'Focused',
    sortOrder: 1,
    icon: 'bullseye',
  ),
  CurrentModePreset(
    id: 'motivated',
    label: 'Motivated',
    sortOrder: 2,
    icon: 'rocket',
  ),
  CurrentModePreset(id: 'tired', label: 'Tired', sortOrder: 3, icon: 'moon'),
  CurrentModePreset(
    id: 'overwhelmed',
    label: 'Overwhelmed',
    sortOrder: 4,
    icon: 'storm',
  ),
  CurrentModePreset(
    id: 'resting',
    label: 'Resting',
    sortOrder: 5,
    icon: 'leaf',
  ),
  CurrentModePreset(id: 'other', label: 'Other', sortOrder: 6, icon: 'dots'),
];
