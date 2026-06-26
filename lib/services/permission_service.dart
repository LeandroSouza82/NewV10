import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class PermissionService {
  /// Solicita todas as permissões vitais para o motorista
  static Future<void> requestAllVitalPermissions() async {
    // 1. Manter a tela acesa
    await WakelockPlus.enable();

    // 2. Solicitar Localização (Precisa do Fine Location primeiro)
    var locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      await Permission.location.request();
    }

    // 3. Solicitar Localização em Segundo Plano (Background)
    var bgLocationStatus = await Permission.locationAlways.status;
    if (!bgLocationStatus.isGranted) {
      await Permission.locationAlways.request();
    }



    // 5. Ignorar Otimização de Bateria (Garante que o app não seja morto pelo Android)
    var batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    if (!batteryStatus.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  /// Desativa a tela acesa (útil para quando o motorista ficar offline)
  static Future<void> disableWakeLock() async {
    await WakelockPlus.disable();
  }
}
