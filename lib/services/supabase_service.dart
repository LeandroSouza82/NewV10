// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/chamada_model.dart';
import '../views/chamadas/widgets/chamada_card.dart';
import 'package:app_do_motorista/services/notification_service.dart';
import '../core/utils/location_utils.dart';
class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;
  
  // Variável em memória rápida para o filtro do Stream
  static String? currentMotoristaId;

  static RealtimeChannel? _entregasChannel;
  static Set<String> _idsRotasConhecidas = {};
  static bool _isPrimeiraBusca = true;

  // Autenticação Customizada
  static Future<void> login(String email, String password) async {
    final response = await client
        .from('motoristas')
        .select()
        .ilike('email', email)
        .eq('senha', password)
        .maybeSingle();

    if (response == null) {
      throw Exception('E-mail ou senha incorretos.');
    }

    // Atualização agressiva: sobrescrevemos o status e a última atualização
    // para "expulsar" qualquer atualização vinda do app antigo.
    await client
        .from('motoristas')
        .update({
          'esta_online': true,
          'status': 'disponivel',
          'aprovado': true, // Garantindo que o Dashboard veja como aprovado
          'ultima_atualizacao': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', response['id']);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('motorista_id', response['id']);
    if (response['nome'] != null) {
      await prefs.setString('nome_motorista', response['nome']);
    }
    currentMotoristaId = response['id'];
  }

  // Verifica se o motorista já está salvo e avisa o banco que ele entrou
  static Future<bool> isLogado() async {
    final prefs = await SharedPreferences.getInstance();
    currentMotoristaId = prefs.getString('motorista_id'); 
    
    if (currentMotoristaId != null) {
      try {
        // Mágica: Atualiza o status para online no auto-login (Fire and Forget)
        client.from('motoristas').update({
          'esta_online': true,
          'status': 'disponivel',
          'aprovado': true, // Garantindo que o Dashboard veja como aprovado
          'ultima_atualizacao': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', currentMotoristaId!).then((_) {}).catchError((_) {});
      } catch (e) {
        // Ignora o erro silenciosamente caso a internet oscile na abertura
      }
      return true;
    }
    return false;
  }

  // Desconecta o motorista
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final motoristaId = prefs.getString('motorista_id');
    
    if (motoristaId != null) {
      await client.from('motoristas').update({'esta_online': false}).eq('id', motoristaId);
    }
    
    await prefs.remove('motorista_id');
    await prefs.remove('manter_logado');
    currentMotoristaId = null;
  }

  // Inicializa monitoramento do socket Realtime para diagnóstico de conexão
  static void initializeMonitoring() {
    print('⚡ SUPABASE MONITOR: Inicializando monitoramento do Socket Realtime...');
    client.realtime.onOpen(() {
      print('⚡ SOCKET EVENT: Conectado (Open)');
    });
    client.realtime.onClose((event) {
      print('⚡ SOCKET EVENT: Desconectado (Closed). Evento: $event');
    });
    client.realtime.onError((error) {
      print('⚡ SOCKET EVENT: Erro na conexão: $error');
    });
  }

  // Inicia a escuta de Novas Entregas para disparar o Overlay
  static void iniciarEscutaNovasEntregas(String motoristaId) {
    pararEscutaNovasEntregas();

    _entregasChannel = client.channel('public:entregas');
    _entregasChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'entregas',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'motorista_id',
        value: motoristaId,
      ),
      callback: (payload) async {
        WidgetsFlutterBinding.ensureInitialized();
        print('🔔 Alteração de entrega recebida via Realtime: ${payload.newRecord}');
        
        final newRecord = payload.newRecord;
        final oldRecord = payload.oldRecord;
        
        if (newRecord.isEmpty) return;
        
        final motoristaIdRecebido = newRecord['motorista_id']?.toString();
        final statusNovo = newRecord['status']?.toString();
        final statusAntigo = oldRecord.isNotEmpty ? oldRecord['status']?.toString() : null;

        if (motoristaIdRecebido == motoristaId && statusNovo == 'em_rota') {
          if (statusAntigo != 'em_rota') {
            await AudioService.playChama(); // Toca incondicionalmente
            final lifecycleState = WidgetsBinding.instance.lifecycleState;
            final isBackground = lifecycleState == AppLifecycleState.paused || 
                                 lifecycleState == AppLifecycleState.inactive || 
                                 lifecycleState == AppLifecycleState.hidden;
            
            if (isBackground) {
              print('✅ Rota recebida em background. Exibindo notificacao local e disparando Overlay nativo...');
              await NotificationService.showRotaRecebida();
              
              try {
                const MethodChannel mainChannel = MethodChannel('com.v10.delivery/main_overlay');
                final bool temPermissao = await mainChannel.invokeMethod('checkOverlayPermission');
                
                if (!temPermissao) {
                  await mainChannel.invokeMethod('requestOverlayPermission');
                  print('⚠️ Solicitando permissão de overlay ao usuário...');
                } else {
                  final mapToEncode = Map<String, dynamic>.from(newRecord);
                  
                  if (mapToEncode['lat'] != null && mapToEncode['lng'] != null) {
                    try {
                      final pos = await Geolocator.getLastKnownPosition();
                      if (pos != null) {
                        final lat = double.tryParse(mapToEncode['lat'].toString()) ?? 0.0;
                        final lng = double.tryParse(mapToEncode['lng'].toString()) ?? 0.0;
                        if (lat != 0.0 && lng != 0.0) {
                          final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/${pos.longitude},${pos.latitude};$lng,$lat?overview=false');
                          final res = await http.get(url).timeout(const Duration(seconds: 3));
                          if (res.statusCode == 200) {
                            final dataOsrm = jsonDecode(res.body);
                            final kmOsrm = (dataOsrm['routes'][0]['distance'] as num) / 1000.0;
                            mapToEncode['distancia'] = kmOsrm;
                            print('✅ OSRM: Distância real confirmada para o Overlay: $kmOsrm km');
                          }
                        }
                      }
                    } catch (e) {
                      print('❌ Erro no cálculo OSRM para o Overlay: $e');
                    }
                  }

                  print('📦 PAYLOAD OVERLAY: KM preparado = ${mapToEncode['distancia']}');
                  await _dispararOverlaySeguro(mapToEncode);
                }
              } catch (e) {
                print('❌ Erro ao disparar Overlay Nativo: $e');
              }
            } else {
              print('✅ Exibindo ChamadaCard popup no Foreground...');
              final contexto = navigatorKey.currentContext;
              if (contexto != null) {
                final id = newRecord['id']?.toString() ?? '';
                final String tipoOriginal = newRecord['tipo']?.toString().toUpperCase() ?? 'ENTREGA';
                final String tipoTag = (tipoOriginal.contains('COLETA') || tipoOriginal.contains('RECOLHA')) 
                    ? 'COLETA' : (tipoOriginal.contains('OUTROS') ? 'OUTROS' : 'ENTREGA');
                
                final model = ChamadaModel(
                  id: id,
                  tipo: TipoChamada.simples,
                  status: StatusChamada.recebida,
                  horario: DateTime.now(),
                  tipoPedido: tipoTag,
                  cliente: newRecord['cliente']?.toString() ?? 'Nova Rota Recebida',
                  endereco: newRecord['endereco']?.toString() ?? 'Endereço não informado',
                  bairro: '',
                  cidade: '',
                  distancia: 0.0,
                );
                if (!contexto.mounted) return;
                showDialog(
                  context: contexto,
                  builder: (context) {
                    return Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ChamadaCard(chamada: model),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[800],
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                child: const Text('FECHAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF64B5F6),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                child: const Text('ACEITAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                );
              }
            }
          }
        }
      },
    );
    
    Future.microtask(() {
      _entregasChannel!.subscribe();
    });
  }

  static void pararEscutaNovasEntregas() {
    if (_entregasChannel != null) {
      client.removeChannel(_entregasChannel!);
      _entregasChannel = null;
    }
  }

  // Atualiza o status de uma entrega
  static Future<void> atualizarStatusEntrega(String entregaId, String novoStatus) async {
    print("AVISO: Tentando atualizar uma entrega para status: $novoStatus");
    await client
        .from('entregas')
        .update({'status': novoStatus})
        .eq('id', entregaId);
  }

  static Stream<List<Map<String, dynamic>>> getRotasAtivas() {
    if (currentMotoristaId == null) return const Stream.empty();

    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    StreamSubscription? realtimeSubscription;
    Timer? fallbackTimer;
    Timer? pollingTimer;
    bool hasReceivedData = false;

    // Função para buscar os dados via REST
    Future<void> fetchViaRest() async {
      print('⚡ FALLBACK: Buscando entregas via REST...');
      try {
        final dataLimite = DateTime.now().toUtc().subtract(const Duration(days: 7)).toIso8601String();

        final dados = await client
            .from('entregas')
            .select()
            .eq('motorista_id', currentMotoristaId!)
            .gte('created_at', dataLimite)
            .or('status.eq.pendente,status.eq.em_rota')
            .order('ordem_logistica', ascending: true);
        
        final list = dados.map((linha) {
          return {
            'id': linha['id'].toString(),
            'tipo': linha['tipo'] ?? 'Sem Tipo',
            'cliente': linha['cliente'] ?? 'Sem Cliente',
            'endereco': linha['endereco'] ?? 'Sem Endereço',
            'aviso': linha['observacoes'] ?? linha['obs'] ?? '',
            'lat': linha['lat'] != null ? double.tryParse(linha['lat'].toString()) : null,
            'lng': linha['lng'] != null ? double.tryParse(linha['lng'].toString()) : null,
            'ordem_logistica': linha['ordem_logistica'],
          };
        }).toList();
        
        if (!controller.isClosed) {
          print('⚡ FALLBACK: Dados REST recebidos com sucesso. Qtd: ${list.length}');
          
          if (list.isEmpty && !_isPrimeiraBusca && _idsRotasConhecidas.isNotEmpty) {
            await AudioService.playFinal();
          }

          Set<String> idsAtuais = list.map((rota) => rota['id'].toString()).toSet();

          if (_isPrimeiraBusca) {
            _idsRotasConhecidas = idsAtuais;
            _isPrimeiraBusca = false;
          } else {
            bool temRotaNova = idsAtuais.any((id) => !_idsRotasConhecidas.contains(id));

            if (temRotaNova) {
              await NotificationService.showRotaRecebida(); // Dispara notificação com som 'chama'
              print('✅ Rota nova via REST detectada.');

              final rotaNovaId = idsAtuais.firstWhere((id) => !_idsRotasConhecidas.contains(id));
              final rotaNovaMap = list.firstWhere((rota) => rota['id'].toString() == rotaNovaId);

              final lifecycleState = WidgetsBinding.instance.lifecycleState;
              final isBackground = lifecycleState == AppLifecycleState.paused || 
                                   lifecycleState == AppLifecycleState.inactive || 
                                   lifecycleState == AppLifecycleState.hidden;
                                   
              if (isBackground) {
                print('I/flutter (12932): 🚀 DISPARANDO OVERLAY VIA REST/POLLING');
                try {
                  const MethodChannel mainChannel = MethodChannel('com.v10.delivery/main_overlay');
                  final bool temPermissao = await mainChannel.invokeMethod('checkOverlayPermission');
                  
                  if (!temPermissao) {
                    await mainChannel.invokeMethod('requestOverlayPermission');
                    print('⚠️ Solicitando permissão de overlay ao usuário...');
                  } else {
                    final mapToEncode = Map<String, dynamic>.from(rotaNovaMap);
                    
                    if (mapToEncode['lat'] != null && mapToEncode['lng'] != null) {
                      try {
                        final pos = await Geolocator.getLastKnownPosition();
                        if (pos != null) {
                          final lat = double.tryParse(mapToEncode['lat'].toString()) ?? 0.0;
                          final lng = double.tryParse(mapToEncode['lng'].toString()) ?? 0.0;
                          if (lat != 0.0 && lng != 0.0) {
                            final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/${pos.longitude},${pos.latitude};$lng,$lat?overview=false');
                            final res = await http.get(url).timeout(const Duration(seconds: 3));
                            if (res.statusCode == 200) {
                              final dataOsrm = jsonDecode(res.body);
                              final kmOsrm = (dataOsrm['routes'][0]['distance'] as num) / 1000.0;
                              mapToEncode['distancia'] = kmOsrm;
                              print('✅ OSRM (REST): Distância real confirmada para o Overlay: $kmOsrm km');
                            }
                          }
                        }
                      } catch (e) {
                        print('❌ Erro no cálculo OSRM (REST) para o Overlay: $e');
                      }
                    }

                    final rotaFiltrada = list.where((rota) => !_idsRotasConhecidas.contains(rota['id'].toString())).toList();
                    if (rotaFiltrada.isEmpty) rotaFiltrada.add(rotaNovaMap);

                    if (rotaFiltrada.length > 1) {
                      mapToEncode['isRoteiro'] = true;
                      mapToEncode['totalPedidos'] = rotaFiltrada.length;
                      mapToEncode['tipo'] = 'multipla';
                      
                      // Início (Ponto Verde)
                      final inicio = rotaFiltrada.first;
                      mapToEncode['inicioEndereco'] = (inicio['endereco'] ?? '').toString().replaceAll('*', '').trim();
                      mapToEncode['inicioCliente'] = (inicio['cliente'] ?? '').toString().replaceAll('*', '').trim();

                      // Fim (Ponto Coral) - OBRIGATÓRIO PEGAR O LAST
                      final fim = rotaFiltrada.last;
                      mapToEncode['fimEndereco'] = (fim['endereco'] ?? '').toString().replaceAll('*', '').trim();
                      mapToEncode['fimCliente'] = (fim['cliente'] ?? '').toString().replaceAll('*', '').trim();

                      if (rotaFiltrada.length > 1 && mapToEncode['inicioEndereco'] == mapToEncode['fimEndereco']) {
                         print("⚠️ ALERTA: Início e Fim idênticos detectados. Verifique se a lista está correta.");
                      }

                      print('🔍 DEBUG ROTA: Início=${mapToEncode['inicioCliente']} | Fim=${mapToEncode['fimCliente']}');
                      
                      final int coletas = rotaFiltrada.where((e) {
                        final t = (e['tipo'] ?? e['tipoServico'] ?? '').toString().toUpperCase();
                        return t.contains('COLETA') || t.contains('RECOLHA');
                      }).length;

                      final int outros = rotaFiltrada.where((e) {
                        final t = (e['tipo'] ?? e['tipoServico'] ?? '').toString().toUpperCase();
                        return t.contains('OUTRO');
                      }).length;

                      final int entregas = rotaFiltrada.length - (coletas + outros);
                      
                      mapToEncode['total_entregas'] = (coletas == 0 && outros == 0) ? rotaFiltrada.length : entregas;
                      mapToEncode['total_coletas'] = coletas;
                      mapToEncode['total_outros'] = outros;
                      
                      double kmTotalAcumulado = 0.0;
                      for (var item in rotaFiltrada) {
                        var valorKm = item['distancia'] ?? item['km'] ?? item['distanciaEstimada'];
                        
                        if (valorKm == null || valorKm == 0 || valorKm == 0.0 || valorKm == '0' || valorKm == '0.0') {
                          final latD = double.tryParse(item['lat']?.toString() ?? '');
                          final lngD = double.tryParse(item['lng']?.toString() ?? '');
                          if (latD != null && lngD != null) {
                            valorKm = await DistanciaService.instance.calcularDistanciaAte(latD, lngD);
                            item['distancia'] = valorKm;
                          }
                        }
                        
                        final kmConvertido = (valorKm is num) 
                            ? valorKm.toDouble() 
                            : (double.tryParse(valorKm.toString()) ?? 0.0);
                        
                        kmTotalAcumulado += kmConvertido;
                      }
                      
                      if (kmTotalAcumulado > 0.0) {
                        mapToEncode['km_total'] = double.parse(kmTotalAcumulado.toStringAsFixed(1));
                      } else {
                        mapToEncode['km_total'] = mapToEncode['distancia'];
                      }
                      
                      print('📦 OVERLAY DATA PREP -> Total KM Somado: ${mapToEncode['km_total']} | Fim: ${mapToEncode['fimEndereco']}');
                    }

                    print('📦 PAYLOAD OVERLAY (REST): KM preparado = ${mapToEncode['distancia']}');
                    await _dispararOverlaySeguro(mapToEncode);
                  }
                } catch (e) {
                  print('❌ Erro ao disparar Overlay Nativo (REST): $e');
                }
              }
            }
            _idsRotasConhecidas = idsAtuais;
          }

          controller.add(list);
          hasReceivedData = true;
        }
      } catch (e) {
        print('⚡ FALLBACK: Erro ao buscar via REST: $e');
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    // Inicia a escuta do Stream do Realtime
    void startRealtime() {
      print('⚡ REALTIME: Iniciando escuta da stream de entregas...');
      final dataLimiteDart = DateTime.now().subtract(const Duration(days: 7));
      realtimeSubscription = client
          .from('entregas')
          .stream(primaryKey: ['id'])
          .eq('motorista_id', currentMotoristaId!)
          .map((dados) {
            // Filtro local adicional
            final filtered = dados
                .where((linha) {
                  final statusOk = (linha['status'] == 'pendente' || linha['status'] == 'em_rota');
                  if (!statusOk) return false;
                  
                  final createdAtStr = linha['created_at'];
                  if (createdAtStr != null) {
                    final createdAtDate = DateTime.tryParse(createdAtStr.toString())?.toLocal();
                    if (createdAtDate != null && createdAtDate.isBefore(dataLimiteDart)) {
                      return false; // Ignora pendentes antigos demais
                    }
                  }
                  return true;
                })
                .map((linha) {
              return {
                'id': linha['id'].toString(),
                'tipo': linha['tipo'] ?? 'Sem Tipo',
                'cliente': linha['cliente'] ?? 'Sem Cliente',
                'endereco': linha['endereco'] ?? 'Sem Endereço',
                'aviso': linha['observacoes'] ?? linha['obs'] ?? '',
                'lat': linha['lat'] != null ? double.tryParse(linha['lat'].toString()) : null,
                'lng': linha['lng'] != null ? double.tryParse(linha['lng'].toString()) : null,
                'ordem_logistica': linha['ordem_logistica'],
              };
            }).toList();
            // Ordenação local por ordem_logistica (Realtime não suporta .order())
            filtered.sort((a, b) {
              final oa = a['ordem_logistica'];
              final ob = b['ordem_logistica'];
              if (oa == null && ob == null) return 0;
              if (oa == null) return 1;
              if (ob == null) return -1;
              return (oa as int).compareTo(ob as int);
            });
            return filtered;
          })
          .listen(
            (dados) async {
              // Convertendo de List<Map<dynamic, dynamic>> para List<Map<String, dynamic>>
              final mapped = dados.map((linha) => Map<String, dynamic>.from(linha)).toList();
              print('⚡ REALTIME: Dados recebidos via WebSocket. Qtd: ${mapped.length}');
              
              if (mapped.isEmpty && !_isPrimeiraBusca && _idsRotasConhecidas.isNotEmpty) {
                await AudioService.playFinal();
              }

              Set<String> idsAtuais = mapped.map((rota) => rota['id'].toString()).toSet();

              if (_isPrimeiraBusca) {
                _idsRotasConhecidas = idsAtuais;
                _isPrimeiraBusca = false;
              } else {
                bool temRotaNova = idsAtuais.any((id) => !_idsRotasConhecidas.contains(id));

                if (temRotaNova) {
                  await NotificationService.showRotaRecebida(); // Dispara notificação com som 'chama'
                  print('✅ Rota via REALTIME detectada.');
                }
                _idsRotasConhecidas = idsAtuais;
              }
              
              hasReceivedData = true;
              if (fallbackTimer != null) {
                fallbackTimer!.cancel();
                fallbackTimer = null;
              }
              if (!controller.isClosed) {
                controller.add(mapped);
              }
            },
            onError: (error) {
              print('⚡ REALTIME: Erro na stream: $error');
              // Se falhar o Realtime, aciona o fallback imediatamente
              fetchViaRest();
            },
            onDone: () {
              print('⚡ REALTIME: Stream finalizada.');
            }
          );
    }

    // Estado local para evitar Flood de logs
    String? ultimoEstadoLog;

    // Configura o timer de fallback de 5 segundos
    fallbackTimer = Timer(const Duration(seconds: 5), () {
      if (!hasReceivedData) {
        print('⚡ SYSTEM: Stream Realtime não respondeu em 5s. Acionando Polling de Segurança.');
        fetchViaRest();
      }
    });

    // Polling de segurança a cada 15 segundos caso a conexão do socket não esteja aberta
    pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      final state = client.realtime.connectionState;
      final isConnected = client.realtime.isConnected;
      
      final currentStateLog = '$state|$isConnected';
      if (ultimoEstadoLog != currentStateLog) {
        ultimoEstadoLog = currentStateLog;
        print('⚡ SOCKET MONITOR: Estado da conexão = $state (conectado = $isConnected)');
      }
      
      if (!isConnected) {
        if (ultimoEstadoLog != 'disconnected_fetch') {
          print('⚡ SOCKET MONITOR: Socket desconectado. Atualizando via Polling.');
          ultimoEstadoLog = 'disconnected_fetch';
        }
        fetchViaRest();
      }
    });

    startRealtime();

    controller.onCancel = () {
      print('⚡ SYSTEM: Cancelando inscrições e timers da stream de entregas.');
      realtimeSubscription?.cancel();
      realtimeSubscription = null;
      fallbackTimer?.cancel();
      fallbackTimer = null;
      pollingTimer?.cancel();
      pollingTimer = null;
      controller.close();
    };

    return controller.stream;
  }

  // Obtém dados do motorista atual
  static Future<Map<String, dynamic>?> getMotorista(String id) async {
    try {
      final motorista = await client.from('motoristas').select().eq('id', id).maybeSingle();
      if (motorista != null && motorista['nome'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('nome_motorista', motorista['nome']);
      }
      return motorista;
    } catch (e) {
      print('Erro ao obter motorista: $e');
      return null;
    }
  }

  // Atualiza foto de perfil com compressão máxima
  static Future<String?> atualizarFotoPerfil(String motoristaId, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 15,
        maxWidth: 400,
        maxHeight: 400,
      );

      if (image == null) return null;

      final file = File(image.path);
      final ext = image.name.split('.').last;
      final caminho = '$motoristaId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // Upload pro Supabase Storage
      await client.storage.from('avatars').upload(
        caminho, 
        file, 
        fileOptions: const FileOptions(upsert: true)
      );

      // Obtém URL pública
      final publicUrl = client.storage.from('avatars').getPublicUrl(caminho);

      // Atualiza tabela
      await client.from('motoristas').update({'avatar_path': publicUrl}).eq('id', motoristaId);

      return publicUrl;
    } catch (e) {
      print('Erro ao atualizar foto: $e');
      throw Exception('Não foi possível atualizar a foto.');
    }
  }

  // Alterna o status online/offline do motorista
  static Future<void> alternarStatusOnline(String motoristaId, bool novoStatus) async {
    await client.from('motoristas').update({
      'esta_online': novoStatus,
      'status': novoStatus ? 'disponivel' : 'indisponivel'
    }).eq('id', motoristaId);
  }

  // Verifica saúde da conexão e tenta reconectar silenciosamente
  static void checkAndReconnect() {
    print('⚡ SYSTEM: Verificando saúde do Supabase Realtime (Lifecycle Resumed)...');
    try {
      final isConnected = client.realtime.isConnected;
      if (!isConnected) {
        print('⚡ SYSTEM: Supabase Realtime desconectado. Forçando reconexão...');
        // O Supabase tenta reconectar automaticamente
        // Não é necessário chamar connect manualmente (membro interno).
        
        // Se já tem motorista logado e online, garantimos que a escuta de entregas está ativa
        if (currentMotoristaId != null) {
          // Re-inscreve para garantir que o canal "public:entregas" está ouvindo
          iniciarEscutaNovasEntregas(currentMotoristaId!);
        }
      } else {
        print('⚡ SYSTEM: Supabase Realtime já está conectado.');
      }
    } catch (e) {
      print('⚡ SYSTEM: Erro ao verificar conexão: $e');
    }
  }

  static Future<void> _dispararOverlaySeguro(Map<String, dynamic> payload) async {
    final kmParaVerificar = payload['km_total'] ?? payload['distancia'] ?? 0.0;
    final kmConvertidoParaVerificar = (kmParaVerificar is num) 
        ? kmParaVerificar.toDouble() 
        : (double.tryParse(kmParaVerificar.toString()) ?? 0.0);
    
    if (kmConvertidoParaVerificar <= 0.0) {
      print("⚠️ OVERLAY BLOQUEADO (Gatekeeper): KM ainda não calculado ou zerado.");
      return; 
    }
    
    final String jsonPayload = jsonEncode(payload);
    const MethodChannel mainChannel = MethodChannel('com.v10.delivery/main_overlay');
    
    print('Disparando Overlay Nativo...');
    await mainChannel.invokeMethod('showOverlay', {'rota_json': jsonPayload});
    print('✅ Overlay nativo (Isolate) acionado com sucesso e KM validado!');
  }
}
