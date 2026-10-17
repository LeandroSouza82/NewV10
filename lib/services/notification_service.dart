import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _plugin.initialize(settings: initializationSettings);
  }

  // Guarda somente os pontos ativos já avisados, separados por motorista.
  // A consulta inicial também avisa roteiros recebidos enquanto o app estava fechado.
  static Future<void> avisarRoteiroPendente(String motoristaId, List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'roteiros_avisados_$motoristaId';
    final conhecidos = (prefs.getStringList(key) ?? []).toSet();
    if (ids.any((id) => !conhecidos.contains(id))) {
      try {
        await showRotaRecebida();
      } catch (_) {
        // Permissão negada não impede o carregamento do roteiro.
        return;
      }
    }
    await prefs.setStringList(key, ids);
  }

  static Future<void> showRotaRecebida() async {
    final prefs = await SharedPreferences.getInstance();
    final somAtivo = prefs.getBool('somNovaChamada') ?? true;

    await _plugin.show(
      id: 0,
      title: 'Você tem um novo roteiro',
      body: 'Abra o aplicativo para consultar os pontos atribuídos a você.',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'canal_urgente',
          'Alertas de Rota',
          importance: Importance.max,
          priority: Priority.high,
          sound: somAtivo ? const RawResourceAndroidNotificationSound('chama') : null,
          playSound: somAtivo,
        ),
      ),
    );
  }
}
