import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../services/supabase_service.dart';
import 'comprovante_detalhes_view.dart';

class ComprovantesListView extends StatefulWidget {
  const ComprovantesListView({super.key});

  @override
  State<ComprovantesListView> createState() => _ComprovantesListViewState();
}

class _ComprovantesListViewState extends State<ComprovantesListView> {
  List<Map<String, dynamic>> _comprovantes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _buscarComprovantes();
  }

  Future<void> _buscarComprovantes() async {
    try {
      final motoristaId = SupabaseService.currentMotoristaId;
      if (motoristaId == null) {
        setState(() {
          _errorMessage = 'Motorista não identificado.';
          _isLoading = false;
        });
        return;
      }

      final setediasAtras = DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();

      final response = await SupabaseService.client
          .from('entregas')
          .select()
          .eq('motorista_id', motoristaId)
          .inFilter('status', ['concluido', 'falha'])
          .gte('created_at', setediasAtras)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _comprovantes = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao carregar comprovantes.';
          _isLoading = false;
        });
      }
    }
  }

  String _formatarDataHora(String? dataIso) {
    if (dataIso == null) return '--/--/---- • --:--';
    try {
      final data = DateTime.parse(dataIso).toLocal();
      return DateFormat('dd/MM/yyyy • HH:mm').format(data);
    } catch (e) {
      return dataIso;
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
          'Meus Comprovantes',
          style: TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textWhite),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.successGreen));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.textWhite, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _buscarComprovantes();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_comprovantes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, color: AppColors.textGrey.withValues(alpha: 0.5), size: 64),
            const SizedBox(height: 16),
            Text(
              'Nenhum comprovante nos últimos 7 dias.',
              style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _comprovantes.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entrega = _comprovantes[index];
        final isConcluido = entrega['status'] == 'concluido';
        final endereco = entrega['endereco'] ?? 'Endereço não informado';
        final dataStr = entrega['data_conclusao'] ?? entrega['created_at'];

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ComprovanteDetalhesView(entrega: entrega),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isConcluido
                    ? AppColors.successGreen.withValues(alpha: 0.3)
                    : Colors.redAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isConcluido
                        ? AppColors.successGreen.withValues(alpha: 0.1)
                        : Colors.redAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isConcluido ? Icons.check_circle_outline : Icons.cancel_outlined,
                    color: isConcluido ? AppColors.successGreen : Colors.redAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConcluido ? 'Entrega Finalizada' : 'Falha na Entrega',
                        style: TextStyle(
                          color: isConcluido ? AppColors.successGreen : Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        endereco,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: AppColors.textGrey, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatarDataHora(dataStr),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textGrey),
              ],
            ),
          ),
        );
      },
    );
  }
}
