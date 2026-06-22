import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../services/supabase_service.dart';
import 'home_view.dart';
import 'register_view.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'permission_onboarding_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;
  bool _manterLogado = false;
  String? _errorMessage;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _passwordController.clear();
    _carregarEmailSalvo();
    
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        if (_errorMessage != null && _errorMessage!.toLowerCase().contains('conexão')) {
          setState(() {
            _errorMessage = null;
          });
        }
      }
    });
  }

  Future<void> _carregarEmailSalvo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('email_salvo');
      if (email != null && email.isNotEmpty) {
        setState(() {
          _emailController.text = email;
        });
      }
    } catch (e) {
      // Ignora erros de inicialização local de forma amigável
    }
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

  Future<void> _fazerLogin() async {
    // Esconde o teclado
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      await SupabaseService.login(
        email,
        _passwordController.text.trim(),
      );
      
      // Salva o email localmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('email_salvo', email);
      
      // Salva a preferência de manter logado
      if (_manterLogado) {
        await prefs.setBool('manter_logado', true);
      } else {
        await prefs.remove('manter_logado');
      }
      
      // Navega para a Home ou para a tela de Permissões
      bool hasOverlayPerm = await FlutterOverlayWindow.isPermissionGranted();
      if (!mounted) return;
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => hasOverlayPerm ? const HomeView() : const PermissionOnboardingView(),
        ),
      );
    } catch (e) {
      String mensagemAmigavel;
      final errorStr = e.toString();
      
      if (e is SocketException || 
          e is TimeoutException || 
          errorStr.contains('Failed host lookup') || 
          errorStr.contains('Failed to host lookup')) {
        mensagemAmigavel = 'Sem conexão com a internet. Verifique seu sinal e tente novamente.';
      } else if (e is PostgrestException) {
        mensagemAmigavel = 'Nosso servidor está passando por instabilidades. Tente novamente em instantes.';
      } else if (errorStr.contains('E-mail ou senha incorretos')) {
        mensagemAmigavel = 'E-mail ou senha incorretos. Verifique seus dados e tente novamente.';
      } else {
        final errString = errorStr.replaceAll('Exception: ', '');
        final shortErr = errString.length > 30 ? '${errString.substring(0, 30)}...' : errString;
        mensagemAmigavel = 'Ops! Algo deu errado: $shortErr';
      }

      setState(() {
        _errorMessage = mensagemAmigavel;
      });
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
  void dispose() {
    _connectivitySubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fundo com gradiente elegante
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.backgroundBody, Colors.black],
              ),
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ícone Premium
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.backgroundBody,
                      border: Border.all(color: AppColors.successGreen, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.successGreen.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.delivery_dining_rounded, color: AppColors.successGreen, size: 60),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'V10 Delivery',
                    style: TextStyle(
                      color: AppColors.textWhite, 
                      fontSize: 28, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Acesso do Motorista',
                    style: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.8), fontSize: 16),
                  ),
                  const SizedBox(height: 48),

                  // Campo de E-mail
                  TextField(
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
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo de Senha
                  TextField(
                    controller: _passwordController,
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
                  ),
                  const SizedBox(height: 12),

                  // Opção Manter Logado
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _manterLogado = !_manterLogado;
                      });
                    },
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _manterLogado,
                            onChanged: (value) {
                              setState(() {
                                _manterLogado = value ?? false;
                              });
                            },
                            activeColor: AppColors.successGreen,
                            checkColor: Colors.white,
                            side: const BorderSide(color: AppColors.textGrey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Manter logado',
                          style: TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mensagem de Erro
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!, 
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold), 
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Botão de Entrar
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _fazerLogin,
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
                              'ENTRAR', 
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botão de Registro
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterView()),
                      );
                    },
                    child: Text.rich(
                      TextSpan(
                        text: 'Não tem uma conta? ',
                        style: TextStyle(
                          color: AppColors.textGrey.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                        children: const [
                          TextSpan(
                            text: 'Registrar-se',
                            style: TextStyle(
                              color: AppColors.successGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
