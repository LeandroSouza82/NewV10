import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_colors.dart';
import 'services/permission_service.dart';
import 'services/supabase_service.dart';
import 'views/splash_view.dart';
import 'views/overlay_view.dart';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayView(),
    ),
  );
}

// Mantenha suas credenciais finais reais aqui
const String supabaseUrl = 'https://uqxoadxqcwidxqsfayem.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVxeG9hZHhxY3dpZHhxc2ZheWVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0NDUxODksImV4cCI6MjA4NDAyMTE4OX0.q9_RqSx4YfJxlblPS9fwrocx3HDH91ff1zJvPbVGI8w';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  PermissionService.requestAllVitalPermissions();

  await Supabase.initialize(
    url: supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: supabaseAnonKey,
  );
  
  // Inicializa o monitoramento do Socket Realtime para diagnóstico
  SupabaseService.initializeMonitoring();
  
  runApp(const AppDoMotorista());
}

class AppDoMotorista extends StatelessWidget {
  const AppDoMotorista({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App do Motorista',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundBody,
        useMaterial3: true,
      ),
      home: const SplashView(),
    );
  }
}

