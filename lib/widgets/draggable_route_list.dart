import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';

class DraggableRouteList extends StatefulWidget {
  final List<Map<String, dynamic>> rotasIniciais;

  const DraggableRouteList({super.key, required this.rotasIniciais});

  @override
  State<DraggableRouteList> createState() => _DraggableRouteListState();
}

class _DraggableRouteListState extends State<DraggableRouteList> {
  late List<Map<String, dynamic>> rotas;

  @override
  void initState() {
    super.initState();
    rotas = List.from(widget.rotasIniciais);
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
    }
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

  Future<void> _abrirNavegador(String endereco) async {
    if (endereco.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final navegador = prefs.getString('navegador_padrao') ?? 'maps';
    final enderecoCodificado = Uri.encodeComponent(endereco);

    Uri uri;
    if (navegador == 'waze') {
      uri = Uri.parse('https://waze.com/ul?q=$enderecoCodificado&navigate=yes');
    } else {
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$enderecoCodificado');
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

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 80, top: 8), // Espaço extra no final
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
        if (tipo.toLowerCase() == 'coleta' || tipo.toLowerCase() == 'recolha') {
          accentColor = AppColors.borderRecolha;
        } else if (tipo.toLowerCase() == 'outros') {
          accentColor = AppColors.borderOutros;
        } else {
          accentColor = AppColors.borderEntregas;
        }

        return Container(
          key: ValueKey(rota['id']),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.05),
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
                          child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          tipo.toUpperCase(),
                          style: TextStyle(color: accentColor, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.borderRecolha.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.location_off_rounded, color: AppColors.borderRecolha, size: 14),
                          SizedBox(width: 4),
                          Text('Sem GPS', style: TextStyle(color: AppColors.borderRecolha, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // INFORMAÇÕES DO CLIENTE
                Text('CLIENTE', style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                const SizedBox(height: 2),
                Text(
                  rota['cliente'] ?? '',
                  style: const TextStyle(color: AppColors.textWhite, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                // ENDEREÇO
                Text('ENDEREÇO', style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                const SizedBox(height: 2),
                Container(
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: accentColor, width: 4)),
                  ),
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    rota['endereco'] ?? '',
                    style: TextStyle(color: AppColors.textWhite.withValues(alpha: 0.9), fontSize: 14, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),

                // AVISO DO GESTOR
                if (rota['aviso'] != null && rota['aviso'].toString().isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.borderRecolha.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderRecolha.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppColors.borderRecolha, size: 16),
                            SizedBox(width: 6),
                            Text('AVISO DO GESTOR:', style: TextStyle(color: AppColors.borderRecolha, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(rota['aviso'], style: const TextStyle(color: AppColors.textWhite, fontSize: 14)),
                      ],
                    ),
                  ),
                if (rota['aviso'] != null && rota['aviso'].toString().isNotEmpty)
                  const SizedBox(height: 16),

                // BOTÕES DE AÇÃO
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Botão Rota
                    Expanded(
                      flex: 4,
                      child: ElevatedButton.icon(
                        onPressed: () => _abrirNavegador(rota['endereco'] ?? ''),
                        icon: const Icon(Icons.map_outlined, size: 18, color: Colors.white),
                        label: const Text('ROTA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.borderEntregas,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Botão Falha
                    Expanded(
                      flex: 4,
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.error_outline_rounded, size: 18, color: Colors.white),
                        label: const Text('FALHA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Botão OK
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                        label: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    // Ícone de arrastar
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.drag_indicator_rounded, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
