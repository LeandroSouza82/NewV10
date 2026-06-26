import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';

class CallKitService {
  static Future<void> showRouteCall(Map<String, dynamic> data) async {
    final routeId = data['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    // Extrai cliente ou endereço para mostrar como "Caller"
    final cliente = data['cliente']?.toString() ?? '';
    final endereco = data['endereco']?.toString() ?? 'Sem endereço';
    final descricao = cliente.isNotEmpty ? '$cliente - $endereco' : endereco;

    final params = CallKitParams(
      id: routeId,
      nameCaller: 'NOVA ROTA V10',
      appName: 'V10 Delivery',
      handle: descricao,
      type: 0,
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Rota perdida',
        callbackText: 'Ligar de volta',
      ),
      duration: 15000,
      extra: data, // Importante: guarda o payload da rota
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0B132B', // Dark Navy
        actionColor: '#00FF66', // Verde Neon
        incomingCallNotificationChannelName: 'Chamadas V10',
        missedCallNotificationChannelName: 'Chamadas Perdidas V10',
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: '',
        supportsVideo: false,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  static Future<void> endAllCalls() async {
    await FlutterCallkitIncoming.endAllCalls();
  }
}
