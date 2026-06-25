import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_colors.dart';
import '../services/supabase_service.dart';
import 'selecao_entrega_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ListaOcorrenciasView
// Exibe as ocorrências registradas pelo motorista, com opção de criar novas.
// ─────────────────────────────────────────────────────────────────────────────
class ListaOcorrenciasView extends StatefulWidget {
  const ListaOcorrenciasView({super.key});

  @override
  State<ListaOcorrenciasView> createState() => _ListaOcorrenciasViewState();
}

class _ListaOcorrenciasViewState extends State<ListaOcorrenciasView> {
  late Future<List<Map<String, dynamic>>> _futureOcorrencias;

  @override
  void initState() {
    super.initState();
    _futureOcorrencias = _carregar();
  }

  Future<List<Map<String, dynamic>>> _carregar() async {
    final motoristaId = SupabaseService.currentMotoristaId ?? '';

    DateTime agora = DateTime.now();
    DateTime corte = DateTime(agora.year, agora.month, agora.day, 4, 0);

    if (agora.hour < 4) {
      corte = corte.subtract(const Duration(days: 1));
    }

    // Busca ocorrências via entrega do motorista (join implícito via entrega_id)
    final resultado = await Supabase.instance.client
        .from('ocorrencias')
        .select('*, entregas(cliente, endereco)')
        .gte('created_at', corte.toUtc().toIso8601String())
        .order('created_at', ascending: false);

    // Filtra apenas as do motorista (via campo da entrega)
    // Se a tabela ocorrencias tiver motorista_id direto, fica mais simples:
    return (resultado as List)
        .where((o) {
          // Compatibilidade: tenta filtrar por motorista_id na ocorrencia ou na entrega
          final mId = o['motorista_id']?.toString() ?? '';
          return mId.isEmpty || mId == motoristaId;
        })
        .cast<Map<String, dynamic>>()
        .toList();
  }

  Color _corStatus(String status) {
    switch (status.toLowerCase()) {
      case 'resolvida':
      case 'concluida':
        return Colors.greenAccent;
      case 'em_analise':
      case 'em analise':
        return Colors.blueAccent;
      case 'pendente':
      default:
        return Colors.orangeAccent;
    }
  }

  String _labelStatus(String status) {
    switch (status.toLowerCase()) {
      case 'resolvida':
      case 'concluida':
        return 'Resolvida';
      case 'em_analise':
      case 'em analise':
        return 'Em análise';
      case 'pendente':
      default:
        return 'Pendente';
    }
  }

  String _formatarData(String? dataStr) {
    if (dataStr == null) return '--';
    final dt = DateTime.tryParse(dataStr)?.toLocal();
    if (dt == null) return '--';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  String _nomeCliente(Map<String, dynamic> ocorrencia) {
    final entrega = ocorrencia['entregas'] as Map<String, dynamic>?;
    if (entrega == null) return 'Entrega não vinculada';
    final raw = (entrega['cliente'] ?? 'Cliente').toString();
    return raw.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
  }

  Future<void> _reenviarWhatsApp(Map<String, dynamic> ocorrencia) async {
    final messenger = ScaffoldMessenger.of(context);
    
    final prefs = await SharedPreferences.getInstance();
    final telefoneInput = prefs.getString('numero_gestor') ?? '';
    
    if (telefoneInput.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Número do gestor não encontrado. Registre uma nova ocorrência primeiro.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final String telefoneLimpo = telefoneInput.replaceAll(RegExp(r'\D'), '');
    final String numeroFinal = telefoneLimpo.startsWith('55') ? telefoneLimpo : '55$telefoneLimpo';
    
    final tipo = ocorrencia['tipo_ocorrencia']?.toString() ?? 'Sem tipo';
    final descricao = ocorrencia['descricao']?.toString() ?? '';
    final cliente = _nomeCliente(ocorrencia);
    final endereco = ocorrencia['entregas']?['endereco']?.toString() ?? '';
    final entregaId = ocorrencia['entrega_id']?.toString() ?? '';

    final String prefixo = cliente.isNotEmpty && cliente != 'Entrega não vinculada'
        ? '🚨 *Ocorrência registrada!*\n\n*Cliente:* $cliente\n*Endereço:* $endereco\n*ID Entrega:* $entregaId\n*Motivo:* $tipo'
        : '🚨 *Ocorrência registrada!*\n\n*Motivo:* $tipo';
        
    final String msg = '$prefixo\n*Detalhe:* $descricao';

    final Uri url = Uri.parse('https://wa.me/$numeroFinal?text=${Uri.encodeComponent(msg)}');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      
      // Atualizar ultima_mensagem_enviada
      await Supabase.instance.client
          .from('ocorrencias')
          .update({'ultima_mensagem_enviada': DateTime.now().toUtc().toIso8601String()})
          .eq('id', ocorrencia['id']);
          
      // Recarregar a lista silenciosamente
      _carregar().then((lista) {
        if (mounted) setState(() => _futureOcorrencias = Future.value(lista));
      });
      
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erro ao reenviar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBody,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundBody,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        title: const Text(
          'Minhas Ocorrências',
          style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textGrey),
            onPressed: () => setState(() => _futureOcorrencias = _carregar()),
          ),
        ],
      ),
      // ── FAB: Registrar nova ocorrência ────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navega para a seleção de entrega
          final recarregar = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SelecaoEntregaView()),
          );
          // Se retornou true (salvou), recarrega a lista
          if (recarregar == true && mounted) {
            setState(() {
              _futureOcorrencias = _carregar();
            });
          }
        },
        backgroundColor: Colors.orangeAccent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova Ocorrência', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureOcorrencias,
        builder: (context, snapshot) {
          // ── Loading ───────────────────────────────────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            );
          }

          // ── Erro ──────────────────────────────────────────────────────────
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, color: AppColors.textGrey, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Erro ao carregar: ${snapshot.error}',
                    style: const TextStyle(color: AppColors.textGrey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final lista = snapshot.data ?? [];

          // ── Lista vazia ───────────────────────────────────────────────────
          if (lista.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.textGrey.withValues(alpha: 0.4),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhuma ocorrência registrada',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Toque em "+ Nova Ocorrência" para registrar.',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          // ── Lista ─────────────────────────────────────────────────────────
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: lista.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final oc = lista[index];
              final status = (oc['status'] ?? 'pendente').toString();
              final tipo = (oc['tipo_ocorrencia'] ?? 'Sem tipo').toString();
              final descricao = (oc['descricao'] ?? '').toString();
              final data = _formatarData(oc['created_at']?.toString());
              final corS = _corStatus(status);
              final cliente = _nomeCliente(oc);

              final DateTime? ultimaEnvio = oc['ultima_mensagem_enviada'] != null 
                  ? DateTime.tryParse(oc['ultima_mensagem_enviada'].toString())?.toLocal() 
                  : null;
              final bool podeReenviar = ultimaEnvio == null || 
                  DateTime.now().difference(ultimaEnvio).inMinutes >= 5;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF112240),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ícone de status
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: corS.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.report_problem_rounded, color: corS, size: 18),
                    ),
                    const SizedBox(width: 12),
                    // Conteúdo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tipo,
                                  style: const TextStyle(
                                    color: AppColors.textWhite,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // Badge de status
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: corS.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: corS.withValues(alpha: 0.35)),
                                ),
                                child: Text(
                                  _labelStatus(status),
                                  style: TextStyle(
                                    color: corS,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (cliente.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              cliente,
                              style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
                            ),
                          ],
                          if (descricao.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              descricao,
                              style: TextStyle(
                                color: AppColors.textWhite.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 11, color: AppColors.textGrey),
                              const SizedBox(width: 4),
                              Text(
                                data,
                                style: const TextStyle(color: AppColors.textGrey, fontSize: 11),
                              ),
                            ],
                          ),
                          if (status.toLowerCase() == 'pendente') ...[
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: podeReenviar 
                                  ? () => _reenviarWhatsApp(oc) 
                                  : () {
                                      final minutosFaltando = 5 - DateTime.now().difference(ultimaEnvio).inMinutes;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Aguarde $minutosFaltando minuto(s) para reenviar a ocorrência.'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: !podeReenviar ? Colors.grey.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: !podeReenviar ? Colors.grey.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.send_rounded, size: 14, color: !podeReenviar ? Colors.grey : Colors.orangeAccent),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Reenviar',
                                      style: TextStyle(color: !podeReenviar ? Colors.grey : Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
