import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'supabase_service.dart';

class LocationService {
  static StreamSubscription<Position>? _positionStream;
  static Timer? _heartbeatTimer;

  // Checa e solicita permissões
  static Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // Inicia o rastreamento e envia para o banco
  static Future<void> iniciarRastreamento(String motoristaId) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      if (kDebugMode) {
        print('Sem permissão de GPS.');
      }
      return;
    }

    // Garante que o stream antigo foi cancelado antes de criar um novo
    pararRastreamento();

    // Configura otimização de bateria
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15, // Atualiza apenas a cada 15 metros de deslocamento
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {
      
      try {
        await SupabaseService.client.from('motoristas').update({
          'lat': position.latitude,
          'lng': position.longitude,
          'heading': position.heading,
          'ultima_atualizacao': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', motoristaId);
      } catch (e) {
        if (kDebugMode) {
          print('Erro ao atualizar posição no banco: $e');
        }
      }
    });

    iniciarHeartbeat(motoristaId);
  }

  // Cancela o rastreamento (quando fica offline)
  static void pararRastreamento() {
    if (_positionStream != null) {
      _positionStream!.cancel();
      _positionStream = null;
    }
    pararHeartbeat();
  }

  // Inicia o pulso de persistência online (Heartbeat)
  static void iniciarHeartbeat(String motoristaId) {
    pararHeartbeat(); // Garante que não haverá timers duplicados

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        await SupabaseService.client.from('motoristas').update({
          'ultimo_sinal': DateTime.now().toUtc().toIso8601String(),
          'esta_online': true,
          'status': 'disponivel',
        }).eq('id', motoristaId);
      } catch (e) {
        if (kDebugMode) {
          print('Erro no heartbeat: $e');
        }
      }
    });
  }

  // Cancela o pulso de persistência
  static void pararHeartbeat() {
    if (_heartbeatTimer != null) {
      _heartbeatTimer!.cancel();
      _heartbeatTimer = null;
    }
  }
}
