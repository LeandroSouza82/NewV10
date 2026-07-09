import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';

class SuccessStatus extends StatelessWidget {
  final String driverName;

  const SuccessStatus({
    super.key,
    this.driverName = 'Leandro', // Preparado para receber do Supabase depois
  });

  Future<void> _abrirModalDefinirBase(BuildContext context) async {
    final TextEditingController enderecoController = TextEditingController();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "CRAVAR LOCAL DA EMPRESA",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: enderecoController,
                    decoration: const InputDecoration(
                      labelText: "Digite o novo endereço da base",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, // Mantém o padrão visual
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: isLoading
                        ? null
                        : () async {
                            if (enderecoController.text.trim().isEmpty) return;
                            setState(() => isLoading = true);
                            
                            try {
                              // Atualiza a coluna endereco_base usando o ID da Essenza Condomínios
                              await Supabase.instance.client
                                  .from('empresas')
                                  .update({'endereco_base': enderecoController.text.trim()})
                                  .eq('id', 'a575367d-f00f-48eb-b6d7-a5116fc2f2d5');
                                  
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Base atualizada com sucesso!'), backgroundColor: Colors.green),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
                                );
                              }
                            } finally {
                              if (context.mounted) setState(() => isLoading = false);
                            }
                          },
                    child: isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("SALVAR BASE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

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
              onPressed: () => _abrirModalDefinirBase(context),
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
