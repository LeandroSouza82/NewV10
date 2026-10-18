import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  static const String _prefsKey = 'theme_mode';

  static final ThemeController instance = ThemeController._internal();
  ThemeController._internal();

  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

  /// Restaura a preferência salva; sem preferência mantém o tema escuro padrão.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    themeModeNotifier.value = ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.dark,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }

  void toggleTheme() {
    setThemeMode(themeModeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
