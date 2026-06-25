import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../services/supabase_service.dart';
import '../widgets/modal_ocorrencia.dart';

class SelecaoEntregaView extends StatefulWidget {
  const SelecaoEntregaView({super.key});

  @override
  State<SelecaoEntregaView> createState() => _SelecaoEntregaViewState();
}

class _SelecaoEntregaViewState extends State<SelecaoEntregaView> {
  late Future<List<Map<String, dynamic>>> _futureEntregas;

  @override
  void initState() {
    super.initState();
    _futureEntregas = _carregarEntregasAbertas();
  }

  Future<List<Map<String, dynamic>>> _carregarEntregasAbertas() async {
    final motoristaId = SupabaseService.currentMotoristaId ?? '';
    final agora = DateTime.now().toLocal();

    // Diária: 04:00 de hoje (ou 04:00 de ontem se antes das 04:00)
    var limiteInicio = DateTime(agora.year, agora.month, agora.day, 4, 0);
    if (agora.isBefore(limiteInicio)) {
      limiteInicio = limiteInicio.subtract(const Duration(days: 1));
    }

    final registros = await Supabase.instance.client
        .from('entregas')
        .select()
        .eq('motorista_id', motoristaId)
        .gte('created_at', limiteInicio.toUtc().toIso8601String())
        .or('status.eq.em_rota,status.is.null') // Filtra ativas ou sem status definido
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(registros);
  }

  String _limparNome(dynamic rawName) {
    final str = (rawName ?? 'Cliente não informado').toString();
    return str.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
  }

  Map<String, dynamic> _getDetalhesServico(String? tipoStr) {
    final tipo = (tipoStr ?? '').toLowerCase();
    if (tipo.contains('recolha') || tipo.contains('coleta')) {
      return {
        'cor': Colors.orange,
        'icone': Icons.back_hand,
        'label': 'Recolha',
      };
    } else if (tipo.contains('outros') || tipo.contains('ata')) {
      return {
        'cor': Colors.purple,
        'icone': Icons.miscellaneous_services,
        'label': 'Outros',
      };
    } else {
      return {
        'cor': Colors.blue,
        'icone': Icons.local_shipping,
        'label': 'Entrega',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBody,
      appBar: AppBar(
        title: const Text('Selecione a Entrega',
            style: TextStyle(color: AppColors.textWhite)),
        backgroundColor: const Color(0xFF112240),
        iconTheme: const IconThemeData(color: AppColors.textWhite),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureEntregas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erro ao carregar entregas.\n${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            );
          }

          final entregas = snapshot.data ?? [];

          if (entregas.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 64, color: AppColors.textGrey),
                    SizedBox(height: 16),
                    Text(
                      'Nenhuma entrega pendente hoje.',
                      style: TextStyle(color: AppColors.textWhite, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entregas.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final e = entregas[index];
              final String nomeCliente = _limparNome(e['cliente']);
              final String endereco = (e['endereco'] ?? '').toString();

              final detalhes = _getDetalhesServico(e['tipo']?.toString());
              final Color cor = detalhes['cor'];
              final IconData icone = detalhes['icone'];
              final String label = detalhes['label'];

              return ListTile(
                tileColor: Colors.white.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(icone, color: cor, size: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(color: cor, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                title: Text(
                  nomeCliente,
                  style: const TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  endereco,
                  style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textGrey),
                onTap: () async {
                  final salvo = await ModalOcorrencia.mostrar(
                    context,
                    entregaId: e['id'].toString(),
                    nomeCliente: nomeCliente,
                    endereco: endereco,
                  );
                  if (salvo == true && context.mounted) {
                    Navigator.pop(context, true);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
