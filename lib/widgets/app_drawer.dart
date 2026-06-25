import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';

class AppDrawer extends StatelessWidget {
  final Map<String, dynamic>? motorista;
  final String saudacao;
  final bool isLoadingPhoto;
  final String navegadorSelecionado;
  final VoidCallback onTapFoto;
  final VoidCallback onTapNavegador;
  final VoidCallback onTapSair;

  const AppDrawer({
    super.key,
    required this.motorista,
    required this.saudacao,
    required this.isLoadingPhoto,
    required this.navegadorSelecionado,
    required this.onTapFoto,
    required this.onTapNavegador,
    required this.onTapSair,
  });

  void _mostrarAvisoDesenvolvimento(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Funcionalidade em desenvolvimento.'),
        backgroundColor: Colors.grey,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildEmBreveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Em breve',
        style: TextStyle(
          color: Colors.orange,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
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
                    onTap: isLoadingPhoto ? null : onTapFoto,
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
                            image: motorista != null && motorista!['avatar_path'] != null
                                ? DecorationImage(
                                    image: NetworkImage(motorista!['avatar_path']),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: motorista == null || motorista!['avatar_path'] == null
                              ? const Icon(
                                  Icons.person,
                                  color: AppColors.textGrey,
                                  size: 40,
                                )
                              : null,
                        ),
                        if (isLoadingPhoto)
                          const CircularProgressIndicator(color: AppColors.successGreen),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    motorista != null
                        ? '$saudacao, ${motorista!['nome'] ?? 'Motorista'}'
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
                    motorista != null ? (motorista!['email'] ?? 'V10 Delivery') : 'V10 Delivery',
                    style: TextStyle(
                      color: AppColors.textGrey.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
                    child: Builder(
                      builder: (context) {
                        return FutureBuilder<List<Map<String, dynamic>>>(
                          future: Supabase.instance.client
                              .from('entregas')
                              .select()
                              .eq('motorista_id', motorista?['id']?.toString() ?? '00000000-0000-0000-0000-000000000000'),
                          builder: (context, snapshot) {
                            // 1. Loading
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            
                            // 2. Erro no banco ou sem dados
                            if (snapshot.hasError || !snapshot.hasData) {
                              print('🕵️ ERRO OU SEM DADOS: ${snapshot.error}');
                              return const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _StatCard(value: '0', label: 'FEITAS', color: Colors.greenAccent),
                                  _StatCard(value: '0', label: 'PENDENTES', color: Colors.orangeAccent),
                                  _StatCard(value: '0', label: 'FALHA', color: Colors.redAccent),
                                ],
                              );
                            }

                            final registros = snapshot.data!;
                            print('🕵️ SUCESSO: O banco retornou ${registros.length} entregas para o Drawer!');
                            
                            // Filtro de data feito direto no aplicativo
                            final agora = DateTime.now().toLocal();
                            // Define o limite como sendo 4h da manhã de hoje
                            DateTime limiteReset = DateTime(agora.year, agora.month, agora.day, 4, 0);

                            // Se a hora atual for antes das 4h da manhã, a diária iniciou às 4h do dia anterior
                            if (agora.isBefore(limiteReset)) {
                              limiteReset = limiteReset.subtract(const Duration(days: 1));
                            }
                            
                            int totalFeitas = 0;
                            int totalFalhas = 0;
                            int totalPendentes = 0;

                            for (var e in registros) {
                              // Verifica a data
                              final dataStr = e['created_at'] ?? e['criado_em'];
                              if (dataStr != null) {
                                final dataCriacao = DateTime.tryParse(dataStr.toString())?.toLocal();
                                if (dataCriacao != null && dataCriacao.isBefore(limiteReset)) {
                                  continue; // Ignora entregas de diárias passadas
                                }
                              }

                              final status = (e['status'] ?? '').toString().toLowerCase().trim();
                              
                              // Contagem
                              if (status == 'arquivado' || status == 'entregue' || status == 'concluido') {
                                totalFeitas++;
                              } else if (status == 'falha' || status == 'nao_entregue') {
                                totalFalhas++;
                              } else if (status == 'pendente' || status == 'em_rota' || status.isEmpty) {
                                totalPendentes++;
                              }
                            }

                            print('🕵️ PLACAR: Feitas: $totalFeitas | Pend: $totalPendentes | Falha: $totalFalhas');

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _StatCard(value: totalFeitas.toString(), label: 'FEITAS', color: Colors.greenAccent),
                                const SizedBox(width: 8),
                                _StatCard(value: totalPendentes.toString(), label: 'PENDENTES', color: Colors.orangeAccent),
                                const SizedBox(width: 8),
                                _StatCard(value: totalFalhas.toString(), label: 'FALHA', color: Colors.redAccent),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Seção Principal
                    ListTile(
                      leading: const Icon(Icons.bar_chart, color: AppColors.textWhite),
                      title: const Text('Meu Desempenho', style: TextStyle(color: AppColors.textWhite)),
                      trailing: _buildEmBreveBadge(),
                      onTap: () => _mostrarAvisoDesenvolvimento(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.history, color: AppColors.textWhite),
                      title: const Text('Histórico do Dia', style: TextStyle(color: AppColors.textWhite)),
                      trailing: _buildEmBreveBadge(),
                      onTap: () => _mostrarAvisoDesenvolvimento(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.report_problem_outlined, color: AppColors.textWhite),
                      title: const Text('Minhas Ocorrências', style: TextStyle(color: AppColors.textWhite)),
                      trailing: _buildEmBreveBadge(),
                      onTap: () => _mostrarAvisoDesenvolvimento(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.textWhite),
                      title: const Text('Meus Comprovantes', style: TextStyle(color: AppColors.textWhite)),
                      trailing: _buildEmBreveBadge(),
                      onTap: () => _mostrarAvisoDesenvolvimento(context),
                    ),

                    Divider(color: AppColors.textGrey.withValues(alpha: 0.2), height: 32),

                    // Seção Secundária
                    ListTile(
                      leading: const Icon(Icons.notifications_none, color: AppColors.textWhite),
                      title: const Text('Notificações', style: TextStyle(color: AppColors.textWhite)),
                      trailing: _buildEmBreveBadge(),
                      onTap: () => _mostrarAvisoDesenvolvimento(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.directions_car_filled_outlined, color: AppColors.textWhite),
                      title: const Text('Meu Veículo', style: TextStyle(color: AppColors.textWhite)),
                      trailing: _buildEmBreveBadge(),
                      onTap: () => _mostrarAvisoDesenvolvimento(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.map, color: AppColors.textWhite),
                      title: const Text('Navegador Padrão', style: TextStyle(color: AppColors.textWhite)),
                      subtitle: Text(
                        navegadorSelecionado == 'waze' ? 'Waze' : 'Google Maps',
                        style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8)),
                      ),
                      onTap: onTapNavegador,
                    ),
                  ],
                ),
              ),
            ),
            
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
                  onTapSair();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4.0),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
