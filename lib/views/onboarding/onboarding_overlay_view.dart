import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OnboardingOverlayView extends StatelessWidget {
  const OnboardingOverlayView({super.key});

  Future<void> _requestPermission(BuildContext context) async {
    const MethodChannel mainChannel = MethodChannel('com.v10.delivery/main_overlay');
    try {
      await mainChannel.invokeMethod('requestOverlayPermission');
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Erro ao solicitar permissão de overlay: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A2740),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF48BB78).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.picture_in_picture_alt,
                size: 48,
                color: Color(0xFF48BB78),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Alerta de Novas Rotas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Para garantir que você nunca perca uma corrida importante, precisamos da permissão para exibir o alerta flutuante sobre outros aplicativos (mesmo quando você estiver no WhatsApp ou Maps).',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _requestPermission(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF48BB78),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'CONCEDER PERMISSÃO',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'AGORA NÃO',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
