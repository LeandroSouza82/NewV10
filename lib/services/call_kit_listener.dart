import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:android_intent_plus/android_intent.dart';

class CallKitListener {
  static void listenEvents() {
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      if (event == null) return;

      if (event is CallEventActionCallIncoming) {
        debugPrint('Incoming call received');
      } else if (event is CallEventActionCallStart) {
        debugPrint('Call started');
      } else if (event is CallEventActionCallAccept) {
        debugPrint('Call accepted: ${event.callKitParams.id}');
        
        try {
          const AndroidIntent intent = AndroidIntent(
            action: 'android.intent.action.MAIN',
            category: 'android.intent.category.LAUNCHER',
            package: 'com.example.app_do_motorista',
            componentName: 'com.example.app_do_motorista.MainActivity',
            flags: <int>[268435456], // FLAG_ACTIVITY_NEW_TASK
          );
          await intent.launch();
        } catch (e) {
          debugPrint('Erro ao lançar Intent do CallKit: $e');
        }
      } else if (event is CallEventActionCallDecline) {
        debugPrint('Call declined: ${event.callKitParams.id}');
      } else if (event is CallEventActionCallEnded) {
        debugPrint('Call ended: ${event.callKitParams.id}');
      } else if (event is CallEventActionCallTimeout) {
        debugPrint('Call timeout: ${event.id}');
      } else {
        debugPrint('Call event: ${event.eventName}');
      }
    });
  }
}
