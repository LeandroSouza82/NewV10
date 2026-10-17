import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_do_motorista/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reabrir com entrega já avisada não toca novamente', () async {
    SharedPreferences.setMockInitialValues({'roteiros_avisados_motorista-1': ['11']});
    var notices = 0;
    await NotificationService.avisarRoteiroPendente('motorista-1', ['11'], notify: () async { notices++; });
    expect(notices, 0);
  });

  test('primeira leitura avisa e grava antes do Android; reabertura fica silenciosa', () async {
    var notices = 0;
    await NotificationService.avisarRoteiroPendente('motorista-1', ['11', '12'], notify: () async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('roteiros_avisados_motorista-1'), ['11', '12']);
      notices++;
    });
    final saved = (await SharedPreferences.getInstance()).getStringList('roteiros_avisados_motorista-1')!;
    // Recria o armazenamento como em um novo processo, sem estado em memória.
    SharedPreferences.setMockInitialValues({'roteiros_avisados_motorista-1': saved});
    await NotificationService.avisarRoteiroPendente('motorista-1', ['12', '11'], notify: () async { notices++; });
    expect(notices, 1);
  });

  test('lista vazia ou parcial não apaga avisos anteriores', () async {
    SharedPreferences.setMockInitialValues({'roteiros_avisados_motorista-1': ['11', '12']});
    var notices = 0;
    for (final ids in <List<String>>[[], ['11'], ['11', '12']]) {
      await NotificationService.avisarRoteiroPendente('motorista-1', ids, notify: () async { notices++; });
    }
    expect(notices, 0);
    expect((await SharedPreferences.getInstance()).getStringList('roteiros_avisados_motorista-1'), ['11', '12']);
  });

  test('nova entrega avisa uma vez, sem repetir as anteriores', () async {
    SharedPreferences.setMockInitialValues({'roteiros_avisados_motorista-1': ['11']});
    var notices = 0;
    for (final ids in <List<String>>[['11', '12', '12'], ['11', '12']]) {
      await NotificationService.avisarRoteiroPendente('motorista-1', ids, notify: () async { notices++; });
    }
    expect(notices, 1);
  });

  test('consultas concorrentes aguardam e não duplicam o aviso', () async {
    final gate = Completer<void>();
    var notices = 0;
    final first = NotificationService.avisarRoteiroPendente('motorista-1', ['11'], notify: () async {
      notices++;
      await gate.future;
    });
    final second = NotificationService.avisarRoteiroPendente('motorista-1', ['11'], notify: () async { notices++; });
    gate.complete();
    await Future.wait([first, second]);
    expect(notices, 1);
  });

  test('falha nativa não repete o som a cada consulta nem bloqueia entregas novas', () async {
    var attempts = 0;
    Future<void> fail() async { attempts++; throw StateError('notificação indisponível'); }
    await NotificationService.avisarRoteiroPendente('motorista-1', ['11'], notify: fail);
    await NotificationService.avisarRoteiroPendente('motorista-1', ['11'], notify: fail);
    await NotificationService.avisarRoteiroPendente('motorista-1', ['11', '12'], notify: () async { attempts++; });
    expect(attempts, 2);
  });

  test('histórico de um motorista não silencia o outro', () async {
    SharedPreferences.setMockInitialValues({'roteiros_avisados_motorista-1': ['11']});
    var notices = 0;
    await NotificationService.avisarRoteiroPendente('motorista-2', ['11'], notify: () async { notices++; });
    expect(notices, 1);
    expect((await SharedPreferences.getInstance()).getStringList('roteiros_avisados_motorista-1'), ['11']);
  });
}
