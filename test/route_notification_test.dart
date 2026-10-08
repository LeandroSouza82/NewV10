import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_motorista/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('roteiro já avisado não tenta gerar outra notificação', () async {
    SharedPreferences.setMockInitialValues({'roteiros_avisados_motorista-1': ['11']});
    await NotificationService.avisarRoteiroPendente('motorista-1', ['11']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('roteiros_avisados_motorista-1'), ['11']);
  });
  test('fim do roteiro limpa somente os avisos do motorista correspondente', () async {
    SharedPreferences.setMockInitialValues({'roteiros_avisados_motorista-1': ['11'], 'roteiros_avisados_motorista-2': ['22']});
    await NotificationService.avisarRoteiroPendente('motorista-1', []);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('roteiros_avisados_motorista-1'), isEmpty);
    expect(prefs.getStringList('roteiros_avisados_motorista-2'), ['22']);
  });
}
