import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../services/supabase_service.dart';

enum _Periodo { hoje, seteDias, mesAtual }

class HistoricoDiaView extends StatefulWidget {
  const HistoricoDiaView({super.key});

  @override
  State<HistoricoDiaView> createState() => _HistoricoDiaViewState();
}

class _HistoricoDiaViewState extends State<HistoricoDiaView> {
  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';
  _Periodo _periodoSelecionado = _Periodo.hoje;
  late Future<List<Map<String, dynamic>>> _futureEntregas;

  @override
  void initState() {
    super.initState();
    _futureEntregas = _carregarEntregas(_periodoSelecionado);
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _carregarEntregas(_Periodo periodo) async {
    final motoristaId = SupabaseService.currentMotoristaId ?? '';
    final agora = DateTime.now().toLocal();

    // ── Calcula o limite inferior conforme o período ──────────────────────────
    DateTime limiteInicio;
    switch (periodo) {
      case _Periodo.hoje:
        // Diária: 04:00 de hoje (ou 04:00 de ontem se antes das 04:00)
        limiteInicio = DateTime(agora.year, agora.month, agora.day, 4, 0);
        if (agora.isBefore(limiteInicio)) {
          limiteInicio = limiteInicio.subtract(const Duration(days: 1));
        }
      case _Periodo.seteDias:
        limiteInicio = DateTime(agora.year, agora.month, agora.day - 6, 0, 0);
      case _Periodo.mesAtual:
        limiteInicio = DateTime(agora.year, agora.month, 1, 0, 0);
    }

    final registros = await Supabase.instance.client
        .from('entregas')
        .select()
        .eq('motorista_id', motoristaId)
        .gte('created_at', limiteInicio.toUtc().toIso8601String())
        .order('created_at', ascending: false);

    return (registros as List).cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> _filtrar(List<Map<String, dynamic>> lista) {
    if (_termoBusca.isEmpty) return lista;
    final termo = _termoBusca.toLowerCase();
    return lista.where((e) {
      final nomeRaw = (e['cliente_nome'] ?? e['nome_cliente'] ?? e['cliente'] ?? '').toString();
      final cliente = nomeRaw.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim().toLowerCase();
      return cliente.contains(termo);
    }).toList();
  }

  // ─── Helpers de UI ─────────────────────────────────────────────────────────

  Color _corStatus(String status) {
    switch (status) {
      case 'concluido':
      case 'entregue':
      case 'arquivado':
        return Colors.greenAccent;
      case 'falha':
      case 'nao_entregue':
        return Colors.redAccent;
      default:
        return Colors.orangeAccent;
    }
  }

  IconData _iconeStatus(String status) {
    switch (status) {
      case 'concluido':
      case 'entregue':
      case 'arquivado':
        return Icons.check_circle_rounded;
      case 'falha':
      case 'nao_entregue':
        return Icons.cancel_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  Color _corTipo(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'coleta':
      case 'recolha':
        return AppColors.borderRecolha;
      case 'outros':
        return AppColors.borderOutros;
      default:
        return AppColors.borderEntregas;
    }
  }

  String _labelTipo(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'coleta':
      case 'recolha':
        return 'COLETA';
      case 'outros':
        return 'ATA';
      default:
        return 'ENTREGA';
    }
  }

  String _formatarHora(dynamic dataStr) {
    if (dataStr == null) return '--:--';
    final dt = DateTime.tryParse(dataStr.toString())?.toLocal();
    if (dt == null) return '--:--';
    return DateFormat('HH:mm').format(dt);
  }

  void _abrirDetalhes(BuildContext context, Map<String, dynamic> entrega) {
    final status = (entrega['status'] ?? '').toString().toLowerCase();
    final tipo = (entrega['tipo'] ?? '').toString();
    final nomeRaw = (entrega['cliente_nome'] ?? entrega['nome_cliente'] ?? entrega['cliente'] ?? 'Não informado').toString();
    final cliente = nomeRaw.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
    final endereco = entrega['endereco'] ?? 'Não informado';
    final observacoes = entrega['observacoes'] ?? 'Nenhuma';
    final recebedor = entrega['recebedor_tipo'] ?? 'Não informado';
    final motivo = entrega['motivo_nao_entrega'];
    final hora = _formatarHora(entrega['data_conclusao'] ?? entrega['created_at']);
    final corS = _corStatus(status);
    final corT = _corTipo(tipo);

    // Captura o messenger ANTES de abrir o modal — evita contexto perdido dentro do builder
    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        decoration: const BoxDecoration(
          color: Color(0xFF112240),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Cabeçalho
            Row(
              children: [
                Icon(_iconeStatus(status), color: corS, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cliente,
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: corT.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: corT.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _labelTipo(tipo),
                    style: TextStyle(
                      color: corT,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DetalheRow(icone: Icons.location_on_outlined, label: 'Endereço', valor: endereco),
            const SizedBox(height: 12),
            _DetalheRow(icone: Icons.access_time_rounded, label: 'Horário', valor: hora),
            const SizedBox(height: 12),
            if (motivo != null && motivo.toString().isNotEmpty)
              Column(
                children: [
                  _DetalheRow(icone: Icons.warning_amber_rounded, label: 'Motivo', valor: motivo.toString()),
                  const SizedBox(height: 12),
                ],
              ),
            _DetalheRow(icone: Icons.person_outline_rounded, label: 'Recebedor', valor: recebedor),
            const SizedBox(height: 12),
            _DetalheRow(icone: Icons.notes_rounded, label: 'Observações', valor: observacoes),
            const SizedBox(height: 20),
            // ── Rodapé: Botão Copiar ──────────────────────────────────────────
            Divider(color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final motivoTexto = (motivo != null && motivo.toString().isNotEmpty)
                        ? '\nMotivo: ${motivo.toString()}'
                        : '';
                    final textoParaCopiar =
                        'Resumo da Entrega:\n'
                        'Cliente: $cliente\n'
                        'Endereço: $endereco\n'
                        'Horário: $hora$motivoTexto\n'
                        'Recebedor: $recebedor\n'
                        'Observação: $observacoes';

                    await Clipboard.setData(ClipboardData(text: textoParaCopiar));

                    // Fecha o modal PRIMEIRO para que o SnackBar fique visível
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pop();

                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Resumo copiado com sucesso!'),
                        backgroundColor: Colors.green.shade700,
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textGrey),
                  label: Text(
                    'Copiar resumo',
                    style: TextStyle(
                      color: AppColors.textGrey.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBody,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundBody,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        title: const Text(
          'Histórico do Dia',
          style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textGrey),
            onPressed: () => setState(() {
              _futureEntregas = _carregarEntregas(_periodoSelecionado);
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Seletor de Período ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _PeriodoChip(
                  label: 'Hoje',
                  ativo: _periodoSelecionado == _Periodo.hoje,
                  onTap: () => setState(() {
                    _periodoSelecionado = _Periodo.hoje;
                    _futureEntregas = _carregarEntregas(_periodoSelecionado);
                  }),
                ),
                const SizedBox(width: 8),
                _PeriodoChip(
                  label: '7 dias',
                  ativo: _periodoSelecionado == _Periodo.seteDias,
                  onTap: () => setState(() {
                    _periodoSelecionado = _Periodo.seteDias;
                    _futureEntregas = _carregarEntregas(_periodoSelecionado);
                  }),
                ),
                const SizedBox(width: 8),
                _PeriodoChip(
                  label: 'Este mês',
                  ativo: _periodoSelecionado == _Periodo.mesAtual,
                  onTap: () => setState(() {
                    _periodoSelecionado = _Periodo.mesAtual;
                    _futureEntregas = _carregarEntregas(_periodoSelecionado);
                  }),
                ),
              ],
            ),
          ),

          // ── Campo de Busca ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _buscaController,
              style: const TextStyle(color: AppColors.textWhite),
              onChanged: (val) => setState(() => _termoBusca = val),
              decoration: InputDecoration(
                hintText: 'Buscar por cliente...',
                hintStyle: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.6)),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textGrey.withValues(alpha: 0.6)),
                suffixIcon: _termoBusca.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textGrey),
                        onPressed: () {
                          _buscaController.clear();
                          setState(() => _termoBusca = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── Lista ──────────────────────────────────────────────────────────
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureEntregas,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.successGreen),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erro ao carregar dados.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textGrey),
                    ),
                  );
                }

                final lista = _filtrar(snapshot.data ?? []);

                if (lista.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_rounded, size: 56, color: AppColors.textGrey.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          _termoBusca.isEmpty
                              ? 'Nenhuma entrega registrada hoje.'
                              : 'Nenhum resultado para "$_termoBusca".',
                          style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.6), fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: lista.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entrega = lista[index];
                    final status = (entrega['status'] ?? '').toString().toLowerCase();
                    final tipo = (entrega['tipo'] ?? '').toString();
                    final nomeRaw = (entrega['cliente_nome'] ?? entrega['nome_cliente'] ?? entrega['cliente'] ?? 'Cliente').toString();
                    final cliente = nomeRaw.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
                    final hora = _formatarHora(entrega['data_conclusao'] ?? entrega['created_at']);
                    final corS = _corStatus(status);
                    final corT = _corTipo(tipo);

                    return GestureDetector(
                      onTap: () => _abrirDetalhes(context, entrega),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: corS.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Ícone de status
                            Icon(_iconeStatus(status), color: corS, size: 28),
                            const SizedBox(width: 14),
                            // Conteúdo central
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cliente,
                                    style: const TextStyle(
                                      color: AppColors.textWhite,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: corT.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: corT.withValues(alpha: 0.35)),
                                        ),
                                        child: Text(
                                          _labelTipo(tipo),
                                          style: TextStyle(
                                            color: corT,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Hora
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  hora,
                                  style: const TextStyle(
                                    color: AppColors.textGrey,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.textGrey, size: 18),
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Linha de detalhe no BottomSheet
// ─────────────────────────────────────────────────────────────────────────────
class _DetalheRow extends StatelessWidget {
  final IconData icone;
  final String label;
  final String valor;

  const _DetalheRow({
    required this.icone,
    required this.label,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, color: AppColors.textGrey, size: 18),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: AppColors.textGrey.withValues(alpha: 0.6),
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: MediaQuery.of(context).size.width - 100,
              child: Text(
                valor,
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Chip de seleção de período
// ─────────────────────────────────────────────────────────────────────────────
class _PeriodoChip extends StatelessWidget {
  final String label;
  final bool ativo;
  final VoidCallback onTap;

  const _PeriodoChip({
    required this.label,
    required this.ativo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: ativo
              ? AppColors.successGreen.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ativo
                ? AppColors.successGreen.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: ativo ? AppColors.successGreen : AppColors.textGrey,
            fontSize: 12,
            fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
