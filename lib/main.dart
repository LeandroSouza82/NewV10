
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'services/permission_service.dart';
import 'services/supabase_service.dart';
import 'views/splash_view.dart';
import 'services/sync_service.dart';
import 'services/notification_service.dart';
import 'services/presence_service.dart';
import 'services/push_notification_service.dart';

import 'main_overlay.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'core/app_environment.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayApp());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF0A0E17),
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Color(0xFF0A0E17),
      systemNavigationBarContrastEnforced: false,
    ),
  );
  
  PermissionService.requestAllVitalPermissions();

  await Supabase.initialize(
    url: AppEnvironment.url,
    // ignore: deprecated_member_use
    anonKey: AppEnvironment.publicKey,
  );
  
  // Inicializa o monitoramento do Socket Realtime para diagnóstico
  SupabaseService.initializeMonitoring();
  
  // Inicializa o serviço de notificações locais
  await NotificationService.initialize();

  // Restaura a preferência de tema (dia/noite) salva no aparelho
  await ThemeController.instance.load();

  // Inicializa o serviço de Push Notifications (Firebase FCM)
  await PushNotificationService.initialize();
  


  // Inicializa o serviço de sincronização offline
  SyncService.initialize();
  
  // Inicializa o serviço de presença do motorista (Heartbeat)
  PresenceService.initialize();
  
  // Requisita permissão de notificação (VITAL para Android 13+)
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  runApp(const AppDoMotorista());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AppDoMotorista extends StatelessWidget {
  const AppDoMotorista({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.themeModeNotifier,
      builder: (context, currentThemeMode, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'V10 Delivery',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentThemeMode,
          home: const SplashView(),
        );
      },
    );
  }
}
