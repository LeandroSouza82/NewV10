import 'package:flutter/material.dart';

import 'dart:convert';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/app_colors.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/info_card.dart';
import '../widgets/success_status.dart';
import '../widgets/draggable_route_list.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';
import '../services/location_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'splash_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  // Stream instanciado UMA vez — não recria conexão a cada build
  Stream<List<Map<String, dynamic>>> _rotasStream = SupabaseService.getRotasAtivas();
  StreamSubscription? _connectivitySubscription;

  Map<String, dynamic>? _motorista;
  bool _isLoadingPhoto = false;
  bool _isOnline = false;
  bool hasInternet = true;
  bool _isUpdatingStatus = false;
  String navegadorSelecionado = 'maps';
  List<Map<String, dynamic>> _entregasCacheadas = [];

  String get _saudacao {
    final hora = DateTime.now().hour;
    if (hora >= 0 && hora < 12) {
      return 'Bom dia';
    } else if (hora >= 12 && hora < 18) {
      return 'Boa tarde';
    } else {
      return 'Boa noite';
    }
  }

  @override
  void initState() {
    super.initState();
    _carregarCacheEntregas();
    _carregarMotorista();
    _carregarNavegador();
    
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (mounted) {
        setState(() {
          hasInternet = results.any((r) => r != ConnectivityResult.none);
        });

        if (hasInternet) {
          _recarregarDadosAoVoltarOnline();
        }
      }
    });
  }

  Future<void> _recarregarDadosAoVoltarOnline() async {
    await _carregarMotorista();
    
    if (mounted) {
      setState(() {
        _rotasStream = SupabaseService.getRotasAtivas();
      });
    }
  }

  Future<void> _carregarCacheEntregas() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheString = prefs.getString('cache_entregas_motorista');
    if (cacheString != null && mounted) {
      setState(() {
        final List<dynamic> decoded = jsonDecode(cacheString);
        _entregasCacheadas = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    }
  }

  Future<void> _salvarCacheEntregas(List<Map<String, dynamic>> entregas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache_entregas_motorista', jsonEncode(entregas));
  }

  Future<void> _carregarNavegador() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      navegadorSelecionado = prefs.getString('navegador_padrao') ?? 'maps';
    });
  }

  Future<void> _salvarNavegador(String valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('navegador_padrao', valor);
    setState(() {
      navegadorSelecionado = valor;
    });
  }

  void _mostrarDialogoNavegador(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Navegador Padrão', style: TextStyle(color: AppColors.textWhite)),
          content: RadioGroup<String>(
            groupValue: navegadorSelecionado,
            onChanged: (String? value) {
              if (value != null) {
                _salvarNavegador(value);
                Navigator.pop(context);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('Google Maps', style: TextStyle(color: AppColors.textWhite)),
                  value: 'maps',
                  activeColor: AppColors.successGreen,
                ),
                RadioListTile<String>(
                  title: const Text('Waze', style: TextStyle(color: AppColors.textWhite)),
                  value: 'waze',
                  activeColor: AppColors.successGreen,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _carregarMotorista() async {
    final id = SupabaseService.currentMotoristaId;
    if (id != null) {
      final dados = await SupabaseService.getMotorista(id);
      if (mounted && dados != null) {
        setState(() {
          _motorista = dados;
          _isOnline = dados['esta_online'] ?? false;
        });

        if (_isOnline) {
          LocationService.iniciarRastreamento(id);
          SupabaseService.iniciarEscutaNovasEntregas(id);
        }
      }
    }
  }

  Future<void> _mudarStatus() async {
    final id = SupabaseService.currentMotoristaId;
    if (id == null) return;

    final novoEstado = !_isOnline;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      await SupabaseService.alternarStatusOnline(id, novoEstado);
      if (mounted) {
        setState(() {
          _isOnline = novoEstado;
        });

        if (_isOnline) {
          LocationService.iniciarRastreamento(id);
          SupabaseService.iniciarEscutaNovasEntregas(id);
          
          final isGranted = await FlutterOverlayWindow.isPermissionGranted();
          if (!isGranted) {
            final granted = await FlutterOverlayWindow.requestPermission();
            if (granted == false && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('A permissão de sobreposição é necessária para exibir alertas de nova entrega.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          }
        } else {
          LocationService.pararRastreamento();
          SupabaseService.pararEscutaNovasEntregas();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(novoEstado ? 'Você está Online' : 'Você ficou Offline'),
              backgroundColor: novoEstado ? AppColors.successGreen : Colors.grey,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao mudar status. Verifique sua conexão.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  Future<void> _atualizarFoto(ImageSource source) async {
    final id = SupabaseService.currentMotoristaId;
    if (id == null) return;

    setState(() {
      _isLoadingPhoto = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Atualizando foto...')),
    );

    try {
      final novaUrl = await SupabaseService.atualizarFotoPerfil(id, source);
      if (novaUrl != null && mounted) {
        setState(() {
          if (_motorista != null) {
            _motorista!['avatar_path'] = novaUrl;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto atualizada com sucesso!'), backgroundColor: AppColors.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao atualizar foto.'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPhoto = false;
        });
      }
    }
  }

  void _mostrarOpcoesDeFoto(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundBody,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.textWhite),
                title: const Text('Tirar foto', style: TextStyle(color: AppColors.textWhite)),
                onTap: () {
                  Navigator.pop(context);
                  _atualizarFoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.textWhite),
                title: const Text('Escolher da galeria', style: TextStyle(color: AppColors.textWhite)),
                onTap: () {
                  Navigator.pop(context);
                  _atualizarFoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _fazerLogout() async {
    LocationService.pararRastreamento();
    SupabaseService.pararEscutaNovasEntregas();
    
    try {
      await SupabaseService.logout().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Logout offline: limpando dados locais.');
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SplashView()),
          (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    LocationService.pararRastreamento();
    SupabaseService.pararEscutaNovasEntregas();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        backgroundColor: AppColors.backgroundBody,
        child: SafeArea(
          child: Column(
            children: [
              // Cabeçalho do Drawer Customizado
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.textGrey.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _isLoadingPhoto ? null : () => _mostrarOpcoesDeFoto(context),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.cardBackground,
                              border: Border.all(
                                color: AppColors.successGreen.withValues(alpha: 0.5),
                                width: 2,
                              ),
                              image: _motorista != null && _motorista!['avatar_path'] != null
                                  ? DecorationImage(
                                      image: NetworkImage(_motorista!['avatar_path']),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _motorista == null || _motorista!['avatar_path'] == null
                                ? const Icon(
                                    Icons.person,
                                    color: AppColors.textGrey,
                                    size: 40,
                                  )
                                : null,
                          ),
                          if (_isLoadingPhoto)
                            const CircularProgressIndicator(color: AppColors.successGreen),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _motorista != null 
                          ? '$_saudacao, ${_motorista!['nome'] ?? 'Motorista'}'
                          : 'Carregando...',
                      style: const TextStyle(
                        color: AppColors.textWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _motorista != null ? (_motorista!['email'] ?? 'V10 Delivery') : 'V10 Delivery',
                      style: TextStyle(
                        color: AppColors.textGrey.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.map, color: AppColors.textWhite),
                title: const Text('Navegador Padrão', style: TextStyle(color: AppColors.textWhite)),
                subtitle: Text(
                  navegadorSelecionado == 'waze' ? 'Waze' : 'Google Maps',
                  style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8)),
                ),
                onTap: () => _mostrarDialogoNavegador(context),
              ),
              const Spacer(),
              // Botão de Sair
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  title: const Text(
                    'Sair',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: Colors.redAccent.withValues(alpha: 0.08),
                  onTap: () {
                    Navigator.of(context).pop(); // Fecha o Drawer
                    _fazerLogout();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Fundo
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.backgroundBody, Colors.black],
              ),
            ),
          ),
          
          // Conexão em Tempo Real
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _rotasStream,
            builder: (context, snapshot) {
              // Tela de Carregamento Inicial (apenas se não houver cache)
              if (snapshot.connectionState == ConnectionState.waiting && _entregasCacheadas.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.successGreen),
                );
              }

              // Atualiza o cache silenciosamente se houver dados novos
              if (snapshot.hasData && !snapshot.hasError) {
                // Compara para evitar regravações inúteis
                if (jsonEncode(_entregasCacheadas) != jsonEncode(snapshot.data)) {
                  _entregasCacheadas = snapshot.data!;
                  Future.microtask(() => _salvarCacheEntregas(_entregasCacheadas));
                }
              }

              final bool isOfflineErro = snapshot.hasError;
              // Filtra entregas já finalizadas localmente para evitar efeito ioiô
              final rotasAtivas = _entregasCacheadas
                  .where((r) => !SyncService.idsFinalizadosLocalmente.contains(r['id'].toString()))
                  .toList();
              bool isFinalizado = rotasAtivas.isEmpty;
              
              // Contagem Dinâmica
              int qtdEntregas = rotasAtivas.where((r) => r['tipo'].toString().toLowerCase() == 'entrega').length;
              int qtdColetas = rotasAtivas.where((r) => r['tipo'].toString().toLowerCase() == 'coleta' || r['tipo'].toString().toLowerCase() == 'recolha').length;
              int qtdOutros = rotasAtivas.length - (qtdEntregas + qtdColetas);

              return Column(
                children: [
                  CustomAppBar(
                    driverName: _motorista != null ? (_motorista!['nome'] ?? 'Motorista') : 'Carregando...',
                    avatarUrl: _motorista != null ? _motorista!['avatar_path'] : null,
                    isOnline: hasInternet,
                    isUpdatingStatus: _isUpdatingStatus,
                    onToggleStatus: _mudarStatus,
                  ),
                  
                  // Banner de Aviso Discreto de Offline (Cache Mode)
                  if (isOfflineErro && _entregasCacheadas.isNotEmpty)
                    Container(
                      width: double.infinity,
                      color: Colors.orange.withValues(alpha: 0.2),
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'Modo Offline. Exibindo dados salvos.',
                            style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                  // Cards com os números REAIS do banco
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InfoCard(
                          title: 'Entregas',
                          value: qtdEntregas.toString(),
                          accentColor: AppColors.borderEntregas,
                          icon: Icons.local_shipping_outlined,
                        ),
                        InfoCard(
                          title: 'Coleta',
                          value: qtdColetas.toString(),
                          accentColor: AppColors.borderRecolha,
                          icon: Icons.inventory_2_outlined,
                        ),
                        InfoCard(
                          title: 'Outros',
                          value: qtdOutros.toString(),
                          accentColor: AppColors.borderOutros,
                          icon: Icons.more_horiz_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Lógica da Lista vs Sucesso vs Offline
                  Expanded(
                    child: (isOfflineErro && rotasAtivas.isEmpty)
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.wifi_off, color: Colors.grey, size: 60),
                                const SizedBox(height: 24),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 32.0),
                                  child: Text(
                                    'Você está offline. O aplicativo sincronizará os dados automaticamente assim que a conexão for restabelecida.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.textWhite, fontSize: 16, height: 1.5),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      // Dispara rebuild para o Stream Builder tentar nova conexão
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.successGreen,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.refresh_rounded, color: Colors.black),
                                  label: const Text(
                                    'Tentar novamente',
                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : isFinalizado 
                            ? const SuccessStatus() 
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.route_rounded, color: AppColors.textGrey, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'FILA DE ROTEIRIZAÇÃO',
                                          style: TextStyle(
                                            color: AppColors.textGrey.withValues(alpha: 0.9),
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              Expanded(
                                child: DraggableRouteList(
                                  key: ValueKey(rotasAtivas.length),
                                  rotasIniciais: rotasAtivas,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            }
          ),
        ],
      ),
    );
  }
}
