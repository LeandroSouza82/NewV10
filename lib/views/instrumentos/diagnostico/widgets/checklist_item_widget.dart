import 'package:flutter/material.dart';
import '../controllers/diagnostico_controller.dart';

class ChecklistItemWidget extends StatelessWidget {
  final CheckItem item;

  const ChecklistItemWidget({super.key, required this.item});

  IconData get _leadingIcon {
    switch (item.iconeKey) {
      case 'network':
        return Icons.cell_tower_outlined;
      case 'gps':
        return Icons.satellite_alt_outlined;
      case 'server':
        return Icons.dns_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Ícone do serviço
          Icon(_leadingIcon, color: const Color(0xFF00E5FF), size: 26),
          const SizedBox(width: 14),
          // Título e detalhe
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (item.detalhe.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.detalhe,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Status visual
          _buildStatusWidget(),
        ],
      ),
    );
  }

  Widget _buildStatusWidget() {
    switch (item.status) {
      case StatusItem.pendente:
        return Icon(
          Icons.remove_circle_outline,
          color: Colors.white.withValues(alpha: 0.3),
          size: 22,
        );
      case StatusItem.checando:
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
          ),
        );
      case StatusItem.ok:
        return const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 22);
      case StatusItem.alerta:
        return const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFAB00), size: 22);
      case StatusItem.erro:
        return const Icon(Icons.cancel, color: Color(0xFFFF1744), size: 22);
    }
  }
}
