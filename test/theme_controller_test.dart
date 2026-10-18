import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_motorista/theme/theme_controller.dart';

void main() {
  final controller = ThemeController.instance;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sem preferência salva mantém o tema escuro padrão', () async {
    await controller.load();
    expect(controller.themeModeNotifier.value, ThemeMode.dark);
  });

  test('alternar salva a escolha e load restaura após reiniciar', () async {
    await controller.load();
    controller.toggleTheme();
    await Future<void>.delayed(Duration.zero);
    expect(controller.themeModeNotifier.value, ThemeMode.light);

    controller.themeModeNotifier.value = ThemeMode.dark;
    await controller.load();
    expect(controller.themeModeNotifier.value, ThemeMode.light);
  });

  test('valor salvo inválido volta ao tema escuro', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'invalido'});
    await controller.load();
    expect(controller.themeModeNotifier.value, ThemeMode.dark);
  });
}
