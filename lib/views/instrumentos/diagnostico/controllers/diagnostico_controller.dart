import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum StatusItem { pendente, checando, ok, alerta, erro }

class CheckItem {
  final String titulo;
  final String iconeKey;
  StatusItem status;
  String detalhe;

  CheckItem({
    required this.titulo,
    required this.iconeKey,
    this.status = StatusItem.pendente,
    this.detalhe = '',
  });
}

class DiagnosticoController {
  bool isScanning = false;

  late CheckItem itemRede;
  late CheckItem itemGPS;
  late CheckItem itemServidor;

  final void Function(void Function()) _setState;

  DiagnosticoController(this._setState) {
    _resetItens();
  }

  void _resetItens() {
    itemRede = CheckItem(titulo: 'Rede Móvel / Wi-Fi', iconeKey: 'network');
    itemGPS = CheckItem(titulo: 'Satélite GPS', iconeKey: 'gps');
    itemServidor = CheckItem(titulo: 'Servidor V10', iconeKey: 'server');
  }

  String get statusGeral {
    final itens = [itemRede, itemGPS, itemServidor];
    if (itens.any((i) => i.status == StatusItem.erro)) return 'Erro';
    if (itens.any((i) => i.status == StatusItem.alerta)) return 'Alerta';
    if (itens.every((i) => i.status == StatusItem.ok)) return 'OK';
    return 'Pendente';
  }

  Future<void> executarVarredura() async {
    _setState(() {
      isScanning = true;
      _resetItens();
    });

    // PASSO 1: Rede
    _setState(() => itemRede.status = StatusItem.checando);
    await Future.delayed(const Duration(milliseconds: 800));
    await _testarRede();

    // PASSO 2: GPS
    _setState(() => itemGPS.status = StatusItem.checando);
    await Future.delayed(const Duration(milliseconds: 600));
    await _testarGPS();

    // PASSO 3: Supabase Ping
    _setState(() => itemServidor.status = StatusItem.checando);
    await Future.delayed(const Duration(milliseconds: 600));
    await _testarServidor();

    _setState(() => isScanning = false);
  }

  Future<void> _testarRede() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result.contains(ConnectivityResult.mobile)) {
        _setState(() {
          itemRede.status = StatusItem.ok;
          itemRede.detalhe = 'Dados Móveis ativos';
        });
      } else if (result.contains(ConnectivityResult.wifi)) {
        _setState(() {
          itemRede.status = StatusItem.ok;
          itemRede.detalhe = 'Wi-Fi conectado';
        });
      } else {
        _setState(() {
          itemRede.status = StatusItem.erro;
          itemRede.detalhe = 'Sem conexão de rede';
        });
      }
    } catch (e) {
      _setState(() {
        itemRede.status = StatusItem.erro;
        itemRede.detalhe = 'Falha ao verificar rede';
      });
    }
  }

  Future<void> _testarGPS() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setState(() {
          itemGPS.status = StatusItem.alerta;
          itemGPS.detalhe = 'GPS desativado no aparelho';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _setState(() {
          itemGPS.status = StatusItem.erro;
          itemGPS.detalhe = 'Permissão permanentemente negada';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (position.accuracy <= 15) {
        _setState(() {
          itemGPS.status = StatusItem.ok;
          itemGPS.detalhe = 'Excelente — ${position.accuracy.toStringAsFixed(1)}m de precisão';
        });
      } else {
        _setState(() {
          itemGPS.status = StatusItem.alerta;
          itemGPS.detalhe = 'Sinal fraco — ${position.accuracy.toStringAsFixed(1)}m de precisão';
        });
      }
    } catch (e) {
      _setState(() {
        itemGPS.status = StatusItem.alerta;
        itemGPS.detalhe = 'Não foi possível obter localização';
      });
    }
  }

  Future<void> _testarServidor() async {
    try {
      final sw = Stopwatch()..start();
      await Supabase.instance.client.from('motoristas').select('id').limit(1);
      sw.stop();
      final latencia = sw.elapsedMilliseconds;

      if (latencia < 500) {
        _setState(() {
          itemServidor.status = StatusItem.ok;
          itemServidor.detalhe = 'Online — ${latencia}ms de latência';
        });
      } else {
        _setState(() {
          itemServidor.status = StatusItem.alerta;
          itemServidor.detalhe = 'Lento — ${latencia}ms de latência';
        });
      }
    } catch (e) {
      _setState(() {
        itemServidor.status = StatusItem.erro;
        itemServidor.detalhe = 'Servidor inacessível';
      });
    }
  }
}
