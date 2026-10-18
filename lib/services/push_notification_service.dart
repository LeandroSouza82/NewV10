// ignore_for_file: avoid_print, deprecated_member_use

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

/// Handler de mensagens em background e terminated.
/// Deve ser função top-level e anotada com @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  // Se a mensagem contiver dados de rota ou nova entrega, aciona o alerta com som personalizado
  final tipo = message.data['tipo'] ?? message.data['type'];
  if (tipo == 'nova_rota' || tipo == 'nova_entrega' || message.data.containsKey('rota_id')) {
    try {
      await NotificationService.showRotaRecebida();
    } catch (_) {}
  }
}

class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static String? _cachedToken;

  /// Retorna o token FCM em cache, se disponível
  static String? get currentToken => _cachedToken;

  /// Inicializa o Firebase e configura os ouvintes de Push Notification
  static Future<void> initialize() async {
    try {
      // Inicializa o Firebase Core nativo
      await Firebase.initializeApp();
    } catch (e) {
      // Se o google-services.json ainda não estiver presente, captura suavemente
      print('⚠️ FCM: Firebase.initializeApp() ignorado ou não configurado ainda: $e');
      return;
    }

    // Registra o handler para mensagens em segundo plano ou app fechado
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Solicita permissões de notificação ao motorista
    await _solicitarPermissoes();

    // Apresentação em primeiro plano
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Obtém o token FCM inicial
    await _capturarERegistrarToken();

    // Ouve renovações periódicas do token FCM
    _fcm.onTokenRefresh.listen((novoToken) {
      _cachedToken = novoToken;
      syncTokenWithMotorista(novoToken);
    });

    // Ouve notificações recebidas com o app em primeiro plano (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _tratarMensagemForeground(message);
    });

    // Ouve quando o motorista clica na notificação com o app em segundo plano
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _tratarCliqueNotificacao(message);
    });

    // Verifica se o app foi aberto a partir de uma notificação (Terminated state)
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _tratarCliqueNotificacao(initialMessage);
    }
  }

  /// Solicita permissão explícita para receber notificações
  static Future<void> _solicitarPermissoes() async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      print('🔔 FCM: Status da permissão: ${settings.authorizationStatus}');
    } catch (e) {
      print('⚠️ FCM: Erro ao solicitar permissões: $e');
    }
  }

  /// Captura o token FCM do dispositivo e persiste
  static Future<void> _capturarERegistrarToken() async {
    try {
      _cachedToken = await _fcm.getToken();
      if (_cachedToken != null) {
        print('🔔 FCM Token capturado: $_cachedToken');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _cachedToken!);
        await syncTokenWithMotorista(_cachedToken);
      }
    } catch (e) {
      print('⚠️ FCM: Erro ao capturar token: $e');
    }
  }

  /// Vincula o token FCM ao motorista logado na tabela `motoristas` do Supabase
  static Future<void> syncTokenWithMotorista([String? token]) async {
    final tokenToSync = token ?? _cachedToken;
    if (tokenToSync == null || tokenToSync.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('fcm_token');
      if (savedToken != null && savedToken.isNotEmpty) {
        await SupabaseService.atualizarFcmToken(savedToken);
      }
      return;
    }

    await SupabaseService.atualizarFcmToken(tokenToSync);
  }

  /// Trata mensagem recebida enquanto o app está aberto na tela
  static void _tratarMensagemForeground(RemoteMessage message) {
    print('🔔 FCM recebido em Foreground: ${message.notification?.title}');
    
    // Se a mensagem não tiver display nativo automático, toca o alerta do roteiro
    final notification = message.notification;
    if (notification != null) {
      NotificationService.showRotaRecebida();
    }
  }

  /// Trata o clique na notificação para direcionamento correto
  static void _tratarCliqueNotificacao(RemoteMessage message) {
    print('🔔 FCM: Notificação clicada com payload: ${message.data}');
    // Os dados da rota (ex: rota_id) podem ser acessados via message.data['rota_id']
  }
}
