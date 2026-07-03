// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Serviço reativo de distância com 3 travas anti-loop:
///   1. Trava de Rebuild: Nenhuma chamada HTTP é disparada pela UI/build()
///   2. Trava de Concorrência (_isFetching): Mutex booleano impede requests paralelos
///   3. Trava de Raio Geográfico (500m): Só chama OSRM se deslocou ≥ 500m
///
/// A UI apenas escuta [distanciasNotifier] — nunca dispara requests.
class DistanciaService {
  // ─── Singleton ───
  DistanciaService._();
  static final DistanciaService instance = DistanciaService._();

  // ─── Estado Reativo (UI escuta apenas isto) ───
  /// Mapa: entregaId → "4.8 km" (texto pronto para exibir)
  final ValueNotifier<Map<String, String>> distanciasNotifier =
      ValueNotifier<Map<String, String>>({});

  // ─── Travas de Segurança ───
  /// TRAVA 2: Mutex de concorrência — impede requests OSRM paralelos
  bool _isFetching = false;

  /// TRAVA 3: Coordenada da última chamada OSRM bem-sucedida
  double? _ultimoLat;
  double? _ultimoLng;

  // ─── Cache Interno ───
  /// Cache OSRM: chave "latO,lngO>latD,lngD" → distância em km
  final Map<String, double> _cacheOsrm = {};

  /// Posição GPS atual do motorista
  double? _motoristaLat;
  double? _motoristaLng;

  /// Lista de entregas ativas (atualizada externamente)
  List<Map<String, dynamic>> _entregas = [];

  /// Stream subscription do GPS (gerenciada internamente)
  StreamSubscription<Position>? _gpsSubscription;

  // ─── Constantes ───
  static const double _raioMinimoMetros = 500.0; // Trava 3: delta mínimo
  static const Duration _timeoutOsrm = Duration(seconds: 5);

  // ═══════════════════════════════════════════════════════════════════
  // API PÚBLICA
  // ═══════════════════════════════════════════════════════════════════

  /// Atualiza a lista de entregas que precisam de cálculo de distância.
  /// Chamado quando o Stream de entregas emite dados novos.
  void atualizarEntregas(List<Map<String, dynamic>> novasEntregas) {
    _entregas = List.from(novasEntregas);
    // Recalcula imediatamente com a posição GPS mais recente
    _recalcularDistancias();
  }

  /// Inicia a escuta do GPS para atualização reativa de distâncias.
  /// Usa distanceFilter de 50m para não desperdiçar bateria.
  void iniciarEscutaGps() {
    pararEscutaGps();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50, // Só emite a cada 50m de deslocamento real
    );

    _gpsSubscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen((Position pos) {
      _motoristaLat = pos.latitude;
      _motoristaLng = pos.longitude;
      _recalcularDistancias();
    });

    // Pega posição inicial imediatamente
    _obterPosicaoInicial();
  }

  /// Para a escuta do GPS (ao ficar offline ou sair)
  void pararEscutaGps() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
  }

  /// Limpa todo o estado (logout, troca de rota)
  void resetar() {
    pararEscutaGps();
    _cacheOsrm.clear();
    _entregas.clear();
    _ultimoLat = null;
    _ultimoLng = null;
    _motoristaLat = null;
    _motoristaLng = null;
    _isFetching = false;
    distanciasNotifier.value = {};
  }

  // ═══════════════════════════════════════════════════════════════════
  // LÓGICA INTERNA (nunca chamada pela UI)
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _obterPosicaoInicial() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        _motoristaLat = pos.latitude;
        _motoristaLng = pos.longitude;
        _recalcularDistancias();
      }
    } catch (_) {}
  }

  /// Decide se chama OSRM ou usa cache/subtração local.
  /// Implementa as 3 travas de segurança.
  void _recalcularDistancias() {
    final lat = _motoristaLat;
    final lng = _motoristaLng;
    if (lat == null || lng == null || _entregas.isEmpty) return;

    // ─── TRAVA 3: Raio Geográfico de 500m ───
    final bool deslocouSuficiente = _verificarDeslocamentoMinimo(lat, lng);

    if (deslocouSuficiente) {
      // Precisa chamar OSRM — mas verifica a Trava 2 primeiro
      _chamarOsrmSeguro(lat, lng);
    } else {
      // Não deslocou 500m → subtrai matematicamente usando Haversine local
      _atualizarComSubtracaoLocal(lat, lng);
    }
  }

  /// TRAVA 3: Verifica se o motorista deslocou ≥ 500m desde a última chamada OSRM
  bool _verificarDeslocamentoMinimo(double lat, double lng) {
    if (_ultimoLat == null || _ultimoLng == null) return true; // Primeira vez

    final deslocamento = _haversineMetros(_ultimoLat!, _ultimoLng!, lat, lng);
    return deslocamento >= _raioMinimoMetros;
  }

  /// TRAVA 2: Mutex — só permite uma chamada OSRM por vez
  Future<void> _chamarOsrmSeguro(double lat, double lng) async {
    if (_isFetching) {
      print('🔒 TRAVA CONCORRÊNCIA: Request OSRM já em andamento. Ignorando.');
      return;
    }

    _isFetching = true; // ← LOCK

    try {
      final Map<String, String> novasDistancias = {};

      for (final entrega in _entregas) {
        final latDest = _parseDouble(entrega['lat']);
        final lngDest = _parseDouble(entrega['lng']);
        final id = entrega['id']?.toString() ?? '';

        if (latDest == null || lngDest == null || id.isEmpty) {
          novasDistancias[id] = 'Sem GPS';
          continue;
        }

        final dist = await _obterDistanciaOsrm(lat, lng, latDest, lngDest);
        novasDistancias[id] = '${dist.toStringAsFixed(1)} km';
      }

      // Atualiza a coordenada de referência SOMENTE após sucesso
      _ultimoLat = lat;
      _ultimoLng = lng;

      // Emite para a UI via ValueNotifier
      distanciasNotifier.value = Map.from(novasDistancias);
    } finally {
      _isFetching = false; // ← UNLOCK (sempre, mesmo com erro)
    }
  }

  /// Subtração local: usa distância Haversine entre posição atual e destino
  /// sem chamar nenhuma API. Atualiza a UI com valores aproximados.
  void _atualizarComSubtracaoLocal(double lat, double lng) {
    final Map<String, String> novasDistancias = {};

    for (final entrega in _entregas) {
      final latDest = _parseDouble(entrega['lat']);
      final lngDest = _parseDouble(entrega['lng']);
      final id = entrega['id']?.toString() ?? '';

      if (latDest == null || lngDest == null || id.isEmpty) {
        novasDistancias[id] = 'Sem GPS';
        continue;
      }

      // Verifica se há valor OSRM em cache para este destino
      final chaveCache = _chaveOsrm(_ultimoLat ?? lat, _ultimoLng ?? lng, latDest, lngDest);
      final distCache = _cacheOsrm[chaveCache];

      if (distCache != null && _ultimoLat != null && _ultimoLng != null) {
        // Subtrai o deslocamento local da distância OSRM cacheada
        final deslocadoKm = _haversineMetros(_ultimoLat!, _ultimoLng!, lat, lng) / 1000.0;
        final distAjustada = (distCache - deslocadoKm).clamp(0.1, double.infinity);
        novasDistancias[id] = '${distAjustada.toStringAsFixed(1)} km';
      } else {
        // Sem cache OSRM → Haversine × 1.45 como fallback
        final distFallback = _haversineKm(lat, lng, latDest, lngDest) * 1.45;
        novasDistancias[id] = '${distFallback.toStringAsFixed(1)} km';
      }
    }

    distanciasNotifier.value = Map.from(novasDistancias);
  }

  /// Chamada real ao OSRM com cache por rota
  Future<double> _obterDistanciaOsrm(
    double latO, double lngO, double latD, double lngD,
  ) async {
    final chave = _chaveOsrm(latO, lngO, latD, lngD);

    if (_cacheOsrm.containsKey(chave)) {
      return _cacheOsrm[chave]!;
    }

    try {
      final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/'
        '$lngO,$latO;$lngD,$latD'
        '?overview=false',
      );

      final response = await http.get(url).timeout(_timeoutOsrm);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            (data['routes'] as List).isNotEmpty) {
          final double distKm =
              (data['routes'][0]['distance'] as num).toDouble() / 1000.0;
          _cacheOsrm[chave] = distKm;
          return distKm;
        }
      }
    } catch (e) {
      print('⚠️ OSRM falhou: $e — usando Haversine×1.45');
    }

    // Fallback
    final fallback = _haversineKm(latO, lngO, latD, lngD) * 1.45;
    _cacheOsrm[chave] = fallback;
    return fallback;
  }

  // ═══════════════════════════════════════════════════════════════════
  // UTILITÁRIOS PUROS (sem side-effects)
  // ═══════════════════════════════════════════════════════════════════

  String _chaveOsrm(double latO, double lngO, double latD, double lngD) {
    return '${latO.toStringAsFixed(4)},${lngO.toStringAsFixed(4)}'
        '>${latD.toStringAsFixed(4)},${lngD.toStringAsFixed(4)}';
  }

  /// Haversine em metros (para cálculo de delta de 500m)
  double _haversineMetros(double lat1, double lng1, double lat2, double lng2) {
    return _haversineKm(lat1, lng1, lat2, lng2) * 1000.0;
  }

  /// Haversine em km (linha reta)
  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const double raioTerra = 6371.0;
    double dLat = _rad(lat2 - lat1);
    double dLng = _rad(lng2 - lng1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return raioTerra * c;
  }

  double _rad(double graus) => graus * (pi / 180);

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    return double.tryParse(value.toString());
  }
}
