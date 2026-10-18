
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
import 'services/shared_test_client.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayApp());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  late final AppEnvironment environment;
  try {
    environment = AppEnvironment.fromBuild();
  } on FormatException catch (error) {
    runApp(MaterialApp(home: Scaffold(body: SafeArea(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('V10 Teste — configuração pendente', style: TextStyle(fontSize: 22)),
        const SizedBox(height: 16),
        Text(error.message),
        const SizedBox(height: 16),
        const Text('Nenhuma conexão com o banco foi iniciada. Configure o ambiente de homologação e gere novamente.'),
      ]),
    )))));
    return;
  }

  AppEnvironment.active = environment;
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  PermissionService.requestAllVitalPermissions();

  await Supabase.initialize(
    url: environment.url,
    httpClient: environment.isSharedTest ? SharedTestClient(environment) : null,
    // ignore: deprecated_member_use
    anonKey: environment.publicKey,
  );
  
  // Inicializa o monitoramento do Socket Realtime para diagnóstico
  SupabaseService.initializeMonitoring();
  
  // Inicializa o serviço de notificações locais
  await NotificationService.initialize();

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
          title: appFlavor == 'homologacao' ? 'V10 Teste' : 'App do Motorista',
          builder: (context, child) => appFlavor == 'homologacao'
              ? Banner(message: 'TESTE', location: BannerLocation.topEnd, child: child!)
              : child!,
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
