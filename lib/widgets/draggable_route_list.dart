import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ignore: unused_import, unnecessary_import
import '../core/app_colors.dart';
import '../theme/theme_controller.dart';
import '../views/components/modal_baixa_entrega.dart';
import '../views/components/modal_falha_entrega.dart';
import '../core/utils/location_utils.dart';

class DraggableRouteList extends StatefulWidget {
  final List<Map<String, dynamic>> rotasIniciais;

  const DraggableRouteList({super.key, required this.rotasIniciais});

  @override
  State<DraggableRouteList> createState() => _DraggableRouteListState();
}

class _DraggableRouteListState extends State<DraggableRouteList> {
  late List<Map<String, dynamic>> rotas;
  Map<String, String> _distanciaTextos = {};

  @override
  void initState() {
    super.initState();
    rotas = List.from(widget.rotasIniciais);

    // Alimenta o serviço com as entregas atuais
    DistanciaService.instance.atualizarEntregas(rotas);

    // Escuta atualizações de distância vindas do GPS (passivamente)
    DistanciaService.instance.distanciasNotifier.addListener(
      _onDistanciasAtualizadas,
    );

    // Gatilho A: Ordenação após o carregamento inicial
    ordenarPorDistancia();
  }

  void _onDistanciasAtualizadas() {
    if (mounted) {
      setState(() {
        _distanciaTextos = DistanciaService.instance.distanciasNotifier.value;
        // Injeta o valor do notifier de volta no objeto para que a ordenação funcione
        for (var rota in rotas) {
          final id = rota['id']?.toString();
          if (id != null && _distanciaTextos.containsKey(id)) {
            final texto = _distanciaTextos[id]!;
            final limpo = texto.replaceAll(RegExp(r'[^\d.]'), '');
            rota['distancia'] = double.tryParse(limpo) ?? rota['distancia'];
          }
        }
      });
    }
  }

  void ordenarPorDistancia() {
    rotas.sort((a, b) {
      final distA = a['distancia'] ?? a['km'] ?? 999999.0;
      final distB = b['distancia'] ?? b['km'] ?? 999999.0;
      final numA = (distA is num)
          ? distA.toDouble()
          : (double.tryParse(distA.toString()) ?? 999999.0);
      final numB = (distB is num)
          ? distB.toDouble()
          : (double.tryParse(distB.toString()) ?? 999999.0);
      return numA.compareTo(numB);
    });
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant DraggableRouteList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reconcilia o estado interno quando o Stream emite dados novos
    if (widget.rotasIniciais.length != oldWidget.rotasIniciais.length ||
        widget.rotasIniciais.toString() != oldWidget.rotasIniciais.toString()) {
      setState(() {
        rotas = List.from(widget.rotasIniciais);
      });
      // Atualiza o serviço com a nova lista de entregas
      DistanciaService.instance.atualizarEntregas(rotas);
      ordenarPorDistancia();
    }
  }

  @override
  void dispose() {
    DistanciaService.instance.distanciasNotifier.removeListener(
      _onDistanciasAtualizadas,
    );
    super.dispose();
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = rotas.removeAt(oldIndex);
      rotas.insert(newIndex, item);
    });
  }

  Future<void> _abrirNavegador(
    String endereco,
    double? lat,
    double? lng,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final navegador = prefs.getString('navegador_padrao') ?? 'maps';

    Uri uri;
    if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      if (navegador == 'waze') {
        uri = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
      } else {
        uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
        );
      }
    } else {
      if (endereco.isEmpty) return;
      final enderecoCodificado = Uri.encodeComponent(endereco);
      if (navegador == 'waze') {
        uri = Uri.parse(
          'https://waze.com/ul?q=$enderecoCodificado&navigate=yes',
        );
      } else {
        uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$enderecoCodificado',
        );
      }
    }

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o navegador.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _abrirModalBaixa(
    BuildContext context,
    Map<String, dynamic> rota,
  ) async {
    final bool? sucesso = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModalBaixaEntrega(
        rota: rota,
        tipo: rota['tipo'] ?? 'Entrega',
        clienteNome: rota['cliente']?.toString() ?? 'Não informado',
        endereco: rota['endereco'] ?? 'Não informado',
      ),
    );

    if (sucesso == true) {
      setState(() {
        rotas.removeWhere((item) => item['id'] == rota['id']);
      });
      DistanciaService.instance.atualizarEntregas(rotas);
      DistanciaService.instance.forcarRecalculoImediato();
      ordenarPorDistancia(); // Gatilho B: Ao finalizar entrega
    }
  }

  Future<void> _abrirModalFalha(
    BuildContext context,
    Map<String, dynamic> rota,
  ) async {
    final bool? sucesso = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModalFalhaEntrega(
        rota: rota,
        tipo: rota['tipo'] ?? 'Entrega',
        clienteNome: rota['cliente']?.toString() ?? 'Não informado',
        endereco: rota['endereco'] ?? 'Não informado',
      ),
    );

    if (sucesso == true) {
      setState(() {
        rotas.removeWhere((item) => item['id'] == rota['id']);
      });
      DistanciaService.instance.atualizarEntregas(rotas);
      DistanciaService.instance.forcarRecalculoImediato();
      ordenarPorDistancia(); // Gatilho B: Ao falhar entrega
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.route_rounded, color: AppColors.textGrey, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'ROTEIRIZAÇÃO',
                          style: TextStyle(
                            color: AppColors.textGrey.withValues(alpha: 0.9),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: const StadiumBorder(), // Formato de pílula
                ),
                onPressed: () {
                  final rotaAtiva = rotas.isNotEmpty ? rotas.first : null;
                  if (rotaAtiva != null) {
                    final double? latColeta = rotaAtiva['lat_coleta'] != null ? double.tryParse(rotaAtiva['lat_coleta'].toString()) : null;
                    final double? lngColeta = rotaAtiva['lng_coleta'] != null ? double.tryParse(rotaAtiva['lng_coleta'].toString()) : null;
                    final String enderecoColeta = rotaAtiva['endereco_coleta']?.toString() ?? '';
                    
                    if (latColeta != null && lngColeta != null) {
                      _abrirNavegador(enderecoColeta, latColeta, lngColeta);
                    }
                  }
                },
                child: const Text('COLETAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              // Gatilho C: Recalcula e ordena no Pull-to-Refresh
              DistanciaService.instance.forcarRecalculoImediato();
              await Future.delayed(const Duration(milliseconds: 500));
              ordenarPorDistancia();
            },
            child: ReorderableListView.builder(
        padding: const EdgeInsets.only(
          bottom: 80,
          top: 8,
        ), // Espaço extra no final
        itemCount: rotas.length,
        onReorder: _reorder,
        proxyDecorator: (child, index, animation) {
          return Material(
            color: Colors.transparent,
            elevation: 10,
            shadowColor: AppColors.backgroundBody,
            child: child,
          );
        },
        itemBuilder: (context, index) {
          final rota = rotas[index];
          final String tipo = rota['tipo'] ?? 'entrega';

          // Cores baseadas no tipo
          Color accentColor;
          if (tipo.toLowerCase() == 'coleta' ||
              tipo.toLowerCase() == 'recolha') {
            accentColor = AppColors.borderRecolha;
          } else if (tipo.toLowerCase() == 'outros') {
            accentColor = AppColors.borderOutros;
          } else {
            accentColor = AppColors.borderEntregas;
          }

          return ValueListenableBuilder<ThemeMode>(
            key: ValueKey(rota['id'].toString()),
            valueListenable: ThemeController.instance.themeModeNotifier,
            builder: (context, mode, child) {
              final isDark = mode == ThemeMode.dark;
              return Container(
                key: ValueKey(rota['id'].toString()),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2525) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? accentColor.withValues(alpha: 0.5) : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? accentColor.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CABEÇALHO DO CARD (Índice, Tipo e GPS)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: accentColor,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            (tipo.toLowerCase() == 'recolha' ||
                                    tipo.toLowerCase() == 'coleta')
                                ? 'COLETA'
                                : tipo.toUpperCase(),
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.borderRecolha.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Builder(
                          builder: (context) {
                            final id = rota['id']?.toString() ?? '';
                            final texto = _distanciaTextos[id];

                            // Se o serviço ainda não calculou, mostra "Sem GPS" ou "..."
                            if (texto == null || texto == 'Sem GPS') {
                              final bool temGps =
                                  rota['lat'] != null && rota['lng'] != null;
                              return Row(
                                children: [
                                  Icon(
                                    temGps
                                        ? Icons.location_on_rounded
                                        : Icons.location_off_rounded,
                                    color: AppColors.borderRecolha,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    temGps ? '...' : 'Sem GPS',
                                    style: const TextStyle(
                                      color: AppColors.borderRecolha,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: AppColors.borderRecolha,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  texto,
                                  style: const TextStyle(
                                    color: AppColors.borderRecolha,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // INFORMAÇÕES DO CLIENTE
                  Text(
                    'CLIENTE',
                    style: TextStyle(
                      color: isDark ? AppColors.textGrey.withValues(alpha: 0.8) : Colors.grey[600],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rota['cliente'] ?? '',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ENDEREÇO
                  Text(
                    'ENDEREÇO',
                    style: TextStyle(
                      color: isDark ? AppColors.textGrey.withValues(alpha: 0.8) : Colors.grey[600],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: accentColor, width: 4),
                      ),
                    ),
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      rota['endereco'] ?? '',
                      style: TextStyle(
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.9),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // AVISO DO GESTOR
                  if (rota['aviso'] != null &&
                      rota['aviso'].toString().isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2D2D3A) : const Color(0xFF4A4A4A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? AppColors.borderRecolha.withValues(alpha: 0.3) : Colors.grey.shade600,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: isDark ? AppColors.borderRecolha : Colors.amber[300],
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'AVISO DO GESTOR:',
                                style: TextStyle(
                                  color: isDark ? AppColors.borderRecolha : Colors.amber[300],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rota['aviso'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (rota['aviso'] != null &&
                      rota['aviso'].toString().isNotEmpty)
                    const SizedBox(height: 16),

                  // BOTÕES DE AÇÃO
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Botão Rota
                      Expanded(
                        flex: 4,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final double? latDestino = rota['lat'] != null ? double.tryParse(rota['lat'].toString()) : null;
                            final double? lngDestino = rota['lng'] != null ? double.tryParse(rota['lng'].toString()) : null;
                            final String enderecoDestino = rota['endereco']?.toString() ?? '';
                            _abrirNavegador(enderecoDestino, latDestino, lngDestino);
                          },
                          icon: const Icon(
                            Icons.map_outlined,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'ROTA',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.borderEntregas,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botão Falha
                      Expanded(
                        flex: 4,
                        child: ElevatedButton.icon(
                          onPressed: () => _abrirModalFalha(context, rota),
                          icon: const Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'FALHA',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botão OK
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          onPressed: () => _abrirModalBaixa(context, rota),
                          icon: const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'OK',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.successGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      // Ícone de arrastar
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
      ),
    ),
  ),
      ],
    );
  }
}
