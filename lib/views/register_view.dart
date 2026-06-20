import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../services/supabase_service.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  bool _isLoading = false;
  bool _obscureText = true;

  // Definição das máscaras de entrada
  final _cpfFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  final _telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void dispose() {
    _nomeController.dispose();
    _cpfController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensagem,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _mostrarSucesso(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensagem,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppColors.successGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _registrarMotorista() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final cpfLimpo = _cpfFormatter.getUnmaskedText();
    final telefoneLimpo = _telefoneFormatter.getUnmaskedText();

    if (cpfLimpo.length != 11) {
      _mostrarErro('O CPF deve conter exatamente 11 dígitos.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Inserção no banco de dados customizado do Supabase
      await SupabaseService.client.from('motoristas').insert({
        'nome': _nomeController.text.trim(),
        'cpf': cpfLimpo,
        'telefone': telefoneLimpo,
        'email': _emailController.text.trim().toLowerCase(),
        'senha': _senhaController.text.trim(),
      });

      _mostrarSucesso('Cadastro realizado com sucesso!');
      
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      String mensagemAmigavel = 'Ocorreu um erro ao realizar o cadastro.';
      
      if (e is PostgrestException) {
        final detailsStr = e.details?.toString() ?? '';
        if (e.message.contains('unique') || e.code == '23505') {
          if (e.message.contains('cpf') || detailsStr.contains('cpf')) {
            mensagemAmigavel = 'Este CPF já está cadastrado no sistema.';
          } else if (e.message.contains('email') || detailsStr.contains('email')) {
            mensagemAmigavel = 'Este e-mail já está cadastrado no sistema.';
          } else {
            mensagemAmigavel = 'E-mail ou CPF já cadastrados.';
          }
        } else {
          mensagemAmigavel = 'Erro no servidor: ${e.message}';
        }
      } else {
        mensagemAmigavel = 'Falha na conexão. Verifique sua internet e tente novamente.';
      }

      _mostrarErro(mensagemAmigavel);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fundo com gradiente elegante idêntico ao do login
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.backgroundBody, Colors.black],
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Ícone Premium
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.backgroundBody,
                          border: Border.all(color: AppColors.successGreen, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.successGreen.withValues(alpha: 0.15),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.successGreen, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Criar Conta',
                        style: TextStyle(
                          color: AppColors.textWhite, 
                          fontSize: 24, 
                          fontWeight: FontWeight.bold, 
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cadastre-se como Motorista Parceiro',
                        style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8), fontSize: 14),
                      ),
                      const SizedBox(height: 32),

                      // Nome Completo
                      TextFormField(
                        controller: _nomeController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(color: AppColors.textWhite),
                        decoration: InputDecoration(
                          hintText: 'Nome Completo',
                          hintStyle: const TextStyle(color: AppColors.textGrey),
                          prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textGrey),
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16), 
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, informe seu nome completo.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // CPF
                      TextFormField(
                        controller: _cpfController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [_cpfFormatter],
                        style: const TextStyle(color: AppColors.textWhite),
                        decoration: InputDecoration(
                          hintText: 'CPF',
                          hintStyle: const TextStyle(color: AppColors.textGrey),
                          prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textGrey),
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16), 
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, informe seu CPF.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Telefone
                      TextFormField(
                        controller: _telefoneController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [_telefoneFormatter],
                        style: const TextStyle(color: AppColors.textWhite),
                        decoration: InputDecoration(
                          hintText: 'Telefone',
                          hintStyle: const TextStyle(color: AppColors.textGrey),
                          prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textGrey),
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16), 
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, informe seu telefone.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // E-mail
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: AppColors.textWhite),
                        decoration: InputDecoration(
                          hintText: 'E-mail',
                          hintStyle: const TextStyle(color: AppColors.textGrey),
                          prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textGrey),
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16), 
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, informe seu e-mail.';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                            return 'Por favor, insira um e-mail válido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Senha
                      TextFormField(
                        controller: _senhaController,
                        obscureText: _obscureText,
                        style: const TextStyle(color: AppColors.textWhite),
                        decoration: InputDecoration(
                          hintText: 'Senha',
                          hintStyle: const TextStyle(color: AppColors.textGrey),
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textGrey),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.textGrey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16), 
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, informe sua senha.';
                          }
                          if (value.length < 6) {
                            return 'A senha deve conter no mínimo 6 caracteres.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Botão de Cadastrar
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _registrarMotorista,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.buttonGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 8,
                            shadowColor: AppColors.buttonGreen.withValues(alpha: 0.5),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24, 
                                  height: 24, 
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'CRIAR CONTA', 
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Voltar ao Login
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Já tenho uma conta. Voltar ao Login',
                          style: TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
