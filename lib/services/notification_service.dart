import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
    await _plugin.show(
      id: 0,
      title: 'Nova Rota Recebida',
      body: 'Toque para abrir',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'canal_urgente',
          'Alertas de Rota',
          importance: Importance.max,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound('chama'), // O Android buscará chama.mp3 em res/raw
          playSound: true,
        ),
      ),
    );
  }
}
