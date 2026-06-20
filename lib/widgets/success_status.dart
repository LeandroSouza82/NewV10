import 'package:flutter/material.dart';
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
              onPressed: () {
                // Ação futura
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
