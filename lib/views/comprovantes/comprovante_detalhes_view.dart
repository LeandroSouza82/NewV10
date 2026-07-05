import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';

class ComprovanteDetalhesView extends StatelessWidget {
  final Map<String, dynamic> entrega;

  const ComprovanteDetalhesView({super.key, required this.entrega});

  DateTime? _parseDataSegura(String? dataIso) {
    if (dataIso == null || dataIso.isEmpty) return null;
    // Limpeza de offset (ex: "+0000" para "Z") para garantir o parse
    String limpa = dataIso.replaceAll('+0000', 'Z');
    return DateTime.tryParse(limpa)?.toLocal();
  }

  String _formatarData(String? dataIso) {
    final data = _parseDataSegura(dataIso);
    if (data == null) return 'Data não disponível';
    
    try {
      final dateFormat = DateFormat("EEEE, dd 'de' MMMM", 'pt_BR');
      final formatada = dateFormat.format(data);
      return "${formatada[0].toUpperCase()}${formatada.substring(1)}";
    } catch (e) {
      // Fallback manual caso o locale 'pt_BR' não esteja inicializado no app (evita o erro "Data inválida")
      final dias = ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo'];
      final meses = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
      return "${dias[data.weekday - 1]}, ${data.day.toString().padLeft(2, '0')} de ${meses[data.month - 1]}";
    }
  }

  String _formatarHora(String? dataIso) {
    final data = _parseDataSegura(dataIso);
    if (data == null) return '--:--';
    
    try {
      return DateFormat("HH:mm").format(data);
    } catch (e) {
      return "${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Coleta resiliente da data (cobre diversos cenários do Supabase)
    final dataIso = entrega['data_conclusao'] ?? 
                    entrega['created_at'] ?? 
                    entrega['data_finalizacao'] ?? 
                    entrega['data_registro'] ?? 
                    entrega['data'];
    final endereco = entrega['endereco'] ?? 'Endereço não informado';
    
    // Fallbacks genéricos caso os campos de GPS estejam com outros nomes
    final lat = entrega['lat'] ?? entrega['latitude'] ?? 'N/A';
    final lng = entrega['lng'] ?? entrega['longitude'] ?? 'N/A';
    
    final recebedorTipo = entrega['recebedor_tipo'] ?? 'Não informado';
    final observacoes = entrega['observacoes'] ?? '';
    
    final assinaturaUrl = entrega['assinatura_url'];
    final fotoUrl = entrega['foto_url'];

    return Scaffold(
      backgroundColor: AppColors.backgroundBody,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundBody,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Recibo de Entrega',
          style: TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textWhite),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // CARD PRINCIPAL DE RECIBO
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.textGrey.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // HEADER DO RECIBO
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Entrega Finalizada',
                          style: TextStyle(
                            color: AppColors.successGreen,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${entrega['id'] ?? 'Desconhecido'}',
                          style: TextStyle(
                            color: AppColors.textWhite.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // INFORMAÇÕES DETALHADAS
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('DATA E HORA'),
                        _buildInfoRow(
                          icon: Icons.calendar_today_rounded,
                          title: _formatarData(dataIso),
                          subtitle: 'Horário: ${_formatarHora(dataIso)}',
                        ),
                        const Divider(height: 32, color: Colors.white10),

                        _buildSectionTitle('LOCALIZAÇÃO'),
                        _buildInfoRow(
                          icon: Icons.location_on_outlined,
                          title: endereco,
                          subtitle: 'GPS: $lat, $lng',
                        ),
                        const Divider(height: 32, color: Colors.white10),

                        _buildSectionTitle('RECEBEDOR'),
                        _buildInfoRow(
                          icon: Icons.person_outline_rounded,
                          title: recebedorTipo,
                          subtitle: observacoes.isNotEmpty ? observacoes : 'Sem nome/observação',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // BOX DE EVIDÊNCIAS DIGITAIS
            if (assinaturaUrl != null || fotoUrl != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.textGrey.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('EVIDÊNCIAS DIGITAIS'),
                    const SizedBox(height: 16),
                    
                    if (assinaturaUrl != null) ...[
                      const Text(
                        'Assinatura Digital',
                        style: TextStyle(color: AppColors.textWhite, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      _buildNetworkImage(assinaturaUrl),
                    ],

                    if (assinaturaUrl != null && fotoUrl != null) 
                      const SizedBox(height: 24),

                    if (fotoUrl != null) ...[
                      const Text(
                        'Foto do Pacote',
                        style: TextStyle(color: AppColors.textWhite, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      _buildNetworkImage(fotoUrl),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textGrey,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textGrey, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textGrey.withValues(alpha: 0.8),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkImage(String url) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.successGreen,
                  strokeWidth: 2,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_outlined, color: Colors.white24, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Não foi possível carregar a imagem.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
