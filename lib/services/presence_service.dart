import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class PresenceService extends WidgetsBindingObserver {
  // Singleton pattern
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  Timer? _heartbeatTimer;

  static void initialize() {
    _instance._init();
  }

  void _init() {
    WidgetsBinding.instance.addObserver(this);
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _pingPresence(); // Dispara um ping imediato
    
    // Dispara a cada 30 segundos
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _pingPresence();
    });
  }

  void _pingPresence() {
    final motoristaId = SupabaseService.currentMotoristaId;
    if (motoristaId != null && motoristaId.isNotEmpty) {
      // Fire and forget sem await e com captura de erro vazia 
      // para garantir que não haverá efeitos colaterais na UI/Event Loop.
      Supabase.instance.client
          .from('motoristas')
          .update({'ultima_atualizacao': DateTime.now().toUtc().toIso8601String()})
          .eq('id', motoristaId)
          .then((_) {})
          .catchError((_) {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Compensa limitações do SO reiniciando o heartbeat imediatamente ao maximizar
      _startHeartbeat();
    } else if (state == AppLifecycleState.paused) {
      // Tenta enviar um último ping antes da possível suspensão em background
      _pingPresence();
    }
  }
}
