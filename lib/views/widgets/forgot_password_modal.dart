import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/supabase_service.dart';

/// Modal de recuperação de senha (validação por e-mail + CPF).
class ForgotPasswordModal extends StatefulWidget {
  const ForgotPasswordModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ForgotPasswordModal(),
    );
  }

  @override
  State<ForgotPasswordModal> createState() => _ForgotPasswordModalState();
}

class _ForgotPasswordModalState extends State<ForgotPasswordModal> {
  final _emailController = TextEditingController();
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarController = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _erro;

  @override
  void dispose() {
    _emailController.dispose();
    _cpfController.dispose();
    _senhaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final email = _emailController.text.trim();
    final cpf = _cpfController.text.trim();
    final senha = _senhaController.text.trim();
    final confirmar = _confirmarController.text.trim();

    if (email.isEmpty || cpf.isEmpty || senha.isEmpty || confirmar.isEmpty) {
      setState(() => _erro = 'Preencha todos os campos.');
      return;
    }
    if (senha != confirmar) {
      setState(() => _erro = 'As senhas não coincidem.');
      return;
    }

    setState(() {
      _isLoading = true;
      _erro = null;
    });

    try {
      await SupabaseService.redefinirSenha(
        email: email,
        cpf: cpf,
        novaSenha: senha,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Senha redefinida com sucesso! Faça login com a nova senha.'),
          backgroundColor: AppColors.buttonGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textGrey),
      prefixIcon: Icon(icon, color: AppColors.textGrey),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.backgroundBody,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final toggle = IconButton(
      icon: Icon(
        _obscure ? Icons.visibility_off : Icons.visibility,
        color: AppColors.textGrey,
      ),
      onPressed: () => setState(() => _obscure = !_obscure),
    );

    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Redefinir senha',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppColors.textWhite),
              decoration: _decoration('E-mail cadastrado', Icons.email_outlined),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cpfController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textWhite),
              decoration: _decoration('CPF', Icons.badge_outlined),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _senhaController,
              obscureText: _obscure,
              style: const TextStyle(color: AppColors.textWhite),
              decoration: _decoration('Nova senha', Icons.lock_outline_rounded, suffix: toggle),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmarController,
              obscureText: _obscure,
              style: const TextStyle(color: AppColors.textWhite),
              decoration: _decoration('Confirmar nova senha', Icons.lock_outline_rounded),
            ),
            if (_erro != null) ...[
              const SizedBox(height: 12),
              Text(
                _erro!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'REDEFINIR SENHA',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textGrey)),
            ),
          ],
        ),
      ),
    );
  }
}
