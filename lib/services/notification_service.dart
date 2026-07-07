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

  static Future<void> showRotaRecebida() async {
    final prefs = await SharedPreferences.getInstance();
    final somAtivo = prefs.getBool('somNovaChamada') ?? true;

    await _plugin.show(
      id: 0,
      title: 'Nova Rota Recebida',
      body: 'Toque para abrir',
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
