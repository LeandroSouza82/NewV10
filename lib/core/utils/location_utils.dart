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
///
/// Resiliência adicional:
///   • Timeout de 5s na requisição HTTP ao OSRM
///   • Watchdog de 15s que desbloquia o mutex caso ele fique preso
///   • Fallback volátil (Geolocator WGS-84 × 1.45) se OSRM falhar — NÃO gravado no cache
///   • Retomada automática: _ultimoLat/_ultimoLng só avança quando OSRM responde com
///     sucesso real; em fallback a Trava 3 permanece ativa e o próximo ciclo GPS retenta
///   • Emissão de fallback na UI quando novas entregas chegam com mutex travado
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

  /// Watchdog: garante que o mutex nunca fique travado além de [_timeoutMutex]
  Timer? _watchdogTimer;

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

  /// Tempo máximo que o mutex pode ficar travado antes do watchdog forçar unlock
  static const Duration _timeoutMutex = Duration(seconds: 15);

  // ═══════════════════════════════════════════════════════════════════
  // API PÚBLICA
  // ═══════════════════════════════════════════════════════════════════

  /// Atualiza a lista de entregas que precisam de cálculo de distância.
  /// Chamado quando o Stream de entregas emite dados novos.
  ///
  /// Se o mutex estiver travado (ex: troca de rede Wi-Fi → 4G), emite
  /// imediatamente um fallback geodésico para que a UI nunca fique em "...".
  void atualizarEntregas(List<Map<String, dynamic>> novasEntregas) {
    _entregas = List.from(novasEntregas);

    if (_isFetching) {
      // Mutex travado: emite fallback imediato para as novas entregas
      // evitando que o badge de distância fique preso em "..."
      print('⚡ MUTEX OCUPADO: emitindo fallback geodésico para novas entregas.');
      _emitirFallbackImediato();
      return;
    }

    // Recalcula normalmente com a posição GPS mais recente
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
    _cancelarWatchdog();
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

  /// TRAVA 2: Mutex — só permite uma chamada OSRM por vez.
  ///
  /// Proteções adicionais:
  ///   • Watchdog Timer de [_timeoutMutex]: força o unlock se o mutex travar
  ///   • try/finally garante unlock em qualquer caminho de saída
  Future<void> _chamarOsrmSeguro(double lat, double lng) async {
    if (_isFetching) {
      print('🔒 TRAVA CONCORRÊNCIA: Request OSRM já em andamento. Ignorando.');
      return;
    }

    _isFetching = true; // ← LOCK
    _iniciarWatchdog();  // ← Watchdog: garante unlock após _timeoutMutex

    try {
      final Map<String, String> novasDistancias = {};

      // Rastreia se algum resultado veio de fallback (linha reta).
      // Se sim, _ultimoLat/_ultimoLng NÃO será atualizado, mantendo a
      // Trava 3 ativa para que o próximo ciclo GPS retente o OSRM.
      bool usouFallback = false;

      for (final entrega in List.from(_entregas)) {
        final latDest = _parseDouble(entrega['lat']);
        final lngDest = _parseDouble(entrega['lng']);
        final id = entrega['id']?.toString() ?? '';

        if (latDest == null || lngDest == null || id.isEmpty) {
          novasDistancias[id] = 'Sem GPS';
          continue;
        }

        final resultado = await _obterDistanciaOsrm(lat, lng, latDest, lngDest);

        if (resultado.fromOsrm) {
          // Valor real de rota: exibe sem prefixo
          novasDistancias[id] = '${resultado.km.toStringAsFixed(1)} km';
        } else {
          // Valor volátil de linha reta: exibe com '~' para sinalizar estimativa
          usouFallback = true;
          novasDistancias[id] = '~${resultado.km.toStringAsFixed(1)} km';
        }
      }

      // REGRA CRÍTICA DE RETOMADA AUTOMÁTICA:
      // Só avança a coordenada de referência (Trava 3) quando TODOS os
      // resultados vieram do OSRM real. Em fallback, a trava permanece na
      // posição anterior, forçando nova tentativa OSRM no próximo ciclo GPS.
      if (!usouFallback) {
        _ultimoLat = lat;
        _ultimoLng = lng;
        print('✅ OSRM: todas as distâncias confirmadas. Referência avançada.');
      } else {
        print('🔄 FALLBACK VOLÁTIL: cache vazio preservado. '
            'OSRM será retentado no próximo ciclo GPS.');
      }

      // Emite para a UI via ValueNotifier
      distanciasNotifier.value = Map.from(novasDistancias);
    } catch (e) {
      // Erro inesperado no loop (ex: CancelledException do stream)
      // → Emite fallback para que a UI não fique travada em "..."
      print('🚨 OSRM loop error: $e — emitindo fallback geodésico.');
      _emitirFallbackImediato();
    } finally {
      _cancelarWatchdog();
      _isFetching = false; // ← UNLOCK (sempre, em sucesso, erro ou timeout)
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

  /// Emite fallback geodésico imediato para TODAS as entregas atuais,
  /// usando Geolocator.distanceBetween (WGS-84 preciso) × 1.45.
  ///
  /// Chamado quando: (a) mutex está travado ao receber novas entregas,
  /// ou (b) o loop OSRM falha com erro inesperado.
  void _emitirFallbackImediato() {
    final lat = _motoristaLat;
    final lng = _motoristaLng;
    if (lat == null || lng == null) return;

    final Map<String, String> fallbackMap = {};
    for (final entrega in _entregas) {
      final latDest = _parseDouble(entrega['lat']);
      final lngDest = _parseDouble(entrega['lng']);
      final id = entrega['id']?.toString() ?? '';
      if (id.isEmpty) continue;

      if (latDest == null || lngDest == null) {
        fallbackMap[id] = 'Sem GPS';
        continue;
      }

      // Verifica cache OSRM antes de calcular linha reta
      final chaveCache = _chaveOsrm(
        _ultimoLat ?? lat, _ultimoLng ?? lng, latDest, lngDest,
      );
      final distCache = _cacheOsrm[chaveCache];

      if (distCache != null) {
        // Ajusta cache com deslocamento local se disponível
        if (_ultimoLat != null && _ultimoLng != null) {
          final deslocadoKm =
              Geolocator.distanceBetween(_ultimoLat!, _ultimoLng!, lat, lng) /
              1000.0;
          final distAjustada = (distCache - deslocadoKm).clamp(0.1, double.infinity);
          fallbackMap[id] = '${distAjustada.toStringAsFixed(1)} km';
        } else {
          fallbackMap[id] = '${distCache.toStringAsFixed(1)} km';
        }
      } else {
        // Linha reta geodésica (WGS-84) × 1.45 como estimativa de rota
        final distMetros = Geolocator.distanceBetween(lat, lng, latDest, lngDest);
        final distEstimada = (distMetros / 1000.0) * 1.45;
        fallbackMap[id] = '~${distEstimada.toStringAsFixed(1)} km';
      }
    }

    if (fallbackMap.isNotEmpty) {
      distanciasNotifier.value = Map.from(fallbackMap);
    }
  }

  // ─── Watchdog Timer (anti-deadlock do mutex) ───

  /// Inicia o watchdog que força o desbloqueio do mutex após [_timeoutMutex].
  /// Evita deadlock caso uma exceção não capturada impeça o finally de rodar.
  void _iniciarWatchdog() {
    _cancelarWatchdog();
    _watchdogTimer = Timer(_timeoutMutex, () {
      if (_isFetching) {
        print('⏰ WATCHDOG: Mutex travado além de ${_timeoutMutex.inSeconds}s. '
            'Forçando desbloqueio e emitindo fallback geodésico.');
        _isFetching = false;
        _emitirFallbackImediato();
      }
    });
  }

  /// Cancela o watchdog (chamado no finally do mutex).
  void _cancelarWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  /// Consulta o OSRM e retorna um record tipado `({double km, bool fromOsrm})`.
  ///
  /// • `fromOsrm = true`  → valor real de rota, gravado no cache permanente.
  /// • `fromOsrm = false` → fallback volátil de linha reta (WGS-84 × 1.45),
  ///                        NÃO gravado no cache para preservar a retomada automática.
  ///
  /// Proteções:
  ///   • .timeout([_timeoutOsrm]) com onTimeout explícito
  ///   • catch tipado separado: TimeoutException vs outros erros de rede
  ///   • Cache hit retorna imediatamente com fromOsrm = true
  Future<({double km, bool fromOsrm})> _obterDistanciaOsrm(
    double latO, double lngO, double latD, double lngD,
  ) async {
    final chave = _chaveOsrm(latO, lngO, latD, lngD);

    // Cache hit: resultado já confirmado pelo OSRM anteriormente
    if (_cacheOsrm.containsKey(chave)) {
      return (km: _cacheOsrm[chave]!, fromOsrm: true);
    }

    try {
      final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/'
        '$lngO,$latO;$lngD,$latD'
        '?overview=false',
      );

      // Timeout de 5s: evita requisição pendurada durante troca Wi-Fi → 4G
      final response = await http.get(url).timeout(
        _timeoutOsrm,
        onTimeout: () {
          throw TimeoutException(
            'OSRM não respondeu em ${_timeoutOsrm.inSeconds}s',
            _timeoutOsrm,
          );
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            (data['routes'] as List).isNotEmpty) {
          final double distKm =
              (data['routes'][0]['distance'] as num).toDouble() / 1000.0;
          // Grava no cache permanente SOMENTE quando OSRM responde com sucesso
          _cacheOsrm[chave] = distKm;
          return (km: distKm, fromOsrm: true);
        }
      }
    } on TimeoutException catch (e) {
      print('⏱️ OSRM timeout: $e — fallback volátil (cache preservado vazio).');
    } catch (e) {
      print('⚠️ OSRM falhou: $e — fallback volátil (cache preservado vazio).');
    }

    // Fallback volátil: distância geodésica WGS-84 × 1.45.
    // NÃO grava no cache → próximo ciclo GPS retentará OSRM automaticamente.
    final distMetros = Geolocator.distanceBetween(latO, lngO, latD, lngD);
    return (km: (distMetros / 1000.0) * 1.45, fromOsrm: false);
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
