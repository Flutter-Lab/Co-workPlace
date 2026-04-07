import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

// Stored in Hive 'app_prefs' as int: 0=system, 1=light, 2=dark
const _kThemeModeKey = 'theme_mode';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final box = Hive.box<int>('app_prefs');
    final raw = box.get(_kThemeModeKey, defaultValue: 0)!;
    return _fromInt(raw);
  }

  Future<void> setMode(ThemeMode mode) async {
    final box = Hive.box<int>('app_prefs');
    await box.put(_kThemeModeKey, _toInt(mode));
    state = mode;
  }

  static ThemeMode _fromInt(int v) => switch (v) {
    1 => ThemeMode.light,
    2 => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static int _toInt(ThemeMode m) => switch (m) {
    ThemeMode.light => 1,
    ThemeMode.dark => 2,
    _ => 0,
  };
}
