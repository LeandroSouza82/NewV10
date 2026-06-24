// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:app_do_motorista/services/notification_service.dart';

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
              final isGranted = await FlutterOverlayWindow.isPermissionGranted();
              if (isGranted) {
                final isActive = await FlutterOverlayWindow.isActive();
                if (!isActive) {
                  await AudioService.playChamaNoOverlay();
                  await FlutterOverlayWindow.showOverlay(
                    enableDrag: true,
                    overlayTitle: "Nova Entrega",
                    overlayContent: "Você tem uma nova atribuição",
                    flag: OverlayFlag.defaultFlag,
                    visibility: NotificationVisibility.visibilityPublic,
                    positionGravity: PositionGravity.auto,
                    height: 300,
                    width: WindowSize.matchParent,
                  );
                  _agendarFechamentoOverlay();
                }
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

  static void _agendarFechamentoOverlay() {
    Future.delayed(const Duration(seconds: 30), () async {
      bool isActive = await FlutterOverlayWindow.isActive();
      if (isActive) {
        debugPrint('Fechando overlay externamente por timeout...');
        await FlutterOverlayWindow.closeOverlay();
      }
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
        final dados = await client
            .from('entregas')
            .select()
            .eq('motorista_id', currentMotoristaId!)
            .or('status.eq.pendente,status.eq.em_rota');
        
        final list = dados.map((linha) {
          return {
            'id': linha['id'].toString(),
            'tipo': linha['tipo'] ?? 'Sem Tipo',
            'cliente': linha['cliente'] ?? 'Sem Cliente',
            'endereco': linha['endereco'] ?? 'Sem Endereço',
            'aviso': linha['observacoes'] ?? linha['obs'] ?? '',
            'lat': linha['lat'] != null ? double.tryParse(linha['lat'].toString()) : null,
            'lng': linha['lng'] != null ? double.tryParse(linha['lng'].toString()) : null,
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
              final isForeground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

              if (!isForeground) {
                print('✅ Rota REALMENTE nova detectada via REST e app em background! Disparando overlay...');
                try {
                  final bool isGranted = await FlutterOverlayWindow.isPermissionGranted();
                  if (isGranted) {
                    await AudioService.playChamaNoOverlay();
                    await FlutterOverlayWindow.showOverlay(
                      enableDrag: true,
                      overlayTitle: "V10 Delivery",
                      overlayContent: "Nova rota disponível",
                      flag: OverlayFlag.defaultFlag,
                      visibility: NotificationVisibility.visibilityPublic,
                      positionGravity: PositionGravity.auto,
                      height: WindowSize.matchParent,
                      width: WindowSize.matchParent,
                    );
                    _agendarFechamentoOverlay();
                    print('✅ Overlay disparado com sucesso pelo plugin!');
                  } else {
                    print('❌ FALHA: Permissão de sobreposição negada no Android.');
                  }
                } catch (e, stacktrace) {
                  print('🚨 ERRO FATAL AO DESENHAR OVERLAY: $e');
                  print(stacktrace);
                }
              } else {
                print('✅ Rota nova detectada via REST, mas app está aberto. Não disparando overlay.');
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
      realtimeSubscription = client
          .from('entregas')
          .stream(primaryKey: ['id'])
          .eq('motorista_id', currentMotoristaId!)
          .map((dados) {
            // Filtro local adicional
            return dados
                .where((linha) => linha['status'] == 'pendente' || linha['status'] == 'em_rota')
                .map((linha) {
              return {
                'id': linha['id'].toString(),
                'tipo': linha['tipo'] ?? 'Sem Tipo',
                'cliente': linha['cliente'] ?? 'Sem Cliente',
                'endereco': linha['endereco'] ?? 'Sem Endereço',
                'aviso': linha['observacoes'] ?? linha['obs'] ?? '',
                'lat': linha['lat'] != null ? double.tryParse(linha['lat'].toString()) : null,
                'lng': linha['lng'] != null ? double.tryParse(linha['lng'].toString()) : null,
              };
            }).toList();
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
                  final isForeground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

                  if (!isForeground) {
                    print('✅ Rota REALMENTE nova detectada via REALTIME e app em background! Disparando overlay...');
                    try {
                      final bool isGranted = await FlutterOverlayWindow.isPermissionGranted();
                      if (isGranted) {
                        await AudioService.playChamaNoOverlay();
                        await FlutterOverlayWindow.showOverlay(
                          enableDrag: true,
                          overlayTitle: "V10 Delivery",
                          overlayContent: "Nova rota disponível",
                          flag: OverlayFlag.defaultFlag,
                          visibility: NotificationVisibility.visibilityPublic,
                          positionGravity: PositionGravity.auto, 
                          height: WindowSize.matchParent,
                          width: WindowSize.matchParent,
                        );
                        _agendarFechamentoOverlay();
                        print('✅ Overlay disparado com sucesso pelo plugin!');
                      } else {
                        print('❌ FALHA: Permissão de sobreposição negada no Android.');
                      }
                    } catch (e, stacktrace) {
                      print('🚨 ERRO FATAL AO DESENHAR OVERLAY: $e');
                      print(stacktrace);
                    }
                  } else {
                    print('✅ Rota nova detectada via REALTIME, mas app está aberto. Não disparando overlay.');
                  }
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
      print('⚡ SOCKET MONITOR: Estado da conexão = $state (conectado = $isConnected)');
      
      if (!isConnected) {
        print('⚡ SOCKET MONITOR: Socket desconectado. Atualizando via Polling.');
        fetchViaRest();
      }
    });

    startRealtime();

    controller.onCancel = () {
      print('⚡ SYSTEM: Cancelando inscrições e timers da stream de entregas.');
      realtimeSubscription?.cancel();
      fallbackTimer?.cancel();
      pollingTimer?.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // Obtém dados do motorista atual
  static Future<Map<String, dynamic>?> getMotorista(String id) async {
    try {
      return await client.from('motoristas').select().eq('id', id).maybeSingle();
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
}
