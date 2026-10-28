import 'dart:ui' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static Future<void> _pending = Future<void>.value();

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_stat_v10');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _plugin.initialize(settings: initializationSettings);

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'canal_urgente',
      'Alertas de Rota',
      description: 'Notificações urgentes de novas rotas e entregas',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('chama'),
      enableVibration: true,
    );
    await androidImplementation?.createNotificationChannel(channel);
  }

  // Histórico por motorista: uma lista vazia/reconexão não torna uma entrega nova.
  // Serializa consultas concorrentes e registra ANTES de chamar o Android.
  static Future<void> avisarRoteiroPendente(
    String motoristaId,
    List<String> ids, {
    Future<void> Function()? notify,
  }) {
    final operation = _pending.then((_) => _avisar(motoristaId, ids, notify));
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  static Future<void> _avisar(
    String motoristaId,
    List<String> ids,
    Future<void> Function()? notify,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'roteiros_avisados_$motoristaId';
    final conhecidos = (prefs.getStringList(key) ?? []).toSet();
    final novos = ids.where((id) => id.isNotEmpty && !conhecidos.contains(id)).toSet();
    if (novos.isEmpty) return;

    // Se não conseguir persistir, carrega os cards sem arriscar repetir o som.
    final saved = await prefs.setStringList(key, {...conhecidos, ...novos}.toList());
    if (!saved) return;
    try {
      await (notify ?? showRotaRecebida)();
    } catch (_) {
      // Permissão negada/erro nativo não impede os cards nem repete o aviso.
    }
  }

  static Future<void> showRotaRecebida() async {
    final prefs = await SharedPreferences.getInstance();
    final somAtivo = (prefs.getBool('somGeralAtivo') ?? true) &&
        (prefs.getBool('somNovaChamada') ?? true);

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
          icon: '@drawable/ic_stat_v10',
          largeIcon: const DrawableResourceAndroidBitmap('@drawable/ic_v10_logo'),
          color: const Color(0xFF44D62C),
          sound: somAtivo ? const RawResourceAndroidNotificationSound('chama') : null,
          playSound: somAtivo,
        ),
      ),
    );
  }
}
