import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/supabase_service.dart';
import 'widgets/notificacao_tile.dart';

class NotificacoesListView extends StatefulWidget {
  const NotificacoesListView({super.key});

  @override
  State<NotificacoesListView> createState() => _NotificacoesListViewState();
}

class _NotificacoesListViewState extends State<NotificacoesListView> {
  final _motoristaId = SupabaseService.currentMotoristaId;
  String _filtroAtual = 'todas'; // 'todas' ou 'nao_lidas'
  bool _primeiraCargaFeita = false;
  final Set<String> _idsLidosLocalmente = {};

  Stream<List<Map<String, dynamic>>> _notificacoesStream() {
    if (_motoristaId == null) return const Stream.empty();

    return SupabaseService.client
        .from('avisos_gestor')
        .stream(primaryKey: ['id'])
        .map((lista) {
          // Filtro no client evita sobrecarga e erro 1002 no socket
          final filtrada = lista.where((aviso) {
            final motId = aviso['motorista_id'];
            return motId == _motoristaId || motId == null;
          }).toList();
          
          // Ordenação manual no client-side
          filtrada.sort((a, b) {
            final dataA = (a['created_at'] ?? '').toString();
            final dataB = (b['created_at'] ?? '').toString();
            return dataB.compareTo(dataA);
          });
          
          return filtrada;
        });
  }

  Future<void> _marcarTodasComoLidas() async {
    if (_motoristaId == null) return;
    try {
      await SupabaseService.client
          .from('avisos_gestor')
          .update({
            'lida': true,
            'data_leitura': DateTime.now().toIso8601String(),
          })
          .eq('motorista_id', _motoristaId)
          .eq('lida', false);
    } catch (e) {
      if (kDebugMode) { debugPrint('Erro ao marcar todas como lidas: $e'); }
    }
  }

  Future<void> _marcarComoLida(dynamic id, bool lida) async {
    if (lida || id == null) return;
    
    // Optimistic UI (Efeito Imediato)
    setState(() {
      _idsLidosLocalmente.add(id.toString());
    });
    
    try {
      await SupabaseService.client
          .from('avisos_gestor')
          .update({
            'lida': true,
            'data_leitura': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      if (kDebugMode) { debugPrint('Erro ao marcar como lida: $e'); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBody,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundBody,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Central de Notificações',
          style: TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        actions: [
          IconButton(
            tooltip: 'Marcar todas como lidas',
            icon: const Icon(Icons.done_all, color: AppColors.successGreen),
            onPressed: _marcarTodasComoLidas,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(child: _buildLista()),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFiltroPill('Todas', 'todas'),
          const SizedBox(width: 12),
          _buildFiltroPill('Não Lidas', 'nao_lidas'),
        ],
      ),
    );
  }

  Widget _buildFiltroPill(String titulo, String valor) {
    final isSelected = _filtroAtual == valor;
    return GestureDetector(
      onTap: () => setState(() => _filtroAtual = valor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : AppColors.textGrey.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          titulo,
          style: TextStyle(
            color: isSelected ? AppColors.textWhite : AppColors.textGrey,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLista() {
    if (_motoristaId == null) {
      return const Center(
        child: Text('Motorista não identificado.', style: TextStyle(color: AppColors.textWhite)),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _notificacoesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erro ao carregar notificações.',
              style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.8)),
            ),
          );
        }

        var notificacoes = snapshot.data ?? [];

        // Abertura Inteligente de Aba
        if (!_primeiraCargaFeita && notificacoes.isNotEmpty) {
          final temNaoLida = notificacoes.any((n) => n['lida'] == false);
          if (temNaoLida) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _filtroAtual = 'nao_lidas';
                  _primeiraCargaFeita = true;
                });
              }
            });
          } else {
            _primeiraCargaFeita = true;
          }
        } else if (!_primeiraCargaFeita) {
          _primeiraCargaFeita = true;
        }

        // Aplicação do filtro local com Optimistic UI
        if (_filtroAtual == 'nao_lidas') {
          notificacoes = notificacoes.where((n) {
            final isLida = n['lida'] == true || _idsLidosLocalmente.contains(n['id'].toString());
            return !isLida;
          }).toList();
        } else {
          // Atualiza estado local da lista 'todas' apenas visualmente
          notificacoes = notificacoes.map((n) {
            if (_idsLidosLocalmente.contains(n['id'].toString())) {
              return {...n, 'lida': true}; // copia do mapa
            }
            return n;
          }).toList();
        }

        if (notificacoes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.textGrey.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text(
                  _filtroAtual == 'todas' ? 'Nenhum aviso do gestor no momento.' : 'Oba! Você não tem avisos não lidos.',
                  style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.7), fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notificacoes.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final notificacao = notificacoes[index];
            return NotificacaoTile(
              notificacao: notificacao,
              onTap: () {
                final lida = notificacao['lida'] == true || _idsLidosLocalmente.contains(notificacao['id'].toString());
                _marcarComoLida(notificacao['id'], lida);
              },
            );
          },
        );
      },
    );
  }
}
