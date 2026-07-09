import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../services/supabase_service.dart';

class MeuDesempenhoView extends StatelessWidget {
  const MeuDesempenhoView({super.key});

  Future<Map<String, dynamic>> _carregarDados() async {
    final motoristaId = SupabaseService.currentMotoristaId ?? '';

    final registros = await Supabase.instance.client
        .from('entregas')
        .select()
        .eq('motorista_id', motoristaId);

    // ── Filtro de diária: início às 04:00 de hoje (ou 04:00 de ontem se < 04:00) ──
    final agora = DateTime.now().toLocal();
    DateTime limiteReset = DateTime(agora.year, agora.month, agora.day, 4, 0);
    if (agora.isBefore(limiteReset)) {
      limiteReset = limiteReset.subtract(const Duration(days: 1));
    }

    final registrosDiaria = (registros as List).where((e) {
      final dataStr = e['created_at'] ?? e['criado_em'];
      if (dataStr == null) return true;
      final dataCriacao = DateTime.tryParse(dataStr.toString())?.toLocal();
      if (dataCriacao == null) return true;
      return !dataCriacao.isBefore(limiteReset);
    }).toList();

    int totalSucesso = 0;
    int totalFalhas = 0;
    int totalEntregas = 0;
    int totalColetas = 0;
    int totalOutros = 0;

    for (final e in registrosDiaria) {
      final status = (e['status'] ?? '').toString().toLowerCase().trim();
      final tipo = (e['tipo'] ?? '').toString().toLowerCase().trim();

      // LOG ESPIÃO: confirma o valor exato que chega do banco
      

      // Contagem de resultado
      if (status == 'concluido' || status == 'entregue' || status == 'arquivado') {
        totalSucesso++;
      } else if (status == 'falha' || status == 'nao_entregue') {
        totalFalhas++;
      }

      // Contagem por tipo (igual ao padrão dos modais)
      if (tipo == 'coleta' || tipo == 'recolha') {
        totalColetas++;
      } else if (tipo == 'outros') {
        totalOutros++;
      } else if (tipo == 'entrega') {
        totalEntregas++;
      } else {
        // Fallback: tipos não mapeados entram em Entregas para não sumir
        totalEntregas++;
      }
    }

    final totalFinalizadas = totalSucesso + totalFalhas;
    final taxaSucesso = totalFinalizadas > 0
        ? (totalSucesso / totalFinalizadas) * 100.0
        : 0.0;

    final totalVolume = totalEntregas + totalColetas + totalOutros;

    return {
      'taxaSucesso': taxaSucesso,
      'totalSucesso': totalSucesso,
      'totalFalhas': totalFalhas,
      'totalEntregas': totalEntregas,
      'totalColetas': totalColetas,
      'totalOutros': totalOutros,
      'totalVolume': totalVolume,
      'totalFinalizadas': totalFinalizadas,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBody,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundBody,
        iconTheme: const IconThemeData(color: AppColors.textWhite),
        title: const Text(
          'Meu Desempenho',
          style: TextStyle(
            color: AppColors.textWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _carregarDados(),
        builder: (context, snapshot) {
          // ── Loading ──────────────────────────────────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.successGreen),
            );
          }

          // ── Erro ─────────────────────────────────────────────────────────
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                'Erro ao carregar dados.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textGrey),
              ),
            );
          }

          final dados = snapshot.data!;
          final double taxaSucesso = dados['taxaSucesso'];
          final int totalSucesso = dados['totalSucesso'];
          final int totalFalhas = dados['totalFalhas'];
          final int totalEntregas = dados['totalEntregas'];
          final int totalColetas = dados['totalColetas'];
          final int totalOutros = dados['totalOutros'];
          final int totalVolume = dados['totalVolume'];

          // Proporções para as barras (0.0 ~ 1.0)
          final double propEntregas = totalVolume > 0 ? totalEntregas / totalVolume : 0;
          final double propColetas = totalVolume > 0 ? totalColetas / totalVolume : 0;
          final double propOutros = totalVolume > 0 ? totalOutros / totalVolume : 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── HEADER: Taxa de Sucesso ──────────────────────────────
                _TaxaSucessoCard(
                  taxaSucesso: taxaSucesso,
                  totalSucesso: totalSucesso,
                  totalFalhas: totalFalhas,
                ),
                const SizedBox(height: 28),

                // ── SEÇÃO: Volume por Tipo ───────────────────────────────
                const _SectionTitle(title: 'Volume por Tipo de Serviço'),
                const SizedBox(height: 16),
                _GraficoBarrasCard(
                  propEntregas: propEntregas,
                  propColetas: propColetas,
                  propOutros: propOutros,
                  totalEntregas: totalEntregas,
                  totalColetas: totalColetas,
                  totalOutros: totalOutros,
                ),
                const SizedBox(height: 28),

                // ── SEÇÃO: Financeiro ────────────────────────────────────
                const _SectionTitle(title: 'Financeiro'),
                const SizedBox(height: 16),
                const _FinanceiroCard(),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD: Taxa de Sucesso
// ─────────────────────────────────────────────────────────────────────────────
class _TaxaSucessoCard extends StatelessWidget {
  final double taxaSucesso;
  final int totalSucesso;
  final int totalFalhas;

  const _TaxaSucessoCard({
    required this.taxaSucesso,
    required this.totalSucesso,
    required this.totalFalhas,
  });

  String get _badgeLabel {
    if (taxaSucesso > 70) return '▲ Excelente';
    if (taxaSucesso >= 50) return '~ Médio';
    return '▼ Atenção';
  }

  Color get _badgeColor {
    if (taxaSucesso > 70) return Colors.green;
    if (taxaSucesso >= 50) return Colors.amber;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final totalFinalizadas = totalSucesso + totalFalhas;
    final taxaStr = totalFinalizadas == 0
        ? '--'
        : '${taxaSucesso.toStringAsFixed(0)}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _badgeColor.withValues(alpha: 0.2),
            AppColors.backgroundBody,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _badgeColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Indicador circular
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _badgeColor, width: 2.5),
              color: _badgeColor.withValues(alpha: 0.1),
            ),
            child: Center(
              child: Text(
                taxaStr,
                style: TextStyle(
                  color: _badgeColor,
                  fontSize: taxaStr == '--' ? 28 : 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Textos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Taxa de Sucesso',
                  style: TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Baseado na diária iniciada às 04:00',
                  style: TextStyle(
                    color: AppColors.textGrey.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _MiniStat(valor: totalSucesso, label: 'Sucesso', cor: AppColors.successGreen),
                    const SizedBox(width: 12),
                    _MiniStat(valor: totalFalhas, label: 'Falha', cor: Colors.redAccent),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    totalFinalizadas == 0 ? 'Sem dados hoje' : _badgeLabel,
                    style: TextStyle(
                      color: _badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final int valor;
  final String label;
  final Color cor;

  const _MiniStat({required this.valor, required this.label, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$valor',
          style: TextStyle(
            color: cor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textGrey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD: Gráfico de Barras por Tipo
// ─────────────────────────────────────────────────────────────────────────────
class _GraficoBarrasCard extends StatelessWidget {
  final double propEntregas;
  final double propColetas;
  final double propOutros;
  final int totalEntregas;
  final int totalColetas;
  final int totalOutros;

  const _GraficoBarrasCard({
    required this.propEntregas,
    required this.propColetas,
    required this.propOutros,
    required this.totalEntregas,
    required this.totalColetas,
    required this.totalOutros,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          _BarraHorizontal(
            label: 'Entregas',
            total: totalEntregas,
            proporcao: propEntregas,
            cor: AppColors.borderEntregas,
          ),
          const SizedBox(height: 20),
          _BarraHorizontal(
            label: 'Coletas',
            total: totalColetas,
            proporcao: propColetas,
            cor: AppColors.borderRecolha,
          ),
          const SizedBox(height: 20),
          _BarraHorizontal(
            label: 'Outros/Atas',
            total: totalOutros,
            proporcao: propOutros,
            cor: AppColors.borderOutros,
          ),
        ],
      ),
    );
  }
}

class _BarraHorizontal extends StatelessWidget {
  final String label;
  final int total;
  final double proporcao;
  final Color cor;

  const _BarraHorizontal({
    required this.label,
    required this.total,
    required this.proporcao,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    final pctStr = total == 0 ? '0' : (proporcao * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$total ',
                    style: TextStyle(
                      color: cor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: '($pctStr%)',
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOut,
                  height: 8,
                  width: constraints.maxWidth * proporcao.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    color: cor,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: cor.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD: Financeiro (Em desenvolvimento)
// ─────────────────────────────────────────────────────────────────────────────
class _FinanceiroCard extends StatelessWidget {
  const _FinanceiroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: Colors.amber,
              size: 26,
            ),
          ),
          const SizedBox(width: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Financeiro',
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Módulo em desenvolvimento',
                style: TextStyle(
                  color: AppColors.textGrey.withValues(alpha: 0.75),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Título de Seção
// ─────────────────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: AppColors.textGrey.withValues(alpha: 0.6),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
      ),
    );
  }
}
