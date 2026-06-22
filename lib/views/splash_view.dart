import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../services/supabase_service.dart';
import 'home_view.dart';
import 'login_view.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'permission_onboarding_view.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _controller.forward();

    // Após a animação, verifica a sessão e redireciona
    _verificarSessaoERedirecionar();
  }

  Future<void> _verificarSessaoERedirecionar() async {
    // Aguarda a animação completar + um breve respiro visual
    await Future.delayed(const Duration(milliseconds: 2800));

    final prefs = await SharedPreferences.getInstance();
    final bool manterLogado = prefs.getBool('manter_logado') ?? false;
    final String? motoristaId = prefs.getString('motorista_id');

    bool vaiParaHome = false;
    if (manterLogado && motoristaId != null && motoristaId.isNotEmpty) {
      final bool logado = await SupabaseService.isLogado();
      vaiParaHome = logado;
    } else {
      // Se não manter logado ou sem id, garante que limpa a sessão ativa local/online
      await SupabaseService.logout();
    }

    Widget nextView;
    if (vaiParaHome) {
      bool hasOverlayPerm = await FlutterOverlayWindow.isPermissionGranted();
      if (!mounted) return;
      nextView = hasOverlayPerm ? const HomeView() : const PermissionOnboardingView();
    } else {
      nextView = const LoginView();
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextView,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backgroundBody, Colors.black],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo V10
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.successGreen.withValues(alpha: 0.6),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.successGreen.withValues(alpha: 0.15),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.delivery_dining_rounded,
                      color: AppColors.successGreen,
                      size: 72,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Nome V10
                  const Text(
                    'V10',
                    style: TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'DELIVERY',
                    style: TextStyle(
                      color: AppColors.textGrey.withValues(alpha: 0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Indicador de carregamento sutil
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.successGreen.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
