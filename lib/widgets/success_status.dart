import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_colors.dart';

class SuccessStatus extends StatelessWidget {
  final String driverName;

  const SuccessStatus({
    super.key,
    this.driverName = 'Leandro', // Preparado para receber do Supabase depois
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícone de Check com Brilho (Neon Suave)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.backgroundBody,
              border: Border.all(color: AppColors.successGreen, width: 4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.successGreen.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.successGreen,
              size: 60,
            ),
          ),
          const SizedBox(height: 32),
          
          // Título de Sucesso
          const Text(
            'Todas as entregas concluídas!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textWhite,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          
          // Subtítulo Dinâmico
          Text(
            'Bom trabalho, $driverName!',
            style: TextStyle(
              color: AppColors.textGrey.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 48),

          // Indicador de Carregamento
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              color: AppColors.borderRecolha,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          
          // Texto Procurando Rotas
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_rounded, color: AppColors.textGrey.withValues(alpha: 0.7), size: 18),
              const SizedBox(width: 8),
              Text(
                'Procurando novas rotas...',
                style: TextStyle(
                  color: AppColors.textGrey.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),

          // Botão Premium de Retorno
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Buscando rota para a base...')),
                  );

                  // 1. Busca o endereço atualizado no banco
                  final response = await Supabase.instance.client
                      .from('empresas')
                      .select('endereco_base')
                      .eq('id', 'a575367d-f00f-48eb-b6d7-a5116fc2f2d5')
                      .single();
                  
                  final String? endereco = response['endereco_base'];

                  if (endereco != null && endereco.isNotEmpty) {
                    // 2. Abre o GPS respeitando a preferência do usuário (Waze / Google Maps)
                    final prefs = await SharedPreferences.getInstance();
                    final navegador = prefs.getString('navegador_padrao') ?? 'maps';
                    final enderecoCodificado = Uri.encodeComponent(endereco);

                    Uri url;
                    if (navegador == 'waze') {
                      url = Uri.parse('https://waze.com/ul?q=$enderecoCodificado&navigate=yes');
                    } else {
                      url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$enderecoCodificado');
                    }

                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      throw 'Falha ao abrir o mapa.';
                    }
                  } else {
                    throw 'Endereço da base não configurado.';
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Erro: Base não configurada. Vá no menu para configurar.'), 
                        backgroundColor: Colors.red
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.business_rounded, color: AppColors.textWhite),
              label: const Text(
                'RETORNAR PARA A EMPRESA',
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.buttonGreen,
                elevation: 8,
                shadowColor: AppColors.buttonGreen.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32), // Margem inferior de segurança
        ],
      ),
    );
  }
}
