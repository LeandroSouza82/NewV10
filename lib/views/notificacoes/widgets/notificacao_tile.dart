import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';

class NotificacaoTile extends StatelessWidget {
  final Map<String, dynamic> notificacao;
  final VoidCallback onTap;

  const NotificacaoTile({
    super.key,
    required this.notificacao,
    required this.onTap,
  });

  String _formatarData(String? dataIso) {
    if (dataIso == null || dataIso.isEmpty) return '';
    try {
      // Limpeza de ISO e parse robusto
      String limpa = dataIso.replaceAll('+0000', 'Z');
      final data = DateTime.tryParse(limpa)?.toLocal();
      
      if (data == null) return '';

      final hoje = DateTime.now();
      if (data.year == hoje.year && data.month == hoje.month && data.day == hoje.day) {
        return DateFormat("HH:mm").format(data);
      } else {
        return DateFormat("dd/MM - HH:mm").format(data);
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool lida = notificacao['lida'] == true;
    final String tipo = (notificacao['tipo'] ?? '').toString().toLowerCase();
    final String titulo = notificacao['titulo'] ?? 'Notificação';
    final String mensagem = notificacao['mensagem'] ?? '';
    final String data = _formatarData(notificacao['created_at'] ?? notificacao['data']);

    IconData icone;
    Color corIcone;

    switch (tipo) {
      case 'rota':
        icone = Icons.inventory_2_outlined;
        corIcone = Colors.cyanAccent;
        break;
      case 'urgente':
      case 'correr':
        icone = Icons.warning_amber_rounded;
        corIcone = Colors.orangeAccent;
        break;
      case 'aviso':
        icone = Icons.campaign_outlined;
        corIcone = Colors.greenAccent;
        break;
      default:
        icone = Icons.cloud_outlined;
        corIcone = AppColors.textGrey;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: lida ? AppColors.cardBackground : AppColors.cardBackground.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: lida ? AppColors.textGrey.withValues(alpha: 0.1) : corIcone.withValues(alpha: 0.5),
            width: lida ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ÍCONE
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: corIcone.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icone, color: corIcone, size: 24),
            ),
            const SizedBox(width: 16),
            
            // CONTEÚDO
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          titulo,
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 15,
                            fontWeight: lida ? FontWeight.w500 : FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        data,
                        style: TextStyle(
                          color: lida ? AppColors.textGrey.withValues(alpha: 0.7) : AppColors.textWhite.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: lida ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mensagem,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: lida ? FontWeight.normal : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // INDICADOR DE NÃO LIDA
            if (!lida) ...[
              const SizedBox(width: 12),
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: corIcone,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: corIcone.withValues(alpha: 0.5), blurRadius: 4, spreadRadius: 1)
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
