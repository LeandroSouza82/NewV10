import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chamada_model.dart';
import '../onboarding/onboarding_overlay_view.dart';
import 'widgets/chamada_card.dart';

class ChamadasView extends StatefulWidget {
  const ChamadasView({super.key});

  @override
  State<ChamadasView> createState() => _ChamadasViewState();
}

class _ChamadasViewState extends State<ChamadasView> {
  String _filtroAtual = 'Todas'; // Todas, Simples, Roteiros

  @override
  void initState() {
    super.initState();
    _verificarPermissaoOverlay();
  }

  Future<void> _verificarPermissaoOverlay() async {
    try {
      const mainChannel = MethodChannel('com.v10.delivery/main_overlay');
      final bool temPermissao = await mainChannel.invokeMethod('checkOverlayPermission');
      if (!temPermissao && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const OnboardingOverlayView(),
        );
      }
    } catch (e) {
      debugPrint('Erro ao verificar permissão: $e');
    }
  }

  // --- DADOS MOCK PARA DESENVOLVIMENTO ---
  final List<ChamadaModel> _mockChamadas = [
    // 1 rota simples ENTREGA recebida agora
    ChamadaModel(
      id: '1',
      tipo: TipoChamada.simples,
      status: StatusChamada.recebida,
      horario: DateTime.now(),
      tipoPedido: 'ENTREGA',
      cliente: 'Cond. Guimarães',
      endereco: 'Rua Dom Pedro II, 176',
      bairro: 'Centro',
      cidade: 'São José - SC',
      distancia: 8.2,
    ),
    // 1 rota simples COLETA visualizada
    ChamadaModel(
      id: '2',
      tipo: TipoChamada.simples,
      status: StatusChamada.visualizada,
      horario: DateTime.now().subtract(const Duration(minutes: 15)),
      tipoPedido: 'COLETA',
      cliente: 'Empresa Alpha',
      endereco: 'Av. das Nações Unidas, 1200',
      bairro: 'Campinas',
      cidade: 'São José - SC',
      distancia: 4.5,
    ),
    // 1 roteiro múltiplo com 12 pedidos recebido
    ChamadaModel(
      id: '3',
      tipo: TipoChamada.multipla,
      status: StatusChamada.recebida,
      horario: DateTime.now().subtract(const Duration(minutes: 3)),
      totalPedidos: 12,
      kmTotal: 34.7,
      totalEntregas: 7,
      totalColetas: 3,
      totalOutros: 2,
      inicioCliente: 'Solar de Gaia',
      inicioEndereco: 'Palhoça',
      fimCliente: 'Green Club',
      fimEndereco: 'Florianópolis',
    ),
    // 1 rota simples OUTROS expirada
    ChamadaModel(
      id: '4',
      tipo: TipoChamada.simples,
      status: StatusChamada.expirada,
      horario: DateTime.now().subtract(const Duration(minutes: 45)),
      tipoPedido: 'OUTROS',
      cliente: 'Cartório Central',
      endereco: 'Rua 7 de Setembro, 45',
      bairro: 'Centro',
      cidade: 'Florianópolis - SC',
      distancia: 12.1,
    ),
  ];

  List<ChamadaModel> get _chamadasFiltradas {
    if (_filtroAtual == 'Simples') {
      return _mockChamadas.where((c) => c.tipo == TipoChamada.simples).toList();
    } else if (_filtroAtual == 'Roteiros') {
      return _mockChamadas.where((c) => c.tipo == TipoChamada.multipla).toList();
    }
    return _mockChamadas;
  }

  void _atualizarFiltro(String filtro) {
    setState(() {
      _filtroAtual = filtro;
    });
  }

  Widget _buildFiltroChip(String titulo) {
    final bool isSelected = _filtroAtual == titulo;
    return GestureDetector(
      onTap: () => _atualizarFiltro(titulo),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF48BB78).withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(0xFF48BB78) : Colors.white24,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          titulo,
          style: TextStyle(
            color: isSelected ? const Color(0xFF48BB78) : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.route_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma chamada recebida ainda',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'As rotas enviadas pelo gestor aparecerão aqui',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chamadas = _chamadasFiltradas;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A), // Tema dark navy
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Chamadas e Rotas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              // Lógica de refresh futuramente
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFiltroChip('Todas'),
                _buildFiltroChip('Simples'),
                _buildFiltroChip('Roteiros'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Lista ou Empty State
          Expanded(
            child: chamadas.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: chamadas.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return ChamadaCard(chamada: chamadas[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
