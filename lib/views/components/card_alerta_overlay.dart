import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../services/audio_service.dart';

class CardAlertaOverlay extends StatefulWidget {
  const CardAlertaOverlay({super.key});

  @override
  State<CardAlertaOverlay> createState() => _CardAlertaOverlayState();
}

class _CardAlertaOverlayState extends State<CardAlertaOverlay> {

  Future<void> dispararSomDeChamadaNativo() async {
    try {
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      
      await flutterLocalNotificationsPlugin.show(
        id: 999, // ID único
        title: 'Nova Rota',
        body: 'Toque para visualizar detalhes',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'canal_urgente', 'Alertas de Rota',
            importance: Importance.max,
            priority: Priority.high,
            sound: RawResourceAndroidNotificationSound('chama'), // Aponta para res/raw/chama.mp3
            playSound: true,
            fullScreenIntent: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao disparar notificacao no overlay: $e');
      // Fallback robusto usando audioplayers com canal de Alarme
      await AudioService.playChamaNoOverlay();
    }
  }

  @override
  void initState() {
    super.initState();
    dispararSomDeChamadaNativo(); // Dispara o som nativo ao abrir o Overlay
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent, // CRÍTICO: Fundo 100% invisível
      child: SizedBox(
        width: double.infinity,
        height: double.infinity, // Ocupa a janela nativa inteira
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end, // CRÍTICO: Joga o card pro chão da tela
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 40), // Afasta do limite inferior da tela (navegação)
              width: MediaQuery.of(context).size.width * 0.90,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 15, spreadRadius: 5)],
              ),
              child: Stack(
                children: [
                  // Conteúdo Principal
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // O card se molda ao conteúdo sem explodir
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 45),
                        const SizedBox(height: 12),
                        const Text(
                          '🚨 NOVA ROTA RECEBIDA!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        const BotaoAlertaOverlay(),
                      ],
                    ),
                  ),
                  // Botão X no canto superior direito
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                      onPressed: () async {
                        await AudioService.stop();
                        FlutterOverlayWindow.closeOverlay();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BotaoAlertaOverlay extends StatelessWidget {
  const BotaoAlertaOverlay({super.key});

  Future<void> _abrirApp(BuildContext context) async {
    await AudioService.stop();
    await FlutterOverlayWindow.closeOverlay();
    try {
      const AndroidIntent intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        category: 'android.intent.category.LAUNCHER',
        package: 'com.example.app_do_motorista',
        componentName: 'com.example.app_do_motorista.MainActivity',
        flags: [268435456],
      );
      await intent.launch();
    } catch (e) {
      debugPrint('Erro ao lançar Intent: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[800], // Verde mais escuro e profissional
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        onPressed: () => _abrirApp(context),
        child: const Text(
          'ABRIR APLICATIVO',
          style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
